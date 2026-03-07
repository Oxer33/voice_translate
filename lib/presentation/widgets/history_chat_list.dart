library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/core/utils/speech_text_formatter.dart';
import 'package:voice_translate/domain/entities/translation_entry.dart';

final DateFormat _historyChatDateFormat = DateFormat('dd MMM yyyy • HH:mm', 'it');

class HistoryChatList extends StatelessWidget {
  final List<TranslationEntry> entries;
  final ValueChanged<String> onDelete;

  const HistoryChatList({
    super.key,
    required this.entries,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final filteredEntries = entries.where((entry) {
      final rawText = sanitizeSpeechText(entry.rawText);
      final translatedText = sanitizeSpeechText(entry.translatedText);
      return rawText.isNotEmpty || translatedText.isNotEmpty;
    }).toList(growable: false);

    if (filteredEntries.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryBlue.withValues(alpha: 0.22),
                      AppColors.accentPurple.withValues(alpha: 0.22),
                      AppColors.accentCyan.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.history_edu_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nessuna sessione salvata',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quando fermerai una sessione, qui vedrai trascrizione e traduzione in formato chat.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: filteredEntries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = filteredEntries[index];
        return _HistorySessionCard(
          entry: entry,
          onDelete: () => onDelete(entry.id),
        );
      },
    );
  }
}

class _HistorySessionCard extends StatelessWidget {
  final TranslationEntry entry;
  final VoidCallback onDelete;

  const _HistorySessionCard({
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final originalText = sanitizeSpeechText(entry.rawText);
    final translatedText = sanitizeSpeechText(entry.translatedText);
    final resolvedOriginal = originalText.isNotEmpty ? originalText : translatedText;
    final resolvedTranslation =
        translatedText.isNotEmpty ? translatedText : resolvedOriginal;
    final isTextOnly = entry.sourceLanguageCode == entry.targetLanguageCode &&
        resolvedOriginal.trim() == resolvedTranslation.trim();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _historyChatDateFormat.format(entry.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _LanguagePill(
                    text: '${entry.sourceLanguageName} > ${entry.targetLanguageName}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _HistoryBubble(
              label: isTextOnly
                  ? 'Trascrizione'
                  : 'Originale • ${entry.sourceLanguageName}',
              text: resolvedOriginal,
              maxWidth: screenWidth * 0.82,
              alignment: Alignment.centerLeft,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.08),
              textColor: theme.colorScheme.onSurface,
              labelColor: AppColors.primaryBlueLight,
              borderColor: AppColors.primaryBlue.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(22),
              ),
            ),
            if (!isTextOnly) ...[
              const SizedBox(height: 12),
              _HistoryBubble(
                label: 'Traduzione • ${entry.targetLanguageName}',
                text: resolvedTranslation,
                maxWidth: screenWidth * 0.82,
                alignment: Alignment.centerRight,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.success,
                    AppColors.accentTeal,
                    AppColors.accentCyan,
                  ],
                ),
                textColor: Colors.white,
                labelColor: Colors.white.withValues(alpha: 0.84),
                borderColor: Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.copy_all_rounded, size: 18),
                  label: Text(isTextOnly ? 'Copia testo' : 'Copia sessione'),
                  onPressed: () => _copyToClipboard(
                    context,
                    isTextOnly
                        ? resolvedOriginal
                        : _combinedSessionText(resolvedOriginal, resolvedTranslation),
                    isTextOnly ? 'Testo copiato' : 'Sessione copiata',
                  ),
                ),
                if (!isTextOnly)
                  ActionChip(
                    avatar: const Icon(Icons.translate_rounded, size: 18),
                    label: const Text('Copia traduzione'),
                    onPressed: () => _copyToClipboard(
                      context,
                      resolvedTranslation,
                      'Traduzione copiata',
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  label: const Text('Elimina'),
                  onPressed: () async {
                    final confirmed = await _confirmDelete(context);
                    if (confirmed == true) {
                      onDelete();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _combinedSessionText(String originalText, String translatedText) {
    return 'Originale (${entry.sourceLanguageName})\n$originalText\n\nTraduzione (${entry.targetLanguageName})\n$translatedText';
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare questa sessione?'),
        content: const Text(
          'La sessione verrà rimossa dalla cronologia in modo permanente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  final String text;

  const _LanguagePill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.14),
            AppColors.accentPurple.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppColors.primaryBlueLight,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryBubble extends StatelessWidget {
  final String label;
  final String text;
  final double maxWidth;
  final Alignment alignment;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color textColor;
  final Color labelColor;
  final Color borderColor;
  final BorderRadius borderRadius;

  const _HistoryBubble({
    required this.label,
    required this.text,
    required this.maxWidth,
    required this.alignment,
    required this.textColor,
    required this.labelColor,
    required this.borderColor,
    required this.borderRadius,
    this.gradient,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          gradient: gradient,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: textColor,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
