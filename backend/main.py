# backend/main.py
import os
import json
import asyncio
import numpy as np
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


@app.websocket("/ws/translate_stream")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("[INFO] Conexión WebSocket aceptada.")
    
    source_lang = None
    target_lang = None

    try:
        # 1. Esperar mensaje de configuración inicial
        config_message = await websocket.receive_json()
        print(f"[INFO] Mensaje de configuración recibido: {config_message}")
        if config_message.get("event") == "start":
            source_lang = config_message.get("source_lang")
            target_lang = config_message.get("target_lang")
            if not all([source_lang, target_lang]):
                await websocket.close(code=1003, reason="Falta source_lang o target_lang")
                return
        else:
            await websocket.close(code=1003, reason="El primer mensaje debe ser 'start'")
            return

        # 2. Bucle de conversación principal (un ciclo por turno)
        while True:
            print(f"\n[TURN START] Esperando audio para: {source_lang} -> {target_lang}")
            audio_buffer = bytearray()
            
            # 3. Bucle de recepción de datos para este turno
            while True:
                message = await websocket.receive()
                
                # [LA CORRECCIÓN CLAVE ESTÁ AQUÍ]
                # Inspeccionamos el diccionario del mensaje
                if "bytes" in message and message["bytes"] is not None:
                    chunk = message["bytes"]
                    audio_buffer.extend(chunk)
                    print(f"[DEBUG] Recibidos {len(chunk)} bytes. Buffer total: {len(audio_buffer)} bytes.")
                elif "text" in message and message["text"] is not None:
                    try:
                        data = json.loads(message["text"])
                        if data.get("event") == "end_of_speech":
                            print("[INFO] Señal 'end_of_speech' recibida. Finalizando recepción de audio.")
                            break # Salir del bucle de recepción
                    except json.JSONDecodeError:
                        print(f"[WARN] Recibido mensaje de texto no-JSON: {message['text']}")
            
            # 4. Procesar el audio del turno
            if not audio_buffer:
                print("[WARN] No se recibió audio. Saltando turno.")
                await websocket.send_text(json.dumps({"type": "no_speech_detected"}))
            else:
                print(f"[INFO] Procesando {len(audio_buffer)} bytes de audio...")
                audio_np = np.frombuffer(audio_buffer, dtype=np.int16).astype(np.float32) / 32768.0
                
                print(f"[INFO] Transcribiendo en '{source_lang}'...")
                result = transcription_pipeline({"sampling_rate": 16000, "raw": audio_np}, generate_kwargs={"language": source_lang})
                original_text = result["text"].strip()
                print(f"[INFO] Transcrito: '{original_text}'")

                if not original_text:
                    await websocket.send_text(json.dumps({"type": "no_speech_detected"}))
                else:
                    translator = await pipeline_manager.get_translation_pipeline(source_lang, target_lang)
                    if translator:
                        translated_text = translator(original_text)[0]["translation_text"]
                        print(f"[INFO] Traducido: '{translated_text}'")
                        await websocket.send_text(json.dumps({
                            "type": "final_translation",
                            "original_text": original_text,
                            "translated_text": translated_text
                        }))
                    else:
                        await websocket.send_text(json.dumps({"type": "error", "message": "Translation model failed to load"}))
            
            # 5. Intercambiar idiomas para el siguiente turno
            source_lang, target_lang = target_lang, source_lang
            print("[TURN END]")

    except WebSocketDisconnect:
        print(f"[INFO] Cliente desconectado.")
    except Exception as e:
        print(f"[FATAL ERROR] Error inesperado en el endpoint: {e}")
    finally:
        print("[INFO] Limpiando y cerrando conexión.")