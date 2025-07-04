import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import 'message_bubble.dart';

class ConversationHistoryViewNew extends StatefulWidget {
  const ConversationHistoryViewNew({super.key});

  @override
  State<ConversationHistoryViewNew> createState() => _ConversationHistoryViewNewState();
}

class _ConversationHistoryViewNewState extends State<ConversationHistoryViewNew> {
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
    
    if (provider.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "¡Listo para conversar!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Presiona 'Iniciar Conversación' para comenzar",
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Invertir la lista para mostrar los más nuevos abajo
    final reversedHistory = provider.history.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: reversedHistory.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: MessageBubbleNew(message: reversedHistory[index]),
        );
      },
    );
  }
}
