import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';

class StatusIndicator extends StatefulWidget {
  const StatusIndicator({super.key});

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();

    String statusText = "Detenido";
    Color indicatorColor = Colors.grey;
    Widget statusIcon = const Icon(Icons.mic_off, color: Colors.grey);

    if (provider.isConversing) {
      if (provider.isListening) {
        final lang = provider.currentSpeaker == 'source' ? provider.sourceLang : provider.targetLang;
        statusText = "Escuchando (${lang.name})...";
        indicatorColor = Colors.green;
        statusIcon = FadeTransition(
          opacity: _animationController,
          child: const Icon(Icons.mic, color: Colors.green),
        );
      } else if (provider.isProcessing) {
        statusText = "Procesando...";
        indicatorColor = Colors.orange;
        statusIcon = const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: indicatorColor.withAlpha((255 * 0.1).round()), // CORREGIDO
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          statusIcon,
          const SizedBox(width: 12),
          Text(statusText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
