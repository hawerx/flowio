import 'dart:async';
import 'package:record/record.dart';
import 'package:vad/vad.dart';
import '../../../../core/utils/logger.dart';

class AudioManager {
  final AudioRecorder _audioRecorder = AudioRecorder();
  VadHandlerBase? _vad;
  StreamSubscription<List<int>>? _audioStreamSub;
  StreamSubscription? _onSpeechStartSub;
  StreamSubscription? _onSpeechEndSub;
  
  bool _vadIsListening = false;
  bool _isRecording = false;
  Function()? _onSpeechEndCallback;

  // Configuración constante
  static const RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,       
  );

  bool get isVadListening => _vadIsListening;
  bool get isRecording => _isRecording;

  Future<void> initialize() async {
    await _initializeVad();
    logger.i("✅ AudioManager inicializado");
  }

  Future<void> _initializeVad() async {
    await _cleanupVad();
    
    _vad = VadHandler.create(isDebug: false);
    
    _onSpeechStartSub = _vad?.onRealSpeechStart.listen((_) {
      if (_vadIsListening) {
        logger.i("🎤 VAD: Inicio de habla detectado");
      }
    });
    
    _onSpeechEndSub = _vad?.onSpeechEnd.listen((_) {
      if (_vadIsListening) {
        logger.i("🛑 VAD: Fin de habla detectado");
        _onSpeechEndCallback?.call();
      }
    });
  }

  Future<void> startListening({
    required Function(List<int>) onAudioData,
    required Function() onSpeechEnd,
  }) async {
    _onSpeechEndCallback = onSpeechEnd;
    
    // Limpiar recursos previos
    await _stopAll();
    
    // Esperar estabilización
    await Future.delayed(const Duration(milliseconds: 400));
    
    // Iniciar grabación
    await _startRecording(onAudioData);
    
    // Esperar antes de VAD
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Iniciar VAD
    await _startVad();
  }

  Future<void> _startRecording(Function(List<int>) onAudioData) async {
    // Verificar y cerrar grabación previa
    if (await _audioRecorder.isRecording()) {
      logger.w("🛑 Cerrando grabación previa...");
      await _audioRecorder.stop();
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (await _audioRecorder.isRecording()) {
        throw Exception("No se pudo cerrar grabación previa");
      }
    }
    
    logger.i("🎙️ Iniciando grabación de audio...");
    
    final audioStream = await _audioRecorder.startStream(_recordConfig);
    _audioStreamSub = audioStream.listen(
      (data) {
        if (data.isNotEmpty && _vadIsListening) {
          onAudioData(data);
        }
      },
      onError: (err) => logger.e("❌ Error en stream de audio", error: err),
      onDone: () => logger.i("🏁 Stream de audio terminado"),
    );
    
    _isRecording = true;
    logger.i("✅ Grabación iniciada");
  }

  Future<void> _startVad() async {
    if (_vad != null && !_vadIsListening) {
      await _vad!.startListening();
      _vadIsListening = true;
      logger.i("✅ VAD iniciado");
    }
  }

  Future<void> stopVad() async {
    if (_vad != null && _vadIsListening) {
      await _vad!.stopListening();
      _vadIsListening = false;
      logger.i("🛑 VAD detenido");
    }
  }

  Future<void> _stopRecording() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    _isRecording = false;
    logger.i("🛑 Grabación detenida");
  }

  Future<void> _stopAll() async {
    await stopVad();
    await _stopRecording();
    _onSpeechEndCallback = null;
  }

  Future<void> _cleanupVad() async {
    await _onSpeechStartSub?.cancel();
    await _onSpeechEndSub?.cancel();
    _onSpeechStartSub = null;
    _onSpeechEndSub = null;
    
    if (_vad != null && _vadIsListening) {
      await _vad!.stopListening();
    }
    
    _vadIsListening = false;
    _vad = null;
  }

  Future<void> reinitialize() async {
    logger.i("🔄 Reinicializando AudioManager...");
    await dispose();
    await Future.delayed(const Duration(milliseconds: 500));
    await initialize();
    logger.i("✅ AudioManager reinicializado");
  }

  Future<void> dispose() async {
    logger.i("🧹 Limpiando AudioManager...");
    await _stopAll();
    await _cleanupVad();
    logger.i("✅ AudioManager limpiado");
  }
}