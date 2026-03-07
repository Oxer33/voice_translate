/// Widget per la selezione della lingua con ricerca.
/// Mostra un bottom sheet con lista filtrata delle lingue supportate.
library;

import 'package:flutter/material.dart';
import 'package:voice_translate/core/constants/languages.dart';
import 'package:voice_translate/core/theme/app_theme.dart';

/// Widget selettore lingua con chip e ricerca
class LanguageSelector extends StatelessWidget {
  /// Label del selettore (es. "Lingua sorgente")
  final String label;

  /// Lingua attualmente selezionata
  final SupportedLanguage selectedLanguage;

  /// Callback quando si seleziona una lingua
  final ValueChanged<SupportedLanguage> onChanged;

  /// Se mostrare l'opzione "Rilevamento automatico"
  final bool showAutoDetect;

  const LanguageSelector({
    super.key,
    required this.label,
    required this.selectedLanguage,
    required this.onChanged,
    this.showAutoDetect = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showLanguagePicker(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLanguage.nameIt,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra il bottom sheet con la lista delle lingue
  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _LanguagePickerSheet(
        selectedLanguage: selectedLanguage,
        onChanged: onChanged,
        showAutoDetect: showAutoDetect,
      ),
    );
  }
}

/// Bottom sheet per la selezione della lingua con ricerca
class _LanguagePickerSheet extends StatefulWidget {
  final SupportedLanguage selectedLanguage;
  final ValueChanged<SupportedLanguage> onChanged;
  final bool showAutoDetect;

  const _LanguagePickerSheet({
    required this.selectedLanguage,
    required this.onChanged,
    required this.showAutoDetect,
  });

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  /// Controller per il campo di ricerca
  final _searchController = TextEditingController();

  /// Lista filtrata delle lingue
  List<SupportedLanguage> _filteredLanguages = kSupportedLanguages;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filtra le lingue in base al testo di ricerca
  void _onSearchChanged() {
    setState(() {
      _filteredLanguages = searchLanguages(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // --- Handle ---
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // --- Titolo ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Seleziona lingua',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- Campo di ricerca ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cerca lingua...',
                  prefixIcon: Icon(Icons.search),
                ),
                autofocus: true,
              ),
            ),

            const SizedBox(height: 8),

            // --- Lista lingue ---
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _filteredLanguages.length +
                    (widget.showAutoDetect ? 1 : 0),
                itemBuilder: (context, index) {
                  // Prima voce: Rilevamento automatico (se abilitato)
                  if (widget.showAutoDetect && index == 0) {
                    return _buildLanguageTile(
                      context,
                      kAutoDetectLanguage,
                      isSelected: widget.selectedLanguage == kAutoDetectLanguage,
                    );
                  }

                  final langIndex =
                      widget.showAutoDetect ? index - 1 : index;
                  final language = _filteredLanguages[langIndex];
                  final isSelected = widget.selectedLanguage == language;

                  return _buildLanguageTile(context, language,
                      isSelected: isSelected);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Costruisce un tile per una lingua
  Widget _buildLanguageTile(
    BuildContext context,
    SupportedLanguage language, {
    required bool isSelected,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        language.nameIt,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.primaryBlue : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: language.nllbCode != 'auto'
          ? Text(
              language.nllbCode,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primaryBlue)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () {
        widget.onChanged(language);
        Navigator.of(context).pop();
      },
    );
  }
}
