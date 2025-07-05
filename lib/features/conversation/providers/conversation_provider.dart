import 'package:flutter/material.dart';
import '../../../core/models/language.dart';
import '../../../core/models/message.dart';
import '../../../core/services/conversation_manager.dart';
import '../../../core/utils/logger.dart';

class ConversationProvider extends ChangeNotifier {
  // Configuración
  double silenceDuration = 2.0;
  Language sourceLang = availableLanguages[1]; // Español
  Language targetLang = availableLanguages[0]; // Inglés

  // Estado de conversación
  ConversationState _currentState = ConversationState.idle;
  String? _currentSpeaker;
  List<Message> history = [];

  // Manager de conversación
  final ConversationManager _conversationManager = ConversationManager();
  bool _isInitialized = false;

  // Idiomas disponibles
  static const List<Language> availableLanguages = [
    Language('en', 'Inglés'), 
    Language('es', 'Español'), 
    Language('fr', 'Francés'),
    Language('de', 'Alemán'), 
    Language('it', 'Italiano'), 
    Language('pt', 'Portugués'),
  ];

  // Getters
  bool get isConversing => _currentState != ConversationState.idle;
  bool get isListening => _currentState == ConversationState.listening;
  bool get isProcessing => _currentState == ConversationState.processing;
  String? get currentSpeaker => _currentSpeaker;
  ConversationState get conversationState => _currentState;

  /// Inicializa el provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logger.i("🚀 Inicializando ConversationProvider...");
      
      final success = await _conversationManager.initialize();
      if (!success) {
        logger.e("❌ Error inicializando ConversationManager");
        return;
      }

      _setupManagerCallbacks();
      _isInitialized = true;
      
      logger.i("✅ ConversationProvider inicializado");
    } catch (e, stackTrace) {
      logger.e("Error inicializando ConversationProvider", error: e, stackTrace: stackTrace);
    }
  }

  /// Configura los callbacks del ConversationManager
  void _setupManagerCallbacks() {
    _conversationManager.onMessageAdded = (message) {
      logger.d("---> Añadiendo mensaje al historial: '${message.originalText}'");
      history.insert(0, message);
      notifyListeners();
    };

    _conversationManager.onMessageUpdated = ({String? originalText, String? translatedText}) {
      logger.i("---> Actualizando último mensaje con original: '$originalText' y traducción: '$translatedText'");
      if (history.isNotEmpty) {
        if (originalText != null) history.first.originalText = originalText;
        if (translatedText != null) history.first.translatedText = translatedText;
        notifyListeners();
      }
    };

    _conversationManager.onMessageRemoved = () {
      if (history.isNotEmpty) {
        history.removeAt(0);
        notifyListeners();
      }
    };

    _conversationManager.onTurnChanged = () {
      _currentSpeaker = _conversationManager.currentSpeaker;
      logger.i("---> Turno cambiado. Nuevo hablante: $_currentSpeaker");
      notifyListeners();
    };

    _conversationManager.onStateChanged = () {
      _currentState = _conversationManager.currentState;
      notifyListeners();
    };

    // Callback para obtener la duración de silencio configurada
    _conversationManager.getSilenceDuration = () {
      return silenceDuration;
    };

    // Callback para obtener el código de idioma destino (igual que en código original)
    _conversationManager.getTargetLanguageCode = () {
      return _currentSpeaker == 'source' ? targetLang.code : sourceLang.code;
    };
  }

  /// Inicia la conversación
  Future<void> startConversation() async {
    if (!_isInitialized) {
      await initialize();
    }

    logger.i("---> Llamada a función startConversation[ConversationProvider]: Iniciando conversación.");
    
    _currentSpeaker = 'source';
    history.clear();
    
    final success = await _conversationManager.startConversation(sourceLang, targetLang);
    if (success) {
      _currentState = _conversationManager.currentState;
      notifyListeners();
    } else {
      logger.e("❌ Error iniciando conversación");
    }
  }

  /// Detiene la conversación
  Future<void> stopConversation() async {
    logger.i("---> Llamada a función stopConversation[ConversationProvider]: Deteniendo conversación.");
    
    await _conversationManager.stopConversation();
    
    _currentState = ConversationState.idle;
    _currentSpeaker = null;
    
    // Limpiar solo mensajes temporales que no tienen contenido real
    _cleanupTemporaryMessages();
    
    notifyListeners();
  }

  /// Función mejorada para limpiar solo mensajes temporales sin contenido real
  void _cleanupTemporaryMessages() {
    history.removeWhere((message) {
      // Eliminar si:
      // 1. Solo dice "Escuchando..." y no tiene traducción
      // 2. Está vacío y solo tiene "..." como traducción
      // 3. Solo dice "Escuchando..." y la traducción es "..."
      bool isTemporary = (message.originalText == "Escuchando..." && 
                         (message.translatedText == "..." || message.translatedText.isEmpty)) ||
                        (message.originalText.isEmpty && message.translatedText == "...");
      
      if (isTemporary) {
        logger.d("---> Eliminando mensaje temporal: '${message.originalText}' -> '${message.translatedText}'");
      }
      
      return isTemporary;
    });
  }

  /// Configura la duración del silencio
  void setSilenceDuration(double value) { 
    logger.d("---> setSilenceDuration: $value");
    silenceDuration = value; 
    notifyListeners(); 
  }

  /// Configura el idioma fuente
  void setSourceLang(Language lang) { 
    logger.d("---> setSourceLang: ${lang.name}");
    sourceLang = lang; 
    notifyListeners(); 
  }

  /// Configura el idioma destino
  void setTargetLang(Language lang) { 
    logger.d("---> setTargetLang: ${lang.name}");
    targetLang = lang; 
    notifyListeners(); 
  }

  /// Intercambia los idiomas fuente y destino
  void swapLanguages() {
    logger.d("---> swapLanguages: ${sourceLang.name} <-> ${targetLang.name}");
    final temp = sourceLang;
    sourceLang = targetLang;
    targetLang = temp;
    notifyListeners();
  }

  @override
  void dispose() {
    _conversationManager.dispose();
    super.dispose();
  }
}
