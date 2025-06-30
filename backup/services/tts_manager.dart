// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:just_audio/just_audio.dart';
// import '../../../../core/utils/logger.dart';

// class TtsManager {
//   final FlutterTts _flutterTts = FlutterTts();
//   final AudioPlayer _beepPlayer = AudioPlayer();
  
//   bool _isPlaying = false;
//   static const String _beepAssetPath = "assets/sounds/beep.mp3";

//   bool get isPlaying => _isPlaying;

//   Future<void> initialize() async {
//     await _initializeTts();
//     await _loadBeep();
//     logger.i("✅ TtsManager inicializado");
//   }

//   Future<void> _initializeTts() async {
//     await _flutterTts.setLanguage("es-ES");
//     await _flutterTts.setSpeechRate(0.5);
//     await _flutterTts.setVolume(1.0);
//     await _flutterTts.setPitch(1.0);
//   }

//   Future<void> _loadBeep() async {
//     try {
//       await _beepPlayer.setAsset(_beepAssetPath);
//     } catch (e) {
//       logger.e("Error cargando beep", error: e);
//     }
//   }

//   Future<void> speak(String text, String languageCode) async {
//     if (text.trim().isEmpty) return;
    
//     logger.i("🔊 TTS: '$text' en $languageCode");
//     _isPlaying = true;
    
//     try {
//       await _flutterTts.setLanguage(languageCode);
//       await _flutterTts.speak(text);
//       await _flutterTts.awaitSpeakCompletion(true);
//       logger.i("✅ TTS completado");
//     } catch (e, stackTrace) {
//       logger.e("❌ Error en TTS", error: e, stackTrace: stackTrace);
//     } finally {
//       _isPlaying = false;
//     }
//   }

//   Future<void> playBeep() async {
//     try {
//       await _beepPlayer.seek(Duration.zero);
//       _beepPlayer.play();
//       logger.i("🔔 Beep reproducido");
//     } catch (e) {
//       logger.w("❌ Error reproduciendo beep", error: e);
//     }
//   }

//   Future<void> stop() async {
//     _isPlaying = false;
//     try {
//       await _flutterTts.stop();
//     } catch (e) {
//       logger.w("Error deteniendo TTS", error: e);
//     }
//   }

//   Future<void> dispose() async {
//     logger.i("🧹 Limpiando TtsManager...");
//     await stop();
//     logger.i("✅ TtsManager limpiado");
//   }
// }