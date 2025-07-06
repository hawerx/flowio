import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../../../../core/models/language.dart';
import '../../../../core/constants/language_constants.dart';
import 'language_selection_popup.dart';

class SettingsControls extends StatelessWidget {
  const SettingsControls({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();
    final bool isEnabled = !provider.isConversing;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selectores de idioma
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha:0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Configuración de idiomas",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLanguageSelectors(context, provider, isEnabled),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Control de silencio
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha:0.2),
              ),
            ),
            child: _buildSilenceSlider(context, provider, isEnabled),
          ),
          
          const SizedBox(height: 24),
          
          // Botón principal
          _buildControlButton(context, provider),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectors(BuildContext context, ConversationProvider provider, bool isEnabled) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildLanguageDropdown(
            context,
            "Hablar en:",
            provider.sourceLang,
            provider.setSourceLang,
            isEnabled,
            Icons.mic,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.only(top: 20), // Alineación vertical con los dropdowns
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isEnabled ? () => provider.swapLanguages() : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEnabled 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    color: isEnabled 
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildLanguageDropdown(
            context,
            "Traducir a:",
            provider.targetLang,
            provider.setTargetLang,
            isEnabled,
            Icons.translate,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown(
    BuildContext context,
    String label,
    Language value,
    void Function(Language) onChanged,
    bool isEnabled,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? () => _showLanguageSelection(
              context, 
              label, 
              value, 
              onChanged, 
              icon
            ) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isEnabled 
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bandera del idioma (sin fondo)
                  Text(
                    LanguageConstants.getLanguageFlag(value.code),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  // Nombre del idioma (sin mostrar código)
                  Flexible(
                    child: Text(
                      value.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isEnabled 
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showLanguageSelection(
    BuildContext context,
    String label,
    Language currentLanguage,
    void Function(Language) onChanged,
    IconData icon,
  ) async {
    await showLanguageSelectionPopup(
      context: context,
      currentLanguage: currentLanguage,
      onLanguageSelected: onChanged,
      title: label,
      titleIcon: icon,
    );
  }

  Widget _buildSilenceSlider(BuildContext context, ConversationProvider provider, bool isEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.timer,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              "Pausa para traducir",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${provider.silenceDuration.toStringAsFixed(1)}s",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: provider.silenceDuration,
            min: 0.5,
            max: 3.0,
            divisions: 10,
            onChanged: isEnabled ? (double value) => provider.setSilenceDuration(value) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(BuildContext context, ConversationProvider provider) {
    final isConversing = provider.isConversing;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isConversing
            ? Colors.red.shade600
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isConversing 
                ? Colors.red.withValues(alpha: 0.3)
                : colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => isConversing 
              ? provider.stopConversation() 
              : provider.startConversation(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConversing ? Icons.stop_circle : Icons.play_circle,
                  color: isConversing 
                      ? Colors.white 
                      : colorScheme.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isConversing ? "Detener Conversación" : "Iniciar Conversación",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isConversing 
                        ? Colors.white 
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
