# backend/main.py
import os
import json
import asyncio
import numpy as np
import scipy.signal
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from transformers import pipeline as hf_pipeline
import torch
from typing import Dict

# --- Configuración Inicial y Carga de Modelos (Sin cambios) ---
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Usando dispositivo: {DEVICE}")

app = FastAPI()

print("Cargando modelo de Speech-to-Text (Whisper)...")
transcription_pipeline = hf_pipeline(
    "automatic-speech-recognition",
    model="openai/whisper-base",
    torch_dtype=torch.float16 if DEVICE == "cuda" else torch.float32,
    device=DEVICE,
)
print("Modelo de transcripción cargado.")

class PipelineManager:
    def __init__(self):
        self.translation_pipelines: Dict[str, hf_pipeline] = {}

    async def get_translation_pipeline(self, source: str, target: str):
        name = f"Helsinki-NLP/opus-mt-{source}-{target}"
        if name not in self.translation_pipelines:
            try:
                print(f"[INFO] Cargando modelo de traducción: {name}")
                # Usamos un task para no bloquear el bucle de eventos si la descarga es lenta
                loop = asyncio.get_running_loop()
                self.translation_pipelines[name] = await loop.run_in_executor(
                    None, 
                    lambda: hf_pipeline(f"translation_{source}_to_{target}", model=name, device=DEVICE)
                )
                print(f"[INFO] Modelo {name} cargado.")
            except Exception as e:
                print(f"[ERROR] Al cargar modelo de traducción {name}: {e}")
                return None
        return self.translation_pipelines.get(name)

pipeline_manager = PipelineManager()

def is_valid_audio(audio_np, min_duration=0.3, min_volume_threshold=0.005):
    """Validar si el audio contiene habla útil"""
    duration = len(audio_np) / 16000
    if duration < min_duration:
        return False, f"Duración muy corta: {duration:.2f}s"
    
    rms_volume = np.sqrt(np.mean(audio_np**2))
    if rms_volume < min_volume_threshold:
        return False, f"Volumen muy bajo: {rms_volume:.4f}"
    
    return True, "Audio válido"

@app.websocket("/ws/translate_stream")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("[INFO] Conexión WebSocket aceptada.")
    
    source_lang = None
    target_lang = None

    try:
        # Configuración inicial
        config_message = await websocket.receive_json()
        if config_message.get("event") == "start":
            source_lang = config_message.get("source_lang")
            target_lang = config_message.get("target_lang")
            print(f"[CONFIG] Idiomas configurados: {source_lang} -> {target_lang}")
        else:
            await websocket.close(code=1003, reason="Primer mensaje debe ser 'start'")
            return

        # Bucle principal - SIN TIMEOUTS
        while True:
            print(f"\n[TURN START] Esperando audio: {source_lang} -> {target_lang}")
            audio_buffer = bytearray()
            
            # Recepción de audio - SIN TIMEOUT
            while True:
                message = await websocket.receive()
                
                if "bytes" in message and message["bytes"]:
                    chunk = message["bytes"]
                    audio_buffer.extend(chunk)
                    print(f"[DEBUG] Recibidos {len(chunk)} bytes. Total: {len(audio_buffer)}")
                    
                elif "text" in message and message["text"]:
                    data = json.loads(message["text"])
                    if data.get("event") == "end_of_speech":
                        print("[INFO] Fin de habla recibido.")
                        break
            
            # Procesar audio
            if len(audio_buffer) < 2000:
                print(f"[WARN] Audio insuficiente: {len(audio_buffer)} bytes")
                await websocket.send_text(json.dumps({"type": "no_speech_detected"}))
                continue
                
            print(f"[INFO] Procesando {len(audio_buffer)} bytes de audio...")
            audio_np = np.frombuffer(audio_buffer, dtype=np.int16).astype(np.float32) / 32768.0
            
            # Validar audio
            is_valid, reason = is_valid_audio(audio_np)
            if not is_valid:
                print(f"[WARN] Audio inválido: {reason}")
                await websocket.send_text(json.dumps({"type": "no_speech_detected"}))
                continue

            # TRANSCRIBIR
            print(f"[TRANSCRIPTION] Iniciando transcripción en '{source_lang}'...")
            result = transcription_pipeline(
                {"sampling_rate": 16000, "raw": audio_np},
                generate_kwargs={
                    "language": source_lang,
                    "task": "transcribe",
                    "temperature": 0.0,
                    "no_repeat_ngram_size": 2,
                }
            )
            
            original_text = result["text"].strip()
            print(f"[TRANSCRIPTION] Transcrito: '{original_text}'")

            # FILTRO BÁSICO - Solo rechazar texto vacío o muy corto
            if len(original_text) < 1:
                print(f"[WARN] Transcripción vacía")
                await websocket.send_text(json.dumps({"type": "no_speech_detected"}))
                continue

            # TRADUCIR
            print(f"[TRANSLATION] Iniciando traducción: {source_lang} -> {target_lang}")
            translator = await pipeline_manager.get_translation_pipeline(source_lang, target_lang)
            
            if not translator:
                print(f"[ERROR] No se pudo cargar traductor {source_lang}->{target_lang}")
                await websocket.send_text(json.dumps({"type": "no_speech_detected"}))
                continue
            
            translation_result = translator(original_text)
            translated_text = translation_result[0]["translation_text"]
            print(f"[TRANSLATION] Traducido: '{translated_text}'")

            # ENVIAR RESULTADO
            response = {
                "type": "final_translation",
                "original_text": original_text,
                "translated_text": translated_text
            }
            await websocket.send_text(json.dumps(response))
            print(f"[RESPONSE] Enviado al frontend: {response}")
            
            # Intercambiar idiomas para siguiente turno
            print(f"[TURN END] Intercambiando idiomas: {source_lang}<->{target_lang}")
            source_lang, target_lang = target_lang, source_lang

    except WebSocketDisconnect:
        print("[INFO] Cliente desconectado.")
    except Exception as e:
        print(f"[ERROR] Error en WebSocket: {e}")
    finally:
        print("[INFO] Limpiando conexión WebSocket.")