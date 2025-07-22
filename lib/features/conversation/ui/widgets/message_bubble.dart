import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/message.dart';
import '../../providers/conversation_provider.dart';
import '../../../../core/services/conversation_manager.dart';

class MessageBubble extends StatefulWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with TickerProviderStateMixin {
  late AnimationController _pulseAnimationController;
  late AnimationController _spinAnimationController;

  @override
  void initState() {
    super.initState();
    
    // Controlador para la animación de pulso del micrófono verde (escuchando)
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // Controlador para la animación de rotación del indicador de carga (procesando)
    _spinAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _spinAnimationController.dispose();
    super.dispose();
  }

  bool _isActiveMessage(ConversationProvider provider) {
    return provider.isConversing && 
           provider.history.isNotEmpty && 
           provider.history.first == widget.message &&
           ((provider.currentSpeaker == 'source' && widget.message.isFromSource) ||
            (provider.currentSpeaker == 'target' && !widget.message.isFromSource));
  }

  Widget _buildMicrophoneWidget(ConversationProvider provider) {
    final isFromSource = widget.message.isFromSource;
    final colorScheme = Theme.of(context).colorScheme;
    
    bool isActiveMessage = _isActiveMessage(provider);
    
    if (!isActiveMessage) {
      _pulseAnimationController.stop();
      _spinAnimationController.stop();
      return const SizedBox.shrink();
    }
    
    String displayText = "";
    Widget microphoneWidget;
    
    if (provider.conversationState == ConversationState.listening) 
    {
      displayText = "Escuchando...";
      _spinAnimationController.stop();
      if (!_pulseAnimationController.isAnimating) {
        _pulseAnimationController.repeat(reverse: true);
      }
      
      microphoneWidget = AnimatedBuilder(
        animation: _pulseAnimationController,
        builder: (context, child) {
          return Container(
            width: 24, 
            height: 24,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha:0.1 + 0.1 * _pulseAnimationController.value),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic, 
              color: Colors.green, 
              size: 16
            ),
          );
        },
      );
    } else if (provider.conversationState == ConversationState.processing) {

      displayText = "Traduciendo...";
      _pulseAnimationController.stop();
      if (!_spinAnimationController.isAnimating) {
        _spinAnimationController.repeat();
      }
      
      microphoneWidget = AnimatedBuilder(
        animation: _spinAnimationController,
        builder: (context, child) {
          return SizedBox(
            width: 24, 
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _spinAnimationController.value * 2 * 3.14159,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha:0.3),
                        width: 1.5,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _LoadingPainter(
                        color: Colors.red,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha:0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.red,
                    size: 12,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // No hay estado activo
      _pulseAnimationController.stop();
      _spinAnimationController.stop();
      return const SizedBox.shrink();
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        microphoneWidget,
        const SizedBox(width: 8),
        Text(
          displayText,
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: isFromSource 
              ? colorScheme.onSurfaceVariant.withValues(alpha:0.7)
              : colorScheme.onPrimary.withValues(alpha:0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    final isFromSource = widget.message.isFromSource;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Selector<ConversationProvider, ({
      bool isConversing,
      ConversationState state,
      String? currentSpeaker,
      bool hasActiveMessage
    })>(
      selector: (context, provider) => (
        isConversing: provider.isConversing,
        state: provider.conversationState,
        currentSpeaker: provider.currentSpeaker,
        hasActiveMessage: _isActiveMessage(provider)
      ),
      builder: (context, data, child) {
        bool shouldShowAnimation = data.hasActiveMessage && 
            (data.state == ConversationState.listening || 
             data.state == ConversationState.processing);
        bool hasRealContent = widget.message.originalText.isNotEmpty && 
                             widget.message.originalText != "Escuchando...";
        bool hasTranslation = widget.message.translatedText.isNotEmpty && 
                             widget.message.translatedText != "...";
        
        return Row(
          mainAxisAlignment: isFromSource ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isFromSource) const Spacer(),
            if (isFromSource) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primary,
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              flex: 3,
              child: Column(
                crossAxisAlignment: isFromSource ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  // Burbuja del mensaje
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isFromSource 
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isFromSource ? 4 : 20),
                        bottomRight: Radius.circular(isFromSource ? 20 : 4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (shouldShowAnimation)
                          Consumer<ConversationProvider>(
                            builder: (context, provider, child) => _buildMicrophoneWidget(provider),
                          )
                        else if (hasRealContent)
                          Text(
                            widget.message.originalText,
                            style: TextStyle(
                              fontSize: 16,
                              color: isFromSource 
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        
                        if (hasTranslation && !shouldShowAnimation) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isFromSource 
                                ? colorScheme.surface
                                : colorScheme.onPrimary.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.message.translatedText,
                              style: TextStyle(
                                fontSize: 15,
                                color: isFromSource 
                                  ? colorScheme.onSurface
                                  : colorScheme.onPrimary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isFromSource) const Spacer(),
            if (!isFromSource) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.secondary,
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: colorScheme.onSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
class _LoadingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _LoadingPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Comenzar desde la parte superior
      3.14159 * 1.5, // 3/4 del círculo
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
