import 'dart:async';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';
import '../constants/constants.dart';

/// Servicio encargado de la grabación de audio
class AudioService {

  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSub;
  
  final List<List<int>> _audioBuffer  = [];     // Buffer para ir acumulando el audio 
  final List<List<int>> _preBuffer    = [];    // Prebuffer circular para capturar audio antes de la detección de voz
  static const int _maxPreBufferSize  = 15;   // ~0.5 segundos de audio
  bool _isPrebufferActive             = false;
  
  bool get isRecording => _audioStreamSub != null;

  /// Solicita los permisos para usar el  microfono
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Inicia solo el prebuffer
  Future<bool> startPreBuffer() async {
    const recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: Constants.AUDIO_SAMPLE_RATE,
      numChannels: Constants.AUDIO_NUM_CHANNELS,
    );

    try {
      // forzamos cierre de grabación previa si existe
      await _forceStopRecording();

      logger.i("Iniciando prebuffer de audio ...");
      
      final audioStream = await _audioRecorder.startStream(recordConfig);
      
      // Limpiamos buffers
      _preBuffer.clear();
      _audioBuffer.clear();
      _isPrebufferActive = true;
      
      // Configuramos prebuffer 
      _audioStreamSub = audioStream.listen(
        (audioData) {
          if (_isPrebufferActive) 
          {
            _preBuffer.add(audioData);
            
            if (_preBuffer.length > _maxPreBufferSize) _preBuffer.removeAt(0);
          } 
          else 
          {
            // Grabamos al buffer normal
            _audioBuffer.add(audioData);
          }
        },
        onError: (err) {
          logger.e("Error en stream de audio", error: err);
        },
        onDone: () {
          logger.i("Stream de audio terminado");
        }
      );
      
      logger.i("Prebuffer iniciado - capturando audio en buffer continuo");
      return true;
    } catch (e, stackTrace) {
      logger.e("Error iniciando prebuffer", error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Activa la grabación real y añade prebuffer al buffer principal
  void activateFullRecording() {
    
    if (!_isPrebufferActive) {
      logger.w("Prebuffer no está activo");
      return;
    }
    
    logger.i("Activando grabación completa - añadiendo prebuffer...");
    
    // Transferir prebuffer al buffer principal
    _audioBuffer.addAll(_preBuffer);
    _preBuffer.clear();
    _isPrebufferActive = false;
    
    logger.i("Prebuffer transferido (${_audioBuffer.length} chunks), grabación activa");
  }

/*   /// Inicia la grabación continua de audio (modo legacy)
  Future<bool> startContinuousRecording() async {
    // Por compatibilidad - activa grabación inmediata si prebuffer no está activo
    if (!_isPrebufferActive) {
      logger.i("🔄 Iniciando grabación directa (modo legacy)");
      return await startPreBuffer();
    } else {
      // Si prebuffer está activo, solo activar grabación completa
      activateFullRecording();
      return true;
    }
  } */

  /// Obtiene todo el audio acumulado y limpia el buffer
  List<int> getAccumulatedAudio() {
    if (_audioBuffer.isEmpty) return [];
    
    // Concatenar todos los chunks en un solo array
    final result = <int>[];
    result.addAll(_audioBuffer.expand((chunk) => chunk));
    
    logger.i("Audio acumulado : ${_audioBuffer.length} chunks, ${result.length} samples total");
    
    // Limpiar buffer después de obtener datos
    _audioBuffer.clear();
    
    return result;
  }

  /// Detiene la grabación de audio
  Future<void> stopRecording() async {
    try {
      logger.i("Deteniendo grabación de audio...");
      
      // Cancelar stream subscription
      if (_audioStreamSub != null) {
        await _audioStreamSub!.cancel();
        _audioStreamSub = null;
        logger.d("Stream subscription cancelado");
      }
      
      // Detener grabación con verificación extra
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
        logger.d("Grabación detenida");
        
        // Esperar para asegurar liberación
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      logger.i("Grabación de audio detenida");
    } catch (e) {
      logger.e("Error deteniendo grabación", error: e);
    }
  }

  /// Fuerza el cierre de grabación previa
  Future<void> _forceStopRecording() async {
    bool wasRecording = await _audioRecorder.isRecording();
    if (wasRecording) {
      logger.w("FORZANDO cierre de grabacion previa...");
      await _audioRecorder.stop();
      
      // Esperar más tiempo para asegurar liberación completa
      await Future.delayed(const Duration(milliseconds: 800));
      
      // verficamos nuevamente
      if (await _audioRecorder.isRecording()) {
        logger.e("No se pudo detener grabación previa");
        throw Exception("No se pudo detener grabación previa");
      }
    }
  }

  Future<void> dispose() async {
    await stopRecording();
  }
}
