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

  static const List<Language> availableLanguages = [
    Language('en', 'Inglés'), Language('es', 'Español'), Language('fr', 'Francés'),
    Language('de', 'Alemán'), Language('it', 'Italiano'), Language('pt', 'Portugués'),
    Language('ru', 'Ruso'), Language('ja', 'Japonés'), Language('ko', 'Coreano'),
    Language('zh', 'Chino (Mandarín)'), Language('ar', 'Árabe'), Language('hi', 'Hindi'),
  ];
  
  void startConversation() {
    isConversing = true;
    isListening = true;
    currentSpeaker = 'source';
    history.clear();
    notifyListeners();
  }

  void stopConversation() {
    isConversing = false;
    isListening = false;
    isProcessing = false;
    currentSpeaker = null;
    notifyListeners();
  }

  void setSilenceDuration(double value) {
    silenceDuration = value;
    notifyListeners();
  }

  void setSourceLang(Language lang) {
    sourceLang = lang;
    notifyListeners();
  }

  void setTargetLang(Language lang) {
    targetLang = lang;
    notifyListeners();
  }

  void addMessage(Message message) {
    history.add(message);
    notifyListeners();
  }
  
  void updateLastMessage({String? originalText, String? translatedText}) {
    if (history.isNotEmpty) {
      if(originalText != null) history.last.originalText = originalText;
      if(translatedText != null) history.last.translatedText = translatedText;
      notifyListeners();
    }
  }

  void removeLastMessageIfEmpty() {
    if (history.isNotEmpty && history.last.originalText.isEmpty) {
      history.removeLast();
      notifyListeners();
    }
  }
  
  void switchTurn() {
    currentSpeaker = (currentSpeaker == 'source') ? 'target' : 'source';
    isListening = true;
    isProcessing = false;
    notifyListeners();
  }

  void revertToListening() {
    isListening = true;
    isProcessing = false;
    notifyListeners();
  }

  void setProcessing() {
    isListening = false;
    isProcessing = true;
    notifyListeners();
  }
}