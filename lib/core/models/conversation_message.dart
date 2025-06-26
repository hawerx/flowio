class ConversationMessage {
  final String id;
  final String speakerId;
  String originalText;
  String translatedText;
  bool isTranslating;

  ConversationMessage({
    required this.id,
    required this.speakerId,
    this.originalText = '',
    this.translatedText = '',
    this.isTranslating = false,
  });

  @override
  String toString() {
    return 'ConversationMessage(id: $id, speakerId: $speakerId, originalText: $originalText, translatedText: $translatedText, isTranslating: $isTranslating)';
  }
}
