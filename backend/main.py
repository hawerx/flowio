import os
import base64
import json
import asyncio
from io import BytesIO
import torch
import soundfile as sf
import numpy as np
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from transformers import pipeline as hf_pipeline
from typing import Dict, Optional

# --- Configuración Inicial ---
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Usando dispositivo: {DEVICE}")

app = FastAPI()

# --- Carga de Modelos ---

# 1. Cargamos el modelo VAD de Silero
try:
    vad_model, utils = torch.hub.load(repo_or_dir='snakers4/silero-vad',
                                  model='silero_vad',
                                  force_reload=False)
    (get_speech_timestamps, _, read_audio, *_) = utils
    print("Modelo VAD cargado correctamente.")
except Exception as e:
    print(f"Error al cargar el modelo VAD. Creando función dummy. Error: {e}")
    # Si falla la carga (ej. sin internet), creamos una función que no hace nada para que la app no se bloquee
    def get_speech_timestamps(audio, model, sampling_rate): return []

# 2. Cargamos el modelo de Transcripción (Whisper)
print("Cargando modelo de Speech-to-Text (Whisper)...")
transcription_pipeline = hf_pipeline(
    "automatic-speech-recognition",
    model="openai/whisper-base",
    torch_dtype=torch.float16 if DEVICE == "cuda" else torch.float32,
    device=DEVICE,
)
print("Modelo de transcripción cargado.")

# 3. Gestor de Pipelines
class PipelineManager:
    def __init__(self):
        self.translation_pipelines: Dict[str, hf_pipeline] = {}

    async def get_translation_pipeline(self, source: str, target: str) -> Optional[hf_pipeline]:
        name = f"Helsinki-NLP/opus-mt-{source}-{target}"
        if name not in self.translation_pipelines:
            try:
                self.translation_pipelines[name] = hf_pipeline(f"translation_{source}_to_{target}", model=name, device=DEVICE)
            except Exception as e: print(f"Error al cargar modelo de traducción {name}: {e}"); return None
        return self.translation_pipelines.get(name)

pipeline_manager = PipelineManager()

# --- Lógica de Streaming del Backend ---
async def handle_stream(websocket: WebSocket, source_lang: str, target_lang: str):
    full_audio_bytes = bytearray()
    last_transcription = ""
    
    try:
        while True:
            message = await websocket.receive()
            if isinstance(message, str):
                data = json.loads(message)
                if data.get("event") == "end_of_speech":
                    print("Señal de fin de habla recibida.")
                    break
            elif isinstance(message, bytes):
                full_audio_bytes.extend(message)
                
                # Preparamos el audio para el VAD
                audio_np_vad = np.frombuffer(full_audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
                audio_tensor_vad = torch.from_numpy(audio_np_vad)

                # --- El "Portero" VAD ---
                speech_timestamps = get_speech_timestamps(audio_tensor_vad, vad_model, sampling_rate=16000)

                if not speech_timestamps:
                    # Si no hay voz, limpiamos el buffer para no acumular silencio
                    if len(full_audio_bytes) > 16000: # Mantenemos un poco de contexto
                        full_audio_bytes = full_audio_bytes[-8000:]
                    continue

                # --- Si VAD detecta voz, continuamos ---
                print("VAD detectó voz, transcribiendo...")
                partial_result = transcription_pipeline({"sampling_rate": 16000, "raw": audio_np_vad})
                partial_text = partial_result["text"].strip()
                
                # Solo enviamos la transcripción si es nueva y no es un artefacto
                if partial_text and partial_text != last_transcription:
                    last_transcription = partial_text
                    await websocket.send_text(json.dumps({
                        "type": "partial_transcription",
                        "text": partial_text
                    }))

    except WebSocketDisconnect:
        print("Cliente se desconectó durante el streaming.")
        return

    # --- Procesamiento Final ---
    print(f"Procesando transcripción final: '{last_transcription}'")
    
    if not last_transcription: return

    translation_pipeline = await pipeline_manager.get_translation_pipeline(source_lang, target_lang)
    if not translation_pipeline: return
        
    translated_text = translation_pipeline(last_transcription)[0]["translation_text"]

    await websocket.send_text(json.dumps({
        "type": "final_translation",
        "original_text": last_transcription,
        "translated_text": translated_text
    }))


@app.websocket("/ws/translate_stream")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("Cliente conectado para streaming.")
    try:
        config_message = await websocket.receive_json()
        if config_message.get("event") == "start":
            source_lang = config_message.get("source_lang")
            target_lang = config_message.get("target_lang")
            
            if not all([source_lang, target_lang]):
                await websocket.close(code=4000)
                return
            
            await handle_stream(websocket, source_lang, target_lang)
        
    except WebSocketDisconnect:
        print("Cliente desconectado al inicio.")
    except Exception as e:
        print(f"ERROR Inesperado: {e}")
