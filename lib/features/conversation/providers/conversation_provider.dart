import 'package:flutter/material.dart';
import '../../../core/models/language.dart';
import '../../../core/models/message.dart';

class ConversationProvider extends ChangeNotifier {
  bool isConversing = false;
  bool isListening = false;
  bool isProcessing = false;
  String? currentSpeaker;

  double silenceDuration = 2.0;
  Language sourceLang = availableLanguages[1]; // Español
  Language targetLang = availableLanguages[0]; // Inglés

  List<Message> history = [];
  String partialTranscription = "";

  static const List<Language> availableLanguages = [
    Language('en', 'Inglés'), Language('es', 'Español'), Language('fr', 'Francés'),
    Language('de', 'Alemán'), Language('it', 'Italiano'), Language('pt', 'Portugués'),
  ];
  
  void startConversation() {
    isConversing = true;
    isListening = true;
    currentSpeaker = 'source';
    history.clear();
    partialTranscription = "";
    notifyListeners();
  }

  void stopConversation() {
    isConversing = false;
    isListening = false;
    isProcessing = false;
    currentSpeaker = null;
    partialTranscription = "";
    notifyListeners();
  }

  void updatePartialTranscription(String text) {
    partialTranscription = text;
    notifyListeners();
  }

  void commitPartialTranscription() {
    if (partialTranscription.isNotEmpty) {
      addMessage(Message(
        id: DateTime.now().toIso8601String(),
        isFromSource: currentSpeaker == 'source',
        originalText: partialTranscription,
        translatedText: "..." // Indicador de traducción
      ));
    }
    partialTranscription = "";
    notifyListeners();
  }

  void setSilenceDuration(double value) { silenceDuration = value; notifyListeners(); }
  void setSourceLang(Language lang) { sourceLang = lang; notifyListeners(); }
  void setTargetLang(Language lang) { targetLang = lang; notifyListeners(); }
  void addMessage(Message message) { history.add(message); notifyListeners(); }
  void updateLastMessage({String? translatedText}) {
    if (history.isNotEmpty) {
      if(translatedText != null) history.last.translatedText = translatedText;
      notifyListeners();
    }
  }
  void switchTurn() { currentSpeaker = (currentSpeaker == 'source') ? 'target' : 'source'; isListening = true; isProcessing = false; notifyListeners(); }
  void setProcessing() { isListening = false; isProcessing = true; notifyListeners(); }
}