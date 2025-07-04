import 'dart:async';
import '../models/message.dart';
import '../models/language.dart';
import '../services/audio_service.dart';
import '../services/vad_service.dart';
import '../services/tts_service.dart';
import '../services/websocket_service.dart';
import '../services/sound_service.dart';
import '../utils/logger.dart';

/// Estados de la conversación
enum ConversationState {
  idle,
  connecting,
  listening,
  processing,
  speaking,
  error
}

/// Gestor principal de la conversación que coordina todos los servicios
class ConversationManager {
  // Servicios
  final AudioService _audioService = AudioService();
  final VadService _vadService = VadService();
  final TtsService _ttsService = TtsService();
  final WebSocketService _webSocketService = WebSocketService();
  final SoundService _soundService = SoundService();

  // Estado
  ConversationState _currentState = ConversationState.idle;
  bool _isFullyDisconnected = false;
  String? _currentSpeaker;
  bool _isAudioStreamActive = false; // Para controlar envío de audio como en código original

  // Callbacks
  Function(Message)? onMessageAdded;
  Function({String? originalText, String? translatedText})? onMessageUpdated;
  Function()? onMessageRemoved;
  Function()? onTurnChanged;
  Function()? onStateChanged;
  Function()? getSilenceDuration; // Callback para obtener silenceDuration
  Function()? getTargetLanguageCode; // Callback para obtener código de idioma destino

  // Getters
  ConversationState get currentState => _currentState;
  bool get isActive => _currentState != ConversationState.idle && !_isFullyDisconnected;
  String? get currentSpeaker => _currentSpeaker;

  /// Inicializa todos los servicios
  Future<bool> initialize() async {
    try {
      logger.i("🚀 Inicializando ConversationManager...");
      
      await _ttsService.initialize();
      await _vadService.initialize();
      await _soundService.initialize();
      
      _setupServiceCallbacks();
      
      logger.i("✅ ConversationManager inicializado");
      return true;
    } catch (e, stackTrace) {
      logger.e("Error inicializando ConversationManager", error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Configura los callbacks de los servicios
  void _setupServiceCallbacks() {
    // VAD callbacks
    _vadService.onSpeechEnd = _onSpeechEndDetected;
    
    // WebSocket callbacks
    _webSocketService.onMessageReceived = _onWebSocketMessageReceived;
    _webSocketService.onError = (error) {
      logger.e("Error en WebSocket", error: error);
      stopConversation();
    };
    _webSocketService.onDisconnected = () {
      if (!_isFullyDisconnected) {
        logger.w("WebSocket desconectado inesperadamente");
        stopConversation();
      }
    };
  }

  /// Inicia una nueva conversación
  Future<bool> startConversation(Language sourceLang, Language targetLang) async {
    try {
      logger.i("🚀 Iniciando nueva conversación...");
      
      // Limpiar estado previo
      await _forceCleanupAll();
      _isFullyDisconnected = false;
      _currentSpeaker = 'source';
      _currentState = ConversationState.connecting;
      onStateChanged?.call();

      // Solicitar permisos de micrófono
      final hasPermission = await _audioService.requestMicrophonePermission();
      if (!hasPermission) {
        logger.e("❌ Sin permisos de micrófono");
        _currentState = ConversationState.error;
        onStateChanged?.call();
        return false;
      }

      // Conectar WebSocket
      final config = WebSocketConfig(
        sourceLanguage: sourceLang.code,
        targetLanguage: targetLang.code,
      );
      
      final connected = await _webSocketService.connect(config);
      if (!connected) {
        _currentState = ConversationState.error;
        onStateChanged?.call();
        return false;
      }

      // Reinicializar VAD
      await _vadService.reinitialize();

      // Iniciar primer ciclo de escucha
      await _startListeningCycle();
      
      return true;
    } catch (e, stackTrace) {
      logger.e("Error iniciando conversación", error: e, stackTrace: stackTrace);
      _currentState = ConversationState.error;
      onStateChanged?.call();
      return false;
    }
  }

  /// Detiene la conversación
  Future<void> stopConversation() async {
    logger.i("🛑 Deteniendo conversación...");
    
    _isFullyDisconnected = true;
    _currentState = ConversationState.idle;
    _currentSpeaker = null;
    
    await _forceCleanupAll();
    
    onStateChanged?.call();
    logger.i("✅ Conversación detenida");
  }

  /// Inicia un ciclo de escucha
  Future<void> _startListeningCycle() async {
    if (_isFullyDisconnected || _currentState == ConversationState.idle) {
      logger.w("❌ No se puede iniciar ciclo - conversación detenida");
      return;
    }

    logger.i("🎯 INICIANDO CICLO PARA: $_currentSpeaker");
    _currentState = ConversationState.listening;
    onStateChanged?.call();

    // Añadir mensaje temporal
    final message = Message(
      id: DateTime.now().toIso8601String(),
      isFromSource: _currentSpeaker == 'source',
      originalText: "Escuchando...",
      translatedText: "..."
    );
    onMessageAdded?.call(message);

    // Estabilización
    await Future.delayed(const Duration(milliseconds: 400));
    
    if (_isFullyDisconnected) return;

    // Iniciar grabación
    final audioStream = await _audioService.startContinuousRecording();
    if (audioStream == null) {
      logger.e("❌ No se pudo iniciar grabación");
      return;
    }

    // Configurar envío de audio al WebSocket
    _audioService.setupAudioStream(audioStream, (audioData) {
      // Replicar la lógica original: enviar mientras la sesión de audio esté activa
      if (_webSocketService.isConnected && !_isFullyDisconnected && _isAudioStreamActive) {
        _webSocketService.sendAudioData(audioData);
      }
    });

    // Activar stream de audio (equivale a _vadIsListening en código original)
    _isAudioStreamActive = true;

    // Delay antes de VAD
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Iniciar VAD
    if (!_isFullyDisconnected) {
      await _vadService.startListening();
    }
  }

  /// Maneja el fin de habla detectado por VAD
  Future<void> _onSpeechEndDetected() async {
    if (_isFullyDisconnected || _currentState != ConversationState.listening) return;
    
    logger.i("⏹️ Procesando fin de habla...");
    
    // DETENER VAD INMEDIATAMENTE (igual que en el código original)
    // PERO MANTENER EL AUDIO GRABANDO durante el período de silencio
    await _vadService.stopListening();
    logger.i("🎤 VAD detenido, pero audio sigue grabando para capturar final...");
    
    // Obtener tiempo de silencio configurado del provider
    double silenceDuration = 2.0; // Default
    if (getSilenceDuration != null) {
      try {
        silenceDuration = getSilenceDuration!() as double;
      } catch (e) {
        logger.w("Error obteniendo silenceDuration, usando default: $e");
      }
    }
    
    logger.i("⏳ Esperando ${silenceDuration}s de silencio (audio sigue grabando)...");
    
    // Esperar el tiempo de silencio configurado (igual que en código original)
    // IMPORTANTE: El audio sigue grabándose durante este tiempo para capturar el final
    await Future.delayed(Duration(milliseconds: (silenceDuration * 1000).round()));
    
    if (_isFullyDisconnected) return;

    // Cambiar estado a procesando
    _currentState = ConversationState.processing;
    onStateChanged?.call();
    
    // AHORA SÍ detener grabación y enviar señal (igual que código original)
    logger.i("🛑 Fin del período de silencio, deteniendo grabación y enviando al backend...");
    _isAudioStreamActive = false; // Detener envío de audio
    await _audioService.stopRecording();
    _webSocketService.sendEndOfSpeechEvent();
  }

  /// Maneja mensajes del WebSocket
  void _onWebSocketMessageReceived(Map<String, dynamic> data) {
    if (_isFullyDisconnected) return;

    switch (data['type']) {
      case 'final_translation':
        final originalText = data['original_text'] ?? '';
        final translatedText = data['translated_text'] ?? '';
        
        if (originalText.isNotEmpty && translatedText.isNotEmpty) {
          logger.i("✅ Traducción: '$originalText' -> '$translatedText'");
          onMessageUpdated?.call(
            originalText: originalText,
            translatedText: translatedText
          );
          _speakTextAndProceed(translatedText);
        } else {
          logger.w("❌ Traducción vacía");
          onMessageRemoved?.call();
          _startListeningCycle();
        }
        break;
      
      case 'no_speech_detected':
        logger.w("❌ No se detectó habla válida");
        onMessageRemoved?.call();
        _startListeningCycle();
        break;
        
      default:
        logger.w("❓ Mensaje desconocido: ${data['type']}");
        onMessageRemoved?.call();
        _startListeningCycle();
    }
  }

  /// Reproduce el texto traducido y procede al siguiente turno
  Future<void> _speakTextAndProceed(String textToSpeak) async {
    if (_isFullyDisconnected || textToSpeak.trim().isEmpty) {
      _nextTurn();
      return;
    }

    _currentState = ConversationState.speaking;
    onStateChanged?.call();

    // Determinar idioma de destino usando el mismo patrón que el código original
    String languageCode = 'es'; // Default
    if (getTargetLanguageCode != null) {
      try {
        languageCode = getTargetLanguageCode!() as String;
      } catch (e) {
        logger.w("Error obteniendo languageCode, usando default: $e");
      }
    }

    await _ttsService.speak(textToSpeak, languageCode);
    
    if (!_isFullyDisconnected) {
      _nextTurn();
    }
  }

  /// Cambia al siguiente turno
  Future<void> _nextTurn() async {
    if (_isFullyDisconnected) return;
    
    logger.i("🔄 CAMBIANDO TURNO");
    
    // Reproducir beep
    await _soundService.playTurnChangeBeep();
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (_isFullyDisconnected) return;
    
    // Cambiar hablante
    _currentSpeaker = (_currentSpeaker == 'source') ? 'target' : 'source';
    onTurnChanged?.call();
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Iniciar nuevo ciclo
    if (!_isFullyDisconnected) {
      await _startListeningCycle();
    }
  }

  /// Limpia completamente todos los recursos
  Future<void> _forceCleanupAll() async {
    logger.i("🧹 LIMPIEZA COMPLETA FORZADA...");
    
    _isAudioStreamActive = false;
    await _ttsService.stop();
    await _audioService.stopRecording();
    await _vadService.cleanup();
    await _webSocketService.disconnect();
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    logger.i("✅ Limpieza completa terminada");
  }

  /// Dispone de todos los recursos
  Future<void> dispose() async {
    await stopConversation();
    await _audioService.dispose();
    await _vadService.dispose();
    await _ttsService.dispose();
    await _webSocketService.dispose();
    await _soundService.dispose();
  }
}
