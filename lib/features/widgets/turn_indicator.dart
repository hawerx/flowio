import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/conversation_provider.dart';

class TurnIndicator extends StatefulWidget {
  @override
  _TurnIndicatorState createState() => _TurnIndicatorState();
}

class _TurnIndicatorState extends State<TurnIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();
    final showIndicator = provider.turnIndicator != 'none';
    final isUserTurn = provider.turnIndicator == 'user';
    final color = isUserTurn ? Colors.blueAccent : Colors.greenAccent;
    final text = isUserTurn ? "Es tu turno" : "Turno de la IA";

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: showIndicator ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: Stack(
          children: [
            // Borde que pulsa
            FadeTransition(
              opacity: Tween<double>(begin: 0.7, end: 0.2).animate(_controller),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Etiqueta de texto
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
