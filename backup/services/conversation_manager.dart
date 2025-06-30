// import 'dart:async';
// import 'dart:convert';
// import '../../../core/utils/logger.dart';
// import '../../../core/constants/constants.dart';
// import '../../../core/models/message.dart';
// import '../models/conversation_state.dart';
// import '../providers/conversation_provider.dart';
// import 'audio_manager.dart';
// import 'websocket_manager.dart';
// import 'tts_manager.dart';

// class ConversationCoordinator {

//   final AudioManager          _audioManager;
//   final WebSocketManager      _webSocketManager;
//   final TtsManager            _ttsManager;
//   final ConversationProvider  _provider;

//   ConversationState _state = const ConversationState(
//     phase: ConversationPhase.idle,
//     isActive: false,
//   );

//   ConversationCoordinator({
//     required AudioManager audioManager,
//     required WebSocketManager webSocketManager,
//     required TtsManager ttsManager,
//     required ConversationProvider provider,
//   }) : _audioManager = audioManager,
//        _webSocketManager = webSocketManager,
//        _ttsManager = ttsManager,
//        _provider = provider;

//   ConversationState get state => _state;

//   Future<void> initialize() async {
//     logger.i("🚀 Inicializando ConversationCoordinator...");
    
//     await _audioManager.initialize();
//     await _ttsManager.initialize();
    
//     logger.i("✅ ConversationCoordinator inicializado");
//   }

//   Future<void> startConversation() async {
//     if (_state.isActive) {
//       logger.w("⚠️ Conversación ya activa");
//       return;
//     }

//     try {
//       _updateState(ConversationPhase.connecting);
      
//       // Conectar WebSocket
//       await _webSocketManager.connect(
//         url: Constants.wsUrl,
//         config: {
//           "event": Constants.wsStartEvent,
//           "source_lang": _provider.sourceLang.code,
//           "target_lang": _provider.targetLang.code,
//         },
//         onMessage: _handleWebSocketMessage,
//         onError: () => stopConversation(),
//       );

//       // Esperar un momento para que la configuración se procese
//       await Future.delayed(const Duration(milliseconds: 500));

//       _updateState(ConversationPhase.listening, currentSpeaker: 'source');
//       await _startListeningCycle();
      
//     } catch (e, stackTrace) {
//       logger.e("❌ Error iniciando conversación", error: e, stackTrace: stackTrace);
//       _updateState(ConversationPhase.idle, error: e.toString());
//       rethrow;
//     }
//   }

//   Future<void> stopConversation() async {
//     if (!_state.isActive) return;

//     logger.i("🛑 Deteniendo conversación...");
//     _updateState(ConversationPhase.disconnecting);

//     // Detener todos los servicios en orden
//     await _ttsManager.stop();
//     await _audioManager.dispose();
//     await _webSocketManager.dispose();

//     // Esperar un momento para asegurar limpieza completa
//     await Future.delayed(const Duration(milliseconds: 300));

//     _updateState(ConversationPhase.idle);
//     logger.i("✅ Conversación detenida");
//   }

//   Future<void> _startListeningCycle() async {
//     if (!_state.isActive) return;

//     logger.i("🎯 Iniciando ciclo de escucha para: ${_state.currentSpeaker}");

//     // Añadir mensaje temporal
//     _provider.addMessage(Message(
//       id: DateTime.now().toIso8601String(),
//       isFromSource: _state.currentSpeaker == 'source',
//       originalText: "Escuchando...",
//       translatedText: "...",
//     ));

//     // Iniciar escucha con callback mejorado
//     await _audioManager.startListening(
//       onAudioData: _handleAudioData,
//       onSpeechEnd: _handleSpeechEnd,
//     );
//   }

//   void _handleAudioData(List<int> data) {
//     // Solo enviar datos si el WebSocket está conectado y la conversación está activa
//     if (_state.isActive && 
//         _state.phase == ConversationPhase.listening && 
//         _webSocketManager.isConnected) {
//       _webSocketManager.send(data);
//     }
//   }

//   Future<void> _handleSpeechEnd() async {
//     if (!_state.isActive || _state.phase != ConversationPhase.listening) {
//       return;
//     }

//     logger.i("⏹️ Fin de habla detectado");
//     _updateState(ConversationPhase.processing);

//     // Detener VAD inmediatamente
//     await _audioManager.stopVad();

//     // Esperar tiempo de silencio
//     await Future.delayed(
//       Duration(milliseconds: (_provider.silenceDuration * 1000).round())
//     );

//     if (!_state.isActive) return;

//     // Enviar señal de fin de habla
//     await _webSocketManager.send({"event": Constants.wsEndOfSpeechEvent});
//   }

//   void _handleWebSocketMessage(dynamic message) {
//     try {
//       final data = jsonDecode(message);
//       logger.i("📨 Mensaje WebSocket: ${data['type']}");

//       switch (data['type']) {
//         case 'final_translation':
//           _handleTranslation(data);
//           break;
//         case 'no_speech_detected':
//           logger.w("❌ No se detectó habla válida");
//           _provider.removeLastMessage();
//           _startListeningCycle();
//           break;
//         default:
//           logger.w("❓ Mensaje desconocido: ${data['type']}");
//           _provider.removeLastMessage();
//           _startListeningCycle();
//       }
//     } catch (e, stackTrace) {
//       logger.e("❌ Error procesando mensaje WebSocket", error: e, stackTrace: stackTrace);
//       _provider.removeLastMessage();
//       _startListeningCycle();
//     }
//   }

//   void _handleTranslation(Map<String, dynamic> data) {
//     final originalText = data['original_text'] ?? '';
//     final translatedText = data['translated_text'] ?? '';

//     if (originalText.isNotEmpty && translatedText.isNotEmpty) {
//       logger.i("✅ Traducción: '$originalText' -> '$translatedText'");
      
//       _provider.updateLastMessage(
//         originalText: originalText,
//         translatedText: translatedText,
//       );

//       _speakAndProceed(translatedText);
//     } else {
//       logger.w("❌ Traducción vacía");
//       _provider.removeLastMessage();
//       _startListeningCycle();
//     }
//   }

//   Future<void> _speakAndProceed(String text) async {
//     if (!_state.isActive || text.trim().isEmpty) {
//       _nextTurn();
//       return;
//     }

//     _updateState(ConversationPhase.speaking);

//     final targetLang = _state.currentSpeaker == 'source'
//         ? _provider.targetLang.code
//         : _provider.sourceLang.code;

//     await _ttsManager.speak(text, targetLang);

//     if (_state.isActive) {
//       _nextTurn();
//     }
//   }

//   Future<void> _nextTurn() async {
//     if (!_state.isActive) return;

//     logger.i("🔄 Cambiando turno");
//     _updateState(ConversationPhase.switching);

//     // Reproducir beep
//     await _ttsManager.playBeep();

//     // Esperar
//     await Future.delayed(const Duration(milliseconds: 500));

//     if (!_state.isActive) return;

//     // Cambiar turno
//     final newSpeaker = _state.currentSpeaker == 'source' ? 'target' : 'source';
//     _provider.switchTurn();

//     // Esperar un poco más
//     await Future.delayed(const Duration(milliseconds: 500));

//     if (_state.isActive) {
//       _updateState(ConversationPhase.listening, currentSpeaker: newSpeaker);
//       _startListeningCycle();
//     }
//   }

//   void _updateState(ConversationPhase phase, {String? currentSpeaker, String? error}) {
//     _state = _state.copyWith(
//       phase: phase,
//       isActive: phase != ConversationPhase.idle,
//       currentSpeaker: currentSpeaker,
//       error: error,
//     );
//   }

//   Future<void> dispose() async {
//     await stopConversation();
//     await _audioManager.dispose();
//     await _ttsManager.dispose();
//     await _webSocketManager.dispose();
//   }
// }