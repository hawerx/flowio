import 'package:flutter_tts/flutter_tts.dart';
import '../utils/logger.dart';
import '../constants/constants.dart';

/// Servicio encargado de la síntesis de voz (TTS)
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  /// Inicializa el servicio TTS
  Future<void> initialize() async {
    try {
      await _flutterTts.setLanguage("es-ES");
      await _flutterTts.setSpeechRate(Constants.ttsDefaultSpeechRate);
      await _flutterTts.setVolume(Constants.ttsDefaultVolume);
      await _flutterTts.setPitch(Constants.ttsDefaultPitch);
      logger.i("✅ TTS inicializado");
    } catch (e, stackTrace) {
      logger.e("Error inicializando TTS", error: e, stackTrace: stackTrace);
    }
  }

  /// Habla el texto proporcionado en el idioma especificado
  Future<void> speak(String text, String languageCode) async {
    if (text.trim().isEmpty) {
      logger.w("❌ Texto vacío para TTS");
      return;
    }

    logger.i("🔊 TTS: '$text' en idioma: $languageCode");
    _isProcessing = true;

    try {
      await _flutterTts.setLanguage(languageCode);
      await _flutterTts.speak(text);
      await _flutterTts.awaitSpeakCompletion(true);
      logger.i("✅ TTS completado");
    } catch (e, stackTrace) {
      logger.e("Error en TTS", error: e, stackTrace: stackTrace);
    } finally {
      _isProcessing = false;
    }
  }

  /// Detiene el TTS si está en proceso
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isProcessing = false;
      logger.i("🛑 TTS detenido");
    } catch (e) {
      logger.w("Error deteniendo TTS", error: e);
    }
  }

  /// Dispone de todos los recursos
  Future<void> dispose() async {
    await stop();
  }
}
