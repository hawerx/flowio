import 'package:flutter_tts/flutter_tts.dart';
import '../utils/logger.dart';
import '../constants/constants.dart';
class TtsService {

  final FlutterTts _flutterTts  = FlutterTts();
  bool _isProcessing            = false;

  bool get isProcessing => _isProcessing;

  /// Inicializa el servicio TtS
  Future<void> initialize() async {
    try {
      await _flutterTts.setSpeechRate(Constants.TTS_DEFAULT_SPEECH_RATE);
      await _flutterTts.setVolume(Constants.TTS_DEFAULT_VOLUME);
      await _flutterTts.setPitch(Constants.TTS_DEFAULT_PITCH);
      logger.i("TTS inicializado");
    } catch (e, stackTrace) {
      logger.e("Error inicializando TTS", error: e, stackTrace: stackTrace);
    }
  }

  /// Mapeo de codigos de lang a codigos tts
  static const Map<String, String> _languageMap = {
    'es': 'es-ES',
    'en': 'en-US',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'it': 'it-IT',
    'pt': 'pt-PT',
    'ru': 'ru-RU',
    'zh': 'zh-CN',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'ar': 'ar-SA',
    'hi': 'hi-IN',
    'th': 'th-TH',
    'vi': 'vi-VN',
    'nl': 'nl-NL',
    'sv': 'sv-SE',
    'da': 'da-DK',
    'no': 'no-NO',
    'fi': 'fi-FI',
    'pl': 'pl-PL',
    'cs': 'cs-CZ',
    'hu': 'hu-HU',
    'ro': 'ro-RO',
    'bg': 'bg-BG',
    'hr': 'hr-HR',
    'sk': 'sk-SK',
    'sl': 'sl-SI',
    'et': 'et-EE',
    'lv': 'lv-LV',
    'lt': 'lt-LT',
    'el': 'el-GR',
    'tr': 'tr-TR',
    'he': 'he-IL',
    'fa': 'fa-IR',
    'ur': 'ur-PK',
    'bn': 'bn-BD',
    'ta': 'ta-IN',
    'te': 'te-IN',
    'mr': 'mr-IN',
    'gu': 'gu-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'pa': 'pa-IN',
    'id': 'id-ID',
    'ms': 'ms-MY',
    'tl': 'tl-PH',
    'sw': 'sw-KE',
    'zu': 'zu-ZA',
    'af': 'af-ZA',
    'am': 'am-ET',
    'ig': 'ig-NG',
    'yo': 'yo-NG',
    'ha': 'ha-NG',
    'es-ar': 'es-AR',
    'es-mx': 'es-MX',
    'pt-br': 'pt-BR',
    'fr-ca': 'fr-CA',
  };

  String _mapLanguageCodeToTts(String languageCode) {
    final mapped = _languageMap[languageCode.toLowerCase()];
    if (mapped != null) return mapped;
    
    logger.w("Codigo de idioma no mapeado: $languageCode, usando default");
    return languageCode.contains('-') ? languageCode : '$languageCode-${languageCode.toUpperCase()}';
  }

  /// sintetiza el texto proporcionado en el idioma especificado por codigo
  Future<void> speak(String text, String languageCode) async {
    if (text.trim().isEmpty) {
      logger.w(" Texto vacío para TTS");
      return;
    }

    final ttsLanguageCode = _mapLanguageCodeToTts(languageCode);
    logger.i("TTS: '$text' en idioma: $languageCode -> $ttsLanguageCode");
    _isProcessing = true;

    try {
      await _flutterTts.setLanguage(ttsLanguageCode);
      await _flutterTts.speak(text);
      await _flutterTts.awaitSpeakCompletion(true);
      logger.i("TTS finalizado");
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
      logger.i("TTS detenido");
    } catch (e) {
      logger.w("Error deteniendo TTS", error: e);
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}
