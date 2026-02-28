/// Widget lista cronologia delle traduzioni.
/// Mostra le ultime 10 traduzioni con opzioni copia e elimina.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/domain/entities/translation_entry.dart';

/// Formato data/ora per la cronologia
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'it');

/// Lista delle traduzioni nella cronologia
class HistoryList extends StatelessWidget {
  /// Lista delle voci della cronologia
  final List<TranslationEntry> entries;

  /// Callback per eliminare una voce
  final ValueChanged<String> onDelete;

  const HistoryList({
    super.key,
    required this.entries,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Nessuna traduzione nella cronologia',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _HistoryTile(
          entry: entry,
          onDelete: () => onDelete(entry.id),
        );
      },
    );
  }
}

/// Tile singola della cronologia
class _HistoryTile extends StatelessWidget {
  final TranslationEntry entry;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: AppColors.error),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header: data e lingue ---
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Text(
                    _dateFormat.format(entry.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.sourceLanguageName} > ${entry.targetLanguageName}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // --- Testo originale (troncato) ---
              Text(
                entry.rawText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),

              const Divider(height: 16),

              // --- Testo tradotto ---
              Text(
                entry.translatedText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              // --- Azioni ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Copia originale
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: entry.rawText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Testo originale copiato'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copia originale',
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                  // Copia traduzione
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: entry.translatedText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Traduzione copiata'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.content_copy, size: 16),
                    tooltip: 'Copia traduzione',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                  // Elimina
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    tooltip: 'Elimina',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.error.withValues(alpha: 0.7),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
