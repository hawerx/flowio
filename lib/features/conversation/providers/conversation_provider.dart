import 'package:flutter/material.dart';
import '../../../core/models/language.dart';
import '../../../core/models/message.dart';
import '../../../core/utils/logger.dart';

class ConversationProvider extends ChangeNotifier {
  bool isConversing = false;
  bool isListening = false;
  bool isProcessing = false;
  String? currentSpeaker;

  double silenceDuration = 2.0;
  Language sourceLang = availableLanguages[1]; // Español
  Language targetLang = availableLanguages[0]; // Inglés

  List<Message> history = [];
  // Se elimina partialTranscription

  static const List<Language> availableLanguages = [
    Language('en', 'Inglés'), Language('es', 'Español'), Language('fr', 'Francés'),
    Language('de', 'Alemán'), Language('it', 'Italiano'), Language('pt', 'Portugués'),
  ];
  
  void startConversation() {
    logger.i("---> LLamada a funcion startConversation[ConversationProvider]: Iniciando conversación. | isConversing: $isConversing | isListening: $isListening");
    isConversing = true;
    isListening = true;
    currentSpeaker = 'source';
    history.clear();
    notifyListeners();
  }

  void stopConversation() {
    logger.i("---> LLamada a funcion stopConversacion[ConversationProvider]: Deteniendo conversacion. | isConversing: $isConversing | isListening: $isListening | isProcessing: $isProcessing | currentSpeaker: $currentSpeaker");
    isConversing = false;
    isListening = false;
    isProcessing = false;
    currentSpeaker = null;

    // Limpiar solo mensajes temporales que no tienen contenido real
    _cleanupTemporaryMessages();
    
    notifyListeners();
  }

  // Función mejorada para limpiar solo mensajes temporales sin contenido real
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

  void setSilenceDuration(double value) { 
    logger.d("---> setSilenceDuration: $value");
    silenceDuration = value; 
    notifyListeners(); 
  }

  void setSourceLang(Language lang) { 
    logger.d("---> setSourceLang: ${lang.name}");
    sourceLang = lang; 
    notifyListeners(); 
  }

  void setTargetLang(Language lang) { 
    logger.d("---> setTargetLang: ${lang.name}");
    targetLang = lang; 
    notifyListeners(); 
  }

  void addMessage(Message message) { 
    logger.d("---> addMessage: Añadiendo mensaje al historial: '${message.originalText}'");
    // Usamos insert en lugar de add para que el nuevo mensaje aparezca arriba
    history.insert(0, message); 
    notifyListeners(); 
  }

  void updateLastMessage({String? originalText, String? translatedText}) {
    logger.i("---> updateLastMessage: Actualizando último mensaje con original: '$originalText' y traducción: '$translatedText'");
    if (history.isNotEmpty) {
      if(originalText != null) history.first.originalText = originalText;
      if(translatedText != null) history.first.translatedText = translatedText;
      notifyListeners();
    }
  }

  // Se añade esta función para eliminar el último mensaje si no se detectó habla
  void removeLastMessage() {
    if (history.isNotEmpty) {
      history.removeAt(0);
      notifyListeners();
    }
  }

  void switchTurn() { 
    logger.i("---> switchTurn: Cambiando turno. Nuevo hablante: ${(currentSpeaker == 'source') ? 'target' : 'source'}");
    currentSpeaker = (currentSpeaker == 'source') ? 'target' : 'source'; 
    isListening = true; 
    isProcessing = false; 
    notifyListeners(); 
  }

  void setProcessing() { 
    logger.i("---> setProcessing: Cambiando a estado 'Procesando'.");
    isListening = false; 
    isProcessing = true; 
    notifyListeners(); 
  }
}