import 'dart:async';
import 'package:vad/vad.dart';
import '../utils/logger.dart';

/// Estados del VAD
enum VadState {
  idle,
  listening,
  speechDetected,
  speechEnded
}

/// Servicio encargado de la detección de voz (VAD)
class VadService {
  VadHandlerBase? _vad;
  StreamSubscription? _onSpeechStartSub;
  StreamSubscription? _onSpeechEndSub;
  
  VadState _currentState = VadState.idle;
  
  /// Callbacks para eventos de VAD
  Function()? onSpeechStart;
  Function()? onSpeechEnd;
  
  VadState get currentState => _currentState;
  bool get isListening => _currentState == VadState.listening;

  /// Inicializa el VAD
  Future<void> initialize() async {
    try {
      // Limpiar VAD previo si existe
      await cleanup();
      
      _vad = VadHandler.create(isDebug: false);
      
      _onSpeechStartSub = _vad?.onRealSpeechStart.listen((_) {
        if (_currentState == VadState.listening) {
          logger.i("🎤 VAD: Inicio de habla detectado");
          _currentState = VadState.speechDetected;
          onSpeechStart?.call();
        }
      });
      
      _onSpeechEndSub = _vad?.onSpeechEnd.listen((_) {
        if (_currentState == VadState.speechDetected) {
          logger.i("🛑 VAD: Fin de habla detectado");
          _currentState = VadState.speechEnded;
          onSpeechEnd?.call();
        }
      });

      logger.i("✅ VAD configurado");
    } catch (e, stackTrace) {
      logger.e("Error configurando VAD", error: e, stackTrace: stackTrace);
    }
  }

  /// Inicia la escucha del VAD
  Future<void> startListening() async {
    try {
      if (_vad != null && _currentState == VadState.idle) {
        await _vad!.startListening();
        _currentState = VadState.listening;
        logger.i("✅ VAD iniciado para turno actual");
      }
    } catch (e) {
      logger.e("Error iniciando VAD", error: e);
    }
  }

  /// Detiene la escucha del VAD
  Future<void> stopListening() async {
    try {
      if (_vad != null && _currentState != VadState.idle) {
        await _vad!.stopListening();
        _currentState = VadState.idle;
        logger.i("🛑 VAD detenido");
      }
    } catch (e) {
      logger.e("Error deteniendo VAD", error: e);
    }
  }

  /// Limpia todos los recursos del VAD
  Future<void> cleanup() async {
    try {
      logger.i("🧹 Limpiando VAD...");
      
      await _onSpeechStartSub?.cancel();
      await _onSpeechEndSub?.cancel();
      _onSpeechStartSub = null;
      _onSpeechEndSub = null;
      
      if (_vad != null && _currentState != VadState.idle) {
        await _vad!.stopListening();
      }
      
      _currentState = VadState.idle;
      _vad = null;
      
      logger.i("✅ VAD limpiado");
    } catch (e) {
      logger.e("Error limpiando VAD", error: e);
    }
  }

  /// Reinicializa completamente el VAD
  Future<void> reinitialize() async {
    logger.i("🔄 Reinicializando VAD completamente...");
    
    await cleanup();
    await Future.delayed(const Duration(milliseconds: 300));
    await initialize();
    
    logger.i("✅ VAD reinicializado");
  }

  /// Dispone de todos los recursos
  Future<void> dispose() async {
    await cleanup();
  }
}
