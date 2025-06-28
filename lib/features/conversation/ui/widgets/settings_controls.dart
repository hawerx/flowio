import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../../../../core/models/language.dart';

class SettingsControls extends StatelessWidget {
  const SettingsControls({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();
    final bool isEnabled = !provider.isConversing;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildLanguageSelectors(context, provider, isEnabled),
          const SizedBox(height: 16),
          _buildSilenceSlider(context, provider, isEnabled),
          const SizedBox(height: 24),
          _buildControlButton(context, provider),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectors(BuildContext context, ConversationProvider provider, bool isEnabled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLanguageDropdown("Hablar en:", provider.sourceLang, provider.setSourceLang, isEnabled),
        const Icon(Icons.swap_horiz, size: 24),
        _buildLanguageDropdown("Traducir a:", provider.targetLang, provider.setTargetLang, isEnabled),
      ],
    );
  }

  Widget _buildLanguageDropdown(String label, Language value, void Function(Language) onChanged, bool isEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        DropdownButton<Language>(
          value: value,
          onChanged: isEnabled ? (Language? newValue) => onChanged(newValue!) : null,
          items: ConversationProvider.availableLanguages.map<DropdownMenuItem<Language>>((Language lang) {
            return DropdownMenuItem<Language>(
              value: lang,
              child: Text(lang.name),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSilenceSlider(BuildContext context, ConversationProvider provider, bool isEnabled) {
    return Column(
      children: [
        Text("Pausa para traducir: ${provider.silenceDuration.toStringAsFixed(1)} segundos"),
        Slider(
          value: provider.silenceDuration,
          min: 1.0,
          max: 5.0,
          divisions: 8,
          label: provider.silenceDuration.toStringAsFixed(1),
          onChanged: isEnabled ? (double value) => provider.setSilenceDuration(value) : null,
        ),
      ],
    );
  }

  Widget _buildControlButton(BuildContext context, ConversationProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(provider.isConversing ? Icons.stop : Icons.play_arrow),
        label: Text(provider.isConversing ? "Detener Conversación" : "Iniciar Conversación"),
        onPressed: () => provider.isConversing ? provider.stopConversation() : provider.startConversation(),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: provider.isConversing ? Colors.red.shade700 : Colors.green.shade700,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}