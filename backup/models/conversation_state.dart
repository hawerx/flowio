// ESTADDO ACTUAL DE LA CONVERSACIÓN
enum ConversationPhase {
  idle,
  connecting,
  listening,
  processing,
  speaking,
  switching,
  disconnecting,
}

class ConversationState {

  final ConversationPhase phase;
  final bool              isActive;
  final String?           currentSpeaker;
  final String?           error;
  
  const ConversationState({
    required this.phase,
    required this.isActive,
    this.currentSpeaker,
    this.error,
  });
  
  // Method for editing the state
  ConversationState copyWith({
    ConversationPhase? phase,
    bool? isActive,
    String? currentSpeaker,
    String? error,
  }) {
    return ConversationState(
      phase: phase ?? this.phase,
      isActive: isActive ?? this.isActive,
      currentSpeaker: currentSpeaker ?? this.currentSpeaker,
      error: error ?? this.error,
    );
  }
  
  bool get isListening  => phase == ConversationPhase.listening;
  bool get isProcessing => phase == ConversationPhase.processing;
  bool get isSpeaking   => phase == ConversationPhase.speaking;
  bool get isIdle       => phase == ConversationPhase.idle;
}