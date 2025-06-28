import 'package:flutter/material.dart';
import '../../../../core/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isFromSource = message.isFromSource;
    final alignment = isFromSource ? Alignment.centerLeft : Alignment.centerRight;
    final color = isFromSource ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: color.withAlpha((255 * 0.15).round()),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.originalText,
              style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            if (message.translatedText.isNotEmpty && message.translatedText != "...") ...[
              const Divider(height: 12),
              Text(
                message.translatedText,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ] else if (message.translatedText == "...")
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: SizedBox(height: 10, width: 60, child: LinearProgressIndicator()),
              )
          ],
        ),
      ),
    );
  }
}