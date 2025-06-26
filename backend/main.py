# main.py - Versión final y robusta para el backend de IA

# --- 1. Fichero `requirements.txt` ---
# Este es el contenido que debe tener tu fichero `requirements.txt` en el Space de Hugging Face.
"""
fastapi
uvicorn
python-socketio
websockets
torch
torchaudio
transformers
accelerate
pyannote.audio
soundfile
pydub
"""

# --- 2. Código del Servidor (main.py) ---
import os
import asyncio
import base64
from io import BytesIO
import torch
import soundfile as sf
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from pyannote.audio import Pipeline as DiarizationPipeline
from transformers import pipeline as hf_pipeline
from typing import Dict, Optional

# --- Configuración Inicial y Carga de Modelos Base ---
# Asegúrate de tener un token de Hugging Face en los secretos de tu Space (HF_TOKEN)
HF_TOKEN = os.environ.get("HF_TOKEN")
if not HF_TOKEN:
    raise ValueError("Se necesita un token de Hugging Face. Añádelo a los secretos de tu Space como HF_TOKEN.")

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Usando dispositivo: {DEVICE}")

app = FastAPI()

print("Cargando modelo de diarización de hablantes...")
diarization_pipeline = DiarizationPipeline.from_pretrained(
    "pyannote/speaker-diarization-3.1",
    use_auth_token=HF_TOKEN
).to(torch.device(DEVICE))
print("Modelo de diarización cargado.")

print("Cargando modelo de Speech-to-Text (Whisper)...")
transcription_pipeline = hf_pipeline(
    "automatic-speech-recognition",
    model="openai/whisper-large-v3", # Usamos un modelo grande para mejor precisión y detección de idioma
    torch_dtype=torch.float16,
    device=DEVICE,
)
print("Modelo de transcripción cargado.")
print("--- Todos los modelos base cargados. Servidor listo. ---")


# --- Gestor de Pipelines de Traducción por Sesión ---
# Carga y cachea los modelos de traducción y TTS para evitar recargarlos.
class PipelineManager:
    def __init__(self):
        self.translation_pipelines: Dict[str, hf_pipeline] = {}
        self.tts_pipelines: Dict[str, hf_pipeline] = {}
        self.lang_code_map = self._create_lang_code_map()

    def _create_lang_code_map(self) -> Dict[str, str]:
        # Mapea códigos de 2 letras (ISO 639-1) a 3 letras (ISO 639-3) para el modelo MMS-TTS
        return {
            'ab': 'abk', 'aa': 'aar', 'af': 'afr', 'ak': 'aka', 'sq': 'sqi', 'am': 'amh', 'ar': 'ara', 'an': 'arg', 'hy': 'hye', 'as': 'asm', 'av': 'ava',
            'ae': 'ave', 'ay': 'aym', 'az': 'aze', 'bm': 'bam', 'ba': 'bak', 'eu': 'eus', 'be': 'bel', 'bn': 'ben', 'bi': 'bis', 'bs': 'bos', 'br': 'bre',
            'bg': 'bul', 'my': 'mya', 'ca': 'cat', 'ch': 'cha', 'ce': 'che', 'ny': 'nya', 'zh': 'zho', 'cv': 'chv', 'kw': 'cor', 'co': 'cos', 'cr': 'cre',
            'hr': 'hrv', 'cs': 'ces', 'da': 'dan', 'dv': 'div', 'nl': 'nld', 'dz': 'dzo', 'en': 'eng', 'eo': 'epo', 'et': 'est', 'ee': 'ewe', 'fo': 'fao',
            'fj': 'fij', 'fi': 'fin', 'fr': 'fra', 'ff': 'ful', 'gl': 'glg', 'ka': 'kat', 'de': 'deu', 'el': 'ell', 'gn': 'grn', 'gu': 'guj', 'ht': 'hat',
            'ha': 'hau', 'he': 'heb', 'hz': 'her', 'hi': 'hin', 'ho': 'hmo', 'hu': 'hun', 'ia': 'ina', 'id': 'ind', 'ie': 'ile', 'ga': 'gle', 'ig': 'ibo',
            'ik': 'ipk', 'io': 'ido', 'is': 'isl', 'it': 'ita', 'iu': 'iku', 'ja': 'jpn', 'jv': 'jav', 'kl': 'kal', 'kn': 'kan', 'kr': 'kau', 'ks': 'kas',
            'kk': 'kaz', 'km': 'khm', 'ki': 'kik', 'rw': 'kin', 'ky': 'kir', 'kv': 'kom', 'kg': 'kon', 'ko': 'kor', 'ku': 'kur', 'kj': 'kua', 'la': 'lat',
            'lb': 'ltz', 'lg': 'lug', 'li': 'lim', 'ln': 'lin', 'lo': 'lao', 'lt': 'lit', 'lu': 'lub', 'lv': 'lav', 'gv': 'glv', 'mk': 'mkd', 'mg': 'mlg',
            'ms': 'msa', 'ml': 'mal', 'mt': 'mlt', 'mi': 'mri', 'mr': 'mar', 'mh': 'mah', 'mn': 'mon', 'na': 'nau', 'nv': 'nav', 'nd': 'nde', 'ne': 'nep',
            'ng': 'ndo', 'nb': 'nob', 'nn': 'nno', 'no': 'nor', 'ii': 'iii', 'nr': 'nbl', 'oc': 'oci', 'oj': 'oji', 'cu': 'chu', 'om': 'orm', 'or': 'ori',
            'os': 'oss', 'pa': 'pan', 'pi': 'pli', 'fa': 'fas', 'pl': 'pol', 'ps': 'pus', 'pt': 'por', 'qu': 'que', 'rm': 'roh', 'rn': 'run', 'ro': 'ron',
            'ru': 'rus', 'sa': 'san', 'sc': 'srd', 'sd': 'snd', 'se': 'sme', 'sm': 'smo', 'sg': 'sag', 'sr': 'srp', 'gd': 'gla', 'sn': 'sna', 'si': 'sin',
            'sk': 'slk', 'sl': 'slv', 'so': 'som', 'st': 'sot', 'es': 'spa', 'su': 'sun', 'sw': 'swa', 'ss': 'ssw', 'sv': 'swe', 'ta': 'tam', 'te': 'tel',
            'tg': 'tgk', 'th': 'tha', 'ti': 'tir', 'bo': 'bod', 'tk': 'tuk', 'tl': 'tgl', 'tn': 'tsn', 'to': 'ton', 'tr': 'tur', 'ts': 'tso', 'tt': 'tat',
            'tw': 'twi', 'ty': 'tah', 'ug': 'uig', 'uk': 'ukr', 'ur': 'urd', 'uz': 'uzb', 've': 'ven', 'vi': 'vie', 'vo': 'vol', 'wa': 'wln', 'cy': 'cym',
            'wo': 'wol', 'fy': 'fry', 'xh': 'xho', 'yi': 'yid', 'yo': 'yor', 'za': 'zha', 'zu': 'zul'
        }

    async def get_translation_pipeline(self, source_lang: str, target_lang: str) -> Optional[hf_pipeline]:
        model_name = f"Helsinki-NLP/opus-mt-{source_lang}-{target_lang}"
        if model_name not in self.translation_pipelines:
            print(f"Cargando modelo de traducción: {model_name}")
            try:
                pipeline = hf_pipeline(f"translation_{source_lang}_to_{target_lang}", model=model_name, device=DEVICE)
                self.translation_pipelines[model_name] = pipeline
            except Exception as e:
                print(f"Error al cargar el modelo de traducción {model_name}: {e}")
                return None # Devolver None para manejar el error de forma segura
        return self.translation_pipelines.get(model_name)

    async def get_tts_pipeline(self, lang_2_letter: str) -> Optional[hf_pipeline]:
        lang_3_letter = self.lang_code_map.get(lang_2_letter)
        if not lang_3_letter:
            print(f"Advertencia: No se encontró el código de 3 letras para el idioma '{lang_2_letter}'. TTS no disponible.")
            return None
        
        model_name = f"facebook/mms-tts-{lang_3_letter}"
        if model_name not in self.tts_pipelines:
            print(f"Cargando modelo TTS: {model_name}")
            try:
                pipeline = hf_pipeline("text-to-speech", model=model_name, device=DEVICE)
                self.tts_pipelines[model_name] = pipeline
            except Exception as e:
                print(f"Error al cargar el modelo TTS {model_name}: {e}")
                return None
        return self.tts_pipelines.get(model_name)

pipeline_manager = PipelineManager()

# --- Endpoint de WebSocket ---
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, target_lang: str = "en"):
    await websocket.accept()
    print(f"Cliente conectado. Idioma objetivo: {target_lang}")

    # Variables de estado para esta conexión
    source_lang: Optional[str] = None
    speaker_language_map: Dict[str, str] = {}
    
    try:
        while True:
            # 1. Recibir y guardar audio
            audio_bytes = await websocket.receive_bytes()
            audio_buffer = BytesIO(audio_bytes)
            
            with open("temp_audio.wav", "wb") as f:
                f.write(audio_buffer.getvalue())

            # 2. Diarización de hablantes
            diarization = diarization_pipeline("temp_audio.wav", num_speakers=2) # Optimización para dos hablantes
            
            if not diarization.get_timeline():
                print("No se detectó habla en el fragmento de audio.")
                continue

            # 3. Procesar cada segmento de voz detectado
            for segment, _, speaker_id in diarization.itertracks(yield_label=True):
                await websocket.send_json({"type": "processing_start", "speakerId": speaker_id})

                # 4. Detección de Idioma (solo en la primera intervención)
                if source_lang is None:
                    transcription_result = transcription_pipeline("temp_audio.wav", return_timestamps=False)
                    # Whisper v3 devuelve el idioma detectado en los metadatos
                    detected_lang = transcription_result.get("chunks", [{}])[0].get("language", "en")
                    source_lang = detected_lang
                    speaker_language_map[speaker_id] = source_lang
                    print(f"Idioma de origen detectado: {source_lang}. Conversación: {source_lang} <-> {target_lang}")
                
                if speaker_id not in speaker_language_map:
                    speaker_language_map[speaker_id] = target_lang

                current_speaker_lang = speaker_language_map[speaker_id]
                lang_to_translate_to = target_lang if current_speaker_lang == source_lang else source_lang

                # 5. Transcripción del segmento específico
                waveform, sample_rate = sf.read("temp_audio.wav")
                start_frame = int(segment.start * sample_rate)
                end_frame = int(segment.end * sample_rate)
                segment_audio = waveform[start_frame:end_frame]
                
                transcription_result = transcription_pipeline(
                    {"sampling_rate": sample_rate, "raw": segment_audio},
                    generate_kwargs={"task": "transcribe", "language": f"<|{current_speaker_lang}|>"}
                )
                original_text = transcription_result["text"].strip()
                if not original_text: continue
                await websocket.send_json({"type": "transcription_update", "speakerId": speaker_id, "originalText": original_text})

                # 6. Traducción Dinámica
                translation_pipeline = await pipeline_manager.get_translation_pipeline(current_speaker_lang, lang_to_translate_to)
                if not translation_pipeline: continue
                
                translated_text = translation_pipeline(original_text)[0]["translation_text"]
                await websocket.send_json({"type": "translation_update", "translatedText": translated_text})

                # 7. TTS Dinámico
                tts_pipeline = await pipeline_manager.get_tts_pipeline(lang_to_translate_to)
                if tts_pipeline:
                    tts_output = tts_pipeline(translated_text)
                    tts_audio, tts_sample_rate = tts_output["audio"][0], tts_output["sampling_rate"]
                    
                    buffer = BytesIO()
                    sf.write(buffer, tts_audio, tts_sample_rate, format='WAV')
                    buffer.seek(0)
                    audio_b64 = base64.b64encode(buffer.read()).decode('utf-8')
                    await websocket.send_json({"type": "audio_output", "audioData": audio_b64})
                else:
                    print(f"Saltando TTS: no se encontró modelo para el idioma '{lang_to_translate_to}'")

    except WebSocketDisconnect:
        print("Cliente desconectado.")
    except Exception as e:
        print(f"Ocurrió un error inesperado en la conexión WebSocket: {e}")
        try:
            await websocket.close(code=1011, reason=str(e))
        except Exception:
            pass
