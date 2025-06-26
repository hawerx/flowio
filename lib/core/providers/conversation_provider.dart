import 'package:flutter/material.dart';
import '../models/language.dart';
import '../models/conversation_message.dart';

class ConversationProvider extends ChangeNotifier {
  // ... (variables de estado _history, _speakerMap, etc. sin cambios) ...
  List<ConversationMessage> _history = [];
  Map<String, Color> _speakerMap = {};
  final List<Color> _speakerColors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.pink,
  ];

  bool _isConversing = false;
  bool _isListening = false;
  bool _isTranslating = false;
  String _turnIndicator = 'none';

  List<ConversationMessage> get history => _history;
  Map<String, Color> get speakerMap => _speakerMap;
  bool get isConversing => _isConversing;
  bool get isListening => _isListening;
  bool get isTranslating => _isTranslating;
  String get turnIndicator => _turnIndicator;

  // --- CAMBIO PRINCIPAL: Lista de idiomas expandida ---
  static const List<Language> availableLanguages = [
    Language('en', 'Inglés'),
    Language('es', 'Español'),
    Language('fr', 'Francés'),
    Language('de', 'Alemán'),
    Language('it', 'Italiano'),
    Language('pt', 'Portugués'),
    Language('ru', 'Ruso'),
    Language('ja', 'Japonés'),
    Language('ko', 'Coreano'),
    Language('zh', 'Chino (Mandarín)'),
    Language('ar', 'Árabe'),
    Language('hi', 'Hindi'),
    Language('nl', 'Holandés'),
    Language('sv', 'Sueco'),
    Language('pl', 'Polaco'),
    Language('tr', 'Turco'),
    Language('el', 'Griego'),
    Language('he', 'Hebreo'),
    // Añadir más idiomas según sea necesario
  ];

  Language _targetLanguage = availableLanguages[0];
  Language get targetLanguage => _targetLanguage;

  void setTargetLanguage(Language language) {
    _targetLanguage = language;
    notifyListeners();
  }

  // El resto de los métodos del Provider no cambian
  // ...
  void addMessage(ConversationMessage message) {
    _history.add(message);
    if (!_speakerMap.containsKey(message.speakerId)) {
      _speakerMap[message.speakerId] =
          _speakerColors[_speakerMap.length % _speakerColors.length];
    }
    notifyListeners();
  }

  void updateLastMessage({
    String? originalText,
    String? translatedText,
    bool? isTranslating,
  }) {
    if (_history.isNotEmpty) {
      final last = _history.last;
      if (originalText != null) last.originalText = originalText;
      if (translatedText != null) last.translatedText = translatedText;
      if (isTranslating != null) last.isTranslating = isTranslating;
      notifyListeners();
    }
  }

  void toggleConversation() {
    _isConversing = !_isConversing;
    if (!_isConversing) {
      _isListening = false;
      _isTranslating = false;
      _turnIndicator = 'none';
      _history = [];
      _speakerMap = {};
    }
    notifyListeners();
  }

  void setStatus({required bool listening, required bool translating}) {
    _isListening = listening;
    _isTranslating = translating;
    notifyListeners();
  }

  void setTurnIndicator(String indicator) {
    _turnIndicator = indicator;
    notifyListeners();
  }
}
