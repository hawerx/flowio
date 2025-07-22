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

    return OrientationBuilder(
      builder: (context, orientation) {
        return Container(
          padding: orientation == Orientation.landscape 
              ? const EdgeInsets.all(12.0) 
              : const EdgeInsets.all(20.0),
          child: orientation == Orientation.landscape
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Selectores de idioma
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _buildLanguageSelectors(context, provider, isEnabled, orientation),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Control de silencio
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha:0.2),
                          ),
                        ),
                        child: _buildSilenceSlider(context, provider, isEnabled, orientation),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Boton principal en landscape tambie
                    _buildStartConversattionButton(context, provider, orientation),
                  ],
                )
              : SingleChildScrollView(
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
                            _buildLanguageSelectors(context, provider, isEnabled, orientation),
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
                        child: _buildSilenceSlider(context, provider, isEnabled, orientation),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Botón principal
                      _buildStartConversattionButton(context, provider, orientation),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildLanguageSelectors(BuildContext context, ConversationProvider provider, bool isEnabled, Orientation orientation) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildLanguageDropdown(
                    context,
                    "Hablar en:",
                    provider.sourceLang,
                    provider.setSourceLang,
                    isEnabled,
                    Icons.mic,
                    orientation,
                  ),
                ),
                SizedBox(width: orientation == Orientation.landscape ? 56 : 72),
                Expanded(
                  child: _buildLanguageDropdown(
                    context,
                    "Traducir a:",
                    provider.targetLang,
                    provider.setTargetLang,
                    isEnabled,
                    Icons.translate,
                    orientation,
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: Column(
                children: [
                  // Espacio más ajustado para centrar mejor
                  SizedBox(
                    height: orientation == Orientation.landscape 
                        ? 32  // Reducido significativamente para landscape
                        : 36  // Reducido para portrait
                  ),
                  // El botón centrado
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isEnabled ? () => provider.swapLanguages() : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.all(orientation == Orientation.landscape ? 6 : 8),
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
                          size: orientation == Orientation.landscape ? 16 : 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageDropdown(
    BuildContext context,
    String label,
    Language value,
    void Function(Language) onChanged,
    bool isEnabled,
    IconData icon,
    Orientation orientation,
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
                fontSize: orientation == Orientation.landscape ? 11 : 12,
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
              height: orientation == Orientation.landscape ? 48 : 56,
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
                    style: TextStyle(fontSize: orientation == Orientation.landscape ? 16 : 20),
                  ),
                  const SizedBox(width: 8),
                  // Nombre del idioma (sin mostrar código)
                  Flexible(
                    child: Text(
                      value.name,
                      style: TextStyle(
                        fontSize: orientation == Orientation.landscape ? 12 : 14,
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

  Widget _buildSilenceSlider(BuildContext context, ConversationProvider provider, bool isEnabled, Orientation orientation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        orientation == Orientation.landscape
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Traducir después de un silencio de:",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${provider.silenceDuration.toStringAsFixed(2)}s",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Traducir después de un silencio de:",
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
                      "${provider.silenceDuration.toStringAsFixed(2)}s",
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
            trackHeight: orientation == Orientation.landscape ? 3 : 4,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: orientation == Orientation.landscape ? 6 : 8,
            ),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: orientation == Orientation.landscape ? 12 : 16,
            ),
          ),
          child: Slider(
            value: provider.silenceDuration,
            min: 0.25,
            max: 2.0,
            divisions: 7,
            onChanged: isEnabled ? (double value) => provider.setSilenceDuration(value) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStartConversattionButton(BuildContext context, ConversationProvider provider, Orientation orientation) {
    final isConversing = provider.isConversing;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: orientation == Orientation.landscape ? 42 : 56,
      decoration: BoxDecoration(
        color: isConversing
            ? Colors.red.shade600
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => isConversing 
              ? provider.stopConversation() 
              : provider.startConversation(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: orientation == Orientation.landscape ? 16 : 24
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConversing ? Icons.stop_circle : Icons.play_circle,
                  color: isConversing 
                      ? Colors.white 
                      : colorScheme.onPrimaryContainer,
                  size: orientation == Orientation.landscape ? 20 : 28,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isConversing ? "Detener" : "Iniciar",
                    style: TextStyle(
                      fontSize: orientation == Orientation.landscape ? 13 : 18,
                      fontWeight: FontWeight.bold,
                      color: isConversing 
                          ? Colors.white 
                          : colorScheme.onPrimaryContainer,
                    ),
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
