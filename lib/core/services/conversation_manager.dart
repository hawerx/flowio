import 'dart:async';
import '../models/message.dart';
import '../models/language.dart';
import '../services/audio_service.dart';
import '../services/vad_service.dart';
import '../services/tts_service.dart';
import '../services/websocket_service.dart';
import '../services/sound_service.dart';
import '../utils/logger.dart';

enum ConversationState {
  idle,
  connecting,
  listening,
  processing,
  speaking,
  error
}

/// Manager de la conversación que coordina todos los servicios
class ConversationManager {

  // Servicios de los que se encarga el manager
  final AudioService      _audioService     = AudioService();
  final VadService        _vadService       = VadService();
  final TtsService        _ttsService       = TtsService();
  final WebSocketService  _webSocketService = WebSocketService();
  final SoundService      _soundService     = SoundService();

  // Estado
  ConversationState _currentState = ConversationState.idle;
  bool _isFullyDisconnected       = false;
  bool _isRecording               = false; 
  String? _currentSpeaker;

  // Callbacks
  void Function(Message)? onMessageAdded;
  void Function({String?  originalText, String? translatedText})? onMessageUpdated;
  void Function()?        onMessageRemoved;
  void Function()?        onTurnChanged;
  void Function()?        onStateChanged;
  
  // Callbacks de configuracion
  double Function()? getSilenceDuration;
  String Function()? getTargetLanguageCode;

  // Getters
  ConversationState get currentState  => _currentState;
  String?           get currentSpeaker=> _currentSpeaker;
  bool              get isActive      => _currentState != ConversationState.idle && !_isFullyDisconnected;
  bool              get isListening   => _currentState == ConversationState.listening;
  bool              get isProcessing  => _currentState == ConversationState.processing;
  bool              get isSpeaking    => _currentState == ConversationState.speaking;
  bool              get isConnecting  => _currentState == ConversationState.connecting;
  bool              get hasError      => _currentState == ConversationState.error;
  bool              get isIdle        => _currentState == ConversationState.idle;

  /// Inicializa todos los servicios
  Future<bool> initialize() async {
    try {
      logger.i("Inicializando ConversationManager...");
      
      await _ttsService.initialize();
      await _vadService.initialize();
      await _soundService.initialize();
      
      _setupServiceCallbacks();
      
      logger.i("ConversationManager inicializado");
      return true;
    } catch (e, stackTrace) {
      logger.e("Error inicializando ConversationManager", error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Configura los callbacks de los servicios
  void _setupServiceCallbacks() {
    
    // VAD callbacks
    _vadService.onSpeechStart = _onSpeechStartDetected;
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
      logger.i("Iniciando nueva conversación...");
      
      // Limpiamos estado previo
      await _forceCleanupAll();
      _isFullyDisconnected = false;
      _currentSpeaker = 'source';
      _currentState = ConversationState.connecting;
      onStateChanged?.call();

      // solicitamos permisos de micrófono
      final hasPermission = await _audioService.requestMicrophonePermission();
      if (!hasPermission) {
        logger.e(" Sin permisos de micrófono");
        _currentState = ConversationState.error;
        onStateChanged?.call();
        return false;
      }

      // conectamos WebSocket
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

      // Solo reinicializar VAD si hay problemas o es la primera vez
      if (_vadService.currentState == VadState.idle) {
        await _vadService.initialize();
      } else {
        // Solo limpieza ligera si ya está inicializado
        await _vadService.cleanup();
        await _vadService.initialize();
      }

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
    logger.i("Deteniendo conversación...");
    
    _isFullyDisconnected = true;
    _currentState = ConversationState.idle;
    _currentSpeaker = null;
    
    await _forceCleanupAll();
    
    onStateChanged?.call();
    logger.i("Conversación detenida");
  }

  /// Inicia un ciclo de escucha
  Future<void> _startListeningCycle() async {
    if (_isFullyDisconnected || _currentState == ConversationState.idle) {
      logger.w("No se puede iniciar ciclo - conversación detenida");
      return;
    }

    logger.i("INICIANDO CICLO PARA: $_currentSpeaker");
    
    // Cambiar estado a escuchando
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

    // Estabilización más corta
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (_isFullyDisconnected) return;

    // Iniciar prebuffer de audio (captura pero no procesa)
    final success = await _audioService.startPreBuffer();
    if (!success) {
      logger.e("No se pudo iniciar prebuffer de audio");
      return;
    }

    logger.i("Prebuffer de audio activo - capturando audio en buffer circular...");

    await Future.delayed(const Duration(milliseconds: 150));
    
    // Iniciamos  VAD y esperanoms detección de voz para activar grabación real
    if (!_isFullyDisconnected) {
      await _vadService.startListening();
      logger.i("VAD activo - esperando detección de voz para activar grabación completa");
    }
  }

  /// Maneja el inicio de habla detectado por VAD
  void _onSpeechStartDetected() {
    if (_isFullyDisconnected || _currentState != ConversationState.listening) return;
    
    logger.i("¡Inicio de habla detectada! Activando grabación completa con prebuffer...");
    
    // transferimos el prebuffer al buffer principal
    _audioService.activateFullRecording();
    _isRecording = true;
    
    logger.i("Grabación completa activada - prebuffer transferido al buffer principal");
  }

  /// Maneja el fin de habla detectado por VAD
  Future<void> _onSpeechEndDetected() async {
    if (_isFullyDisconnected || _currentState != ConversationState.listening) return;
    
    logger.i("⏹Procesando fin de habla...");
    
    await _vadService.stopListening();
    logger.i("VAD detenido, pero audio sigue grabando para capturar final...");
    
    // Obtener tiempo de silencio configurado del provider
    double silenceDuration = 2.0;
    if (getSilenceDuration != null) {
      try {
        silenceDuration = getSilenceDuration!();
      } catch (e) {
        logger.w("Error obteniendo silenceDuration, usando default: $e");
      }
    }
    
    logger.i("Esperando ${silenceDuration}s de silencio ( audio sigue grabando) ...");
    
    await Future.delayed(Duration(milliseconds: (silenceDuration * 1000).round()));
    
    if (_isFullyDisconnected) return;

    // Cambiar estado a procesando
    _currentState = ConversationState.processing;
    onStateChanged?.call();
    
    logger.i("Fin del período de silencio, obteniendo audio completo y enviando al backend...");
    
    // Detener grabación y obtener audio completo (solo si estamos grabando)
    if (_isRecording) {
      _isRecording = false;
      await _audioService.stopRecording();
      
      // Obtener todo el audio acumulado
      final completeAudio = _audioService.getAccumulatedAudio();
      
      if (completeAudio.isNotEmpty) {
        // Enviar audio completo al backend
        _webSocketService.sendAudioData(completeAudio);
      } else {
        logger.w("Audio acumulado está vacío");
      }
    } else {
      logger.w("No había grabación activa - enviando señal sin audio");
    }
    
    // Enviar señal de fin de habla
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
          logger.i("Traducción: '$originalText' -> '$translatedText'");
          logger.i("CurrentSpeaker antes de TTS: $_currentSpeaker");
          onMessageUpdated?.call(
            originalText: originalText,
            translatedText: translatedText
          );
          _speakTextAndProceed(translatedText);
        } else {
          logger.w(" Traducción vacía");
          onMessageRemoved?.call();
          _startListeningCycle();
        }
        break;
      
      case 'no_speech_detected':
        logger.w("No se detectó habla válida");
        onMessageRemoved?.call();
        _startListeningCycle();
        break;
        
      default:
        logger.w(" Mensaje desconocido: ${data['type']}");
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

    // Determinar idioma de destino
    // El texto ya está traducido, así que necesitamos el idioma de destino correspondiente
    String languageCode = 'es';
    if (getTargetLanguageCode != null) {
      try {
        languageCode = getTargetLanguageCode!();
        logger.i("TTS usando idioma obtenido del provider: $languageCode");
      } catch (e) {
        logger.w("Error obteniendo languageCode, usando default: $e");
      }
    } else {
      logger.w("getTargetLanguageCode es null, usando idioma por defecto: $languageCode");
    }

    await _ttsService.speak(textToSpeak, languageCode);
    
    if (!_isFullyDisconnected) {
      _nextTurn();
    }
  }

  /// Cambia al siguiente turno
  Future<void> _nextTurn() async {
    if (_isFullyDisconnected) return;
    
    logger.i("CAMBIANDO TURNO ...");
    
    // Reproducir sonido de cambio de turno
    await _soundService.playTurnChangeBeep();
    
    final delay = _ttsService.isProcessing ? 1000 : 500;
    await Future.delayed(Duration(milliseconds: delay));
    
    if (_isFullyDisconnected) return;
    
    // Cambiar el hablante actual
    _currentSpeaker = (_currentSpeaker == 'source') ? 'target' : 'source';
    onTurnChanged?.call();
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Iniciar nuevo ciclo
    if (!_isFullyDisconnected) {
      await _startListeningCycle();
    }
  }

  /// Limpia completamente todos los recursos con paralelizado para mejor rendimiento
  Future<void> _forceCleanupAll() async {
    logger.i("LIMPIEZA COMPLETA FORZADA...");
    
    _isRecording = false;
    
    // paralelizamos operaciones de limpieza que no dependen entre sí
    await Future.wait([
      _ttsService.stop(),
      _audioService.stopRecording(),
      _vadService.cleanup(),
      _webSocketService.disconnect(),
    ], eagerError: false);
    
    // Solo un delay corto al final
    await Future.delayed(const Duration(milliseconds: 200));
    
    logger.i(" Limpieza completa terminada");
  }

  Future<void> dispose() async {

    await stopConversation();
    await _audioService.dispose();
    await _vadService.dispose();
    await _ttsService.dispose();
    await _webSocketService.dispose();
    await _soundService.dispose();
  }
}
