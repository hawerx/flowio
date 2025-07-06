import 'dart:async';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';
import '../constants/constants.dart';

/// Servicio encargado de la gestión de grabación de audio
class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSub;
  
  bool get isRecording => _audioStreamSub != null;

  /// Solicita permisos de micrófono
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Inicia la grabación continua de audio
  Future<Stream<List<int>>?> startContinuousRecording() async {
    const recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: Constants.sampleRate,
      numChannels: Constants.numChannels,
    );

    try {
      // Forzar cierre de grabación previa si existe
      await _forceStopRecording();

      logger.i("🎙️ Iniciando NUEVA grabación de audio...");
      
      final audioStream = await _audioRecorder.startStream(recordConfig);
      logger.i("✅ Grabación continua iniciada correctamente");
      
      return audioStream;
    } catch (e, stackTrace) {
      logger.e("❌ Error iniciando grabación", error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Configura el listener del stream de audio
  void setupAudioStream(Stream<List<int>> audioStream, Function(List<int>) onData) {
    _audioStreamSub = audioStream.listen(
      onData,
      onError: (err) {
        logger.e("❌ Error en stream de audio", error: err);
      },
      onDone: () {
        logger.i("🏁 Stream de audio terminado");
      }
    );
  }

  /// Detiene la grabación de audio
  Future<void> stopRecording() async {
    try {
      logger.i("🧹 Deteniendo grabación de audio...");
      
      // Cancelar stream subscription
      if (_audioStreamSub != null) {
        await _audioStreamSub!.cancel();
        _audioStreamSub = null;
        logger.d("✅ Stream subscription cancelado");
      }
      
      // Detener grabación con verificación extra
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
        logger.d("✅ Grabación detenida");
        
        // Esperar para asegurar liberación
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      logger.i("🧹 Grabación de audio detenida");
    } catch (e) {
      logger.e("❌ Error deteniendo grabación", error: e);
    }
  }

  /// Fuerza el cierre de grabación previa
  Future<void> _forceStopRecording() async {
    bool wasRecording = await _audioRecorder.isRecording();
    if (wasRecording) {
      logger.w("🛑 FORZANDO cierre de grabación previa...");
      await _audioRecorder.stop();
      
      // Esperar más tiempo para asegurar liberación completa
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Verificar nuevamente
      if (await _audioRecorder.isRecording()) {
        logger.e("❌ No se pudo detener grabación previa");
        throw Exception("No se pudo detener grabación previa");
      }
    }
  }

  /// Limpia todos los recursos del servicio de audio
  Future<void> dispose() async {
    await stopRecording();
  }
}
