import 'package:flutter/material.dart';
import '../../../core/models/language.dart';
import '../../../core/models/message.dart';
import '../../../core/services/conversation_manager.dart';
import '../../../core/utils/logger.dart';
import '../../../core/constants/constants.dart';
import '../../../core/constants/language_constants.dart';

class ConversationProvider extends ChangeNotifier {
  // Configuración 
  double silenceDuration  = Constants.SLIDER_DEFAULT_VALUE;
  Language sourceLang     = LanguageConstants.DEFAULT_SOURCE_LANGUAGE;
  Language targetLang     = LanguageConstants.DEFAULT_TARGET_LANGUAGE;
  List<Message> history   = [];

  // Manager de conversación
  final ConversationManager _conversationManager = ConversationManager();
  bool _isInitialized = false;

  // Idiomas disponibles
  static List<Language> get availableLanguages => LanguageConstants.ALL_SUPPORTED_LANGUAGES;

  // Getters
  bool get isConversing                   => _conversationManager.isActive;
  bool get isListening                    => _conversationManager.isListening;
  bool get isProcessing                   => _conversationManager.isProcessing;
  bool get isSpeaking                     => _conversationManager.isSpeaking;
  bool get isConnecting                   => _conversationManager.isConnecting;
  bool get hasError                       => _conversationManager.hasError;
  bool get isIdle                         => _conversationManager.isIdle;
  String? get currentSpeaker              => _conversationManager.currentSpeaker;
  ConversationState get conversationState => _conversationManager.currentState;

  /// Inicializa el provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logger.i("Inicializando ConversationProvider...");
      
      final success = await _conversationManager.initialize();
      if (!success) {
        logger.e("Error inicializando ConversationManager");
        return;
      }

      _setupCallbacks();
      _isInitialized = true;
      
      logger.i("ConversationProvide inicializado");
    } catch (e, stackTrace) {
      logger.e("Error inicializando ConversationProvider", error: e, stackTrace: stackTrace);
    }
  }

  /// Setup de callbacks
  void _setupCallbacks() {
    // Verificar qué callbacks realmente existen en ConversationManager
    try {
      _conversationManager.onMessageAdded   = _addMessage;
      _conversationManager.onMessageUpdated = _updateMessage;
      _conversationManager.onMessageRemoved = _removeMessage;
      _conversationManager.onTurnChanged    = _onTurnChanged;
      _conversationManager.onStateChanged   = _onStateChanged;
      
      // Asignar los callbacks de configuración
      _conversationManager.getSilenceDuration = () => silenceDuration;
      _conversationManager.getTargetLanguageCode = _getTargetLanguageCode;
      
      logger.i("Callbacks configurados correctamente");
    } catch (e) {
      logger.e("Error configurando callbacks: $e");
    }
  }

  void _addMessage(Message message) {
    history.insert(0, message);
    notifyListeners();
  }

  void _updateMessage({String? originalText, String? translatedText}) {
    if (history.isEmpty) return;
    
    final message = history.first;
    if (originalText != null) message.originalText = originalText;
    if (translatedText != null) message.translatedText = translatedText;
    notifyListeners();
  }

  void _removeMessage() {
    if (history.isNotEmpty) {
      history.removeAt(0);
      notifyListeners();
    }
  }

  void _onTurnChanged() {
    logger.i("Turno: ${_conversationManager.currentSpeaker}");
    notifyListeners();
  }

  void _onStateChanged() {
    logger.d("Estado: ${_conversationManager.currentState}");
    notifyListeners();
  }

  String _getTargetLanguageCode() {
    
    final targetCode = _conversationManager.currentSpeaker == 'source' 
        ? targetLang.code 
        : sourceLang.code;

    return targetCode;
  }

  /// Inicia la conversación
  Future<void> startConversation() async {
    // Inicializamos solo si es necesario
    if (!_isInitialized) {
      await initialize();
    }
    
    history.clear();
    
    final success = await _conversationManager.startConversation(sourceLang, targetLang);
    if (!success) {
      logger.e("Error iniciando conversación");
    }
  }

  /// Detiene la conversación
  Future<void> stopConversation() async {
    await _conversationManager.stopConversation();
    _cleanupTemporaryMessages();
    notifyListeners();
  }

  /// Limpieza de mensajes temporales 
  void _cleanupTemporaryMessages() {
    history.removeWhere((msg) => 
      msg.originalText == "Escuchando..." && 
      (msg.translatedText == "..." || msg.translatedText.isEmpty));
  }

  /// Seteo de la duracion del silencio con validacion
  void setSilenceDuration(double value) {
    final clampedValue = value.clamp(Constants.SLIDER_MIN_VALUE, Constants.SLIDER_MAX_VALUE);
    if (clampedValue != silenceDuration) {
      silenceDuration = clampedValue;
      notifyListeners();
    }
  }

  void setSourceLang(Language lang) {
    if (lang != sourceLang) {
      sourceLang = lang;
      notifyListeners();
    }
  }

  void setTargetLang(Language lang) {
    if (lang != targetLang) {
      targetLang = lang;
      notifyListeners();
    }
  }

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
