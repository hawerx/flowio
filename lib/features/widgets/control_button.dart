import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/providers/conversation_provider.dart';

class ControlButton extends StatelessWidget {
  const ControlButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();

    IconData iconData = LucideIcons.play;
    String text = "Iniciar Conversación";
    Color bgColor = Colors.green;
    onPressed() => provider.toggleConversation();

    if (provider.isConversing) {
      text = "Detener Conversación";
      bgColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(iconData),
        label: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
      ),
    );
  }
}
