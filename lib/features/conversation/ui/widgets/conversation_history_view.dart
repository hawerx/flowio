import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import 'message_bubble.dart';

class ConversationHistoryView extends StatefulWidget {
  const ConversationHistoryView({super.key});

  @override
  State<ConversationHistoryView> createState() => _ConversationHistoryViewState();
}

class _ConversationHistoryViewState extends State<ConversationHistoryView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<ConversationProvider>();
    if (provider.history.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: provider.history.length,
      itemBuilder: (context, index) {
        return MessageBubble(message: provider.history[index]);
      },
    );
  }
}
