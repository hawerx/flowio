import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/conversation_provider.dart';
import 'message_bubble.dart';

class ConversationHistory extends StatelessWidget {
  const ConversationHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();
    final scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: provider.history.length,
      itemBuilder: (context, index) {
        return MessageBubble(message: provider.history[index]);
      },
    );
  }
}
