class Message {
  final String  id;
  final bool    isFromSource;
  String        originalText;
  String        translatedText;
  
  Message({required this.id, required this.isFromSource, this.originalText = "", this.translatedText = ""});
}

