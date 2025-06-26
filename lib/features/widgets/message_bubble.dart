import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/models/conversation_message.dart';
import '../../core/providers/conversation_provider.dart';

class MessageBubble extends StatelessWidget {
  final ConversationMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();
    final color = provider.speakerMap[message.speakerId] ?? Colors.grey;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDarkMode ? color.withOpacity(0.15) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                message.speakerId.startsWith('USER')
                    ? LucideIcons.user
                    : LucideIcons.bot,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                message.speakerId,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const Divider(height: 16),
          if (message.originalText.isNotEmpty)
            Text(
              message.originalText,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15),
            ),
          if (message.translatedText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message.translatedText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ],
          if (message.isTranslating && message.translatedText.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(
                backgroundColor: color.withOpacity(0.2),
                color: color,
                minHeight: 4,
              ),
            ),
        ],
      ),
    );
  }
}
