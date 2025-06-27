import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/language.dart';
import '../../core/providers/conversation_provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();
    final bool isEnabled = !provider.isConversing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Traducir a: ",
            style: TextStyle(
              fontSize: 16,
              color: isEnabled ? null : Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<Language>(
            value: provider.targetLanguage,
            onChanged: isEnabled
                ? (Language? newValue) {
                    if (newValue != null) {
                      provider.setTargetLanguage(newValue);
                    }
                  }
                : null,
            items: ConversationProvider.availableLanguages
                .map<DropdownMenuItem<Language>>((Language lang) {
                  return DropdownMenuItem<Language>(
                    value: lang,
                    child: Text(
                      lang.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }
}
