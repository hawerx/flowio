import 'package:flutter/material.dart';
import '../../../../core/models/language.dart';
import '../../../../core/constants/language_constants.dart';

/// Popup minimalista para selección de idiomas
/// 
/// Este widget muestra una interfaz limpia y minimalista con:
/// - Lista simple en una sola columna de todos los idiomas soportados
/// - Búsqueda en tiempo real
/// - Diseño Material 3 con elementos esenciales únicamente
class LanguageSelectionPopup extends StatefulWidget {
  final Language currentLanguage;
  final Function(Language) onLanguageSelected;
  final String title;
  final IconData titleIcon;

  const LanguageSelectionPopup({
    super.key,
    required this.currentLanguage,
    required this.onLanguageSelected,
    required this.title,
    required this.titleIcon,
  });

  @override
  State<LanguageSelectionPopup> createState() => _LanguageSelectionPopupState();
}

class _LanguageSelectionPopupState extends State<LanguageSelectionPopup> {
  final TextEditingController _searchController = TextEditingController();
  List<Language> _filteredLanguages = [];

  @override
  void initState() {
    super.initState();
    _filteredLanguages = LanguageConstants.allSupportedLanguages;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLanguages = LanguageConstants.allSupportedLanguages;
      } else {
        _filteredLanguages = LanguageConstants.allSupportedLanguages
            .where((lang) =>
                lang.name.toLowerCase().contains(query) ||
                lang.code.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: screenHeight * 0.8,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(context),
            Expanded(child: _buildLanguageList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(18), // Reducido de 20 a 18
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.titleIcon,
              color: colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  "Actual: ${widget.currentLanguage.name}",
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(14), // Reducido de 16 a 14
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Buscar idioma...",
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildLanguageList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        itemCount: _filteredLanguages.length,
        itemBuilder: (context, index) {
          final language = _filteredLanguages[index];
          final isSelected = language.code == widget.currentLanguage.code;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildLanguageCard(context, language, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context, Language language, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onLanguageSelected(language);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primaryContainer.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected 
                ? Border.all(color: colorScheme.primary, width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Bandera del idioma
              Text(
                LanguageConstants.getLanguageFlag(language.code),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              // Nombre del idioma
              Expanded(
                child: Text(
                  language.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected 
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              // Código del idioma
              Text(
                language.code.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected 
                      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              // Indicador de selección
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Función helper para mostrar el popup de selección de idiomas
Future<void> showLanguageSelectionPopup({
  required BuildContext context,
  required Language currentLanguage,
  required Function(Language) onLanguageSelected,
  required String title,
  required IconData titleIcon,
}) {
  return showDialog(
    context: context,
    builder: (context) => LanguageSelectionPopup(
      currentLanguage: currentLanguage,
      onLanguageSelected: onLanguageSelected,
      title: title,
      titleIcon: titleIcon,
    ),
  );
}
