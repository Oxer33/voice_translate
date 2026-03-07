library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/core/utils/speech_text_formatter.dart';
import 'package:voice_translate/presentation/providers/history_provider.dart';
import 'package:voice_translate/presentation/widgets/history_chat_list.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyListProvider);
    final visibleHistory = history.where((entry) {
      final rawText = sanitizeSpeechText(entry.rawText);
      final translatedText = sanitizeSpeechText(entry.translatedText);
      return rawText.isNotEmpty || translatedText.isNotEmpty;
    }).toList(growable: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronologia chat'),
        actions: [
          if (visibleHistory.isNotEmpty)
            IconButton(
              onPressed: () => _confirmDeleteAll(context, ref),
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Svuota cronologia',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: 0.18),
                  AppColors.accentPurple.withValues(alpha: 0.18),
                  AppColors.accentCyan.withValues(alpha: 0.14),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessioni salvate',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visibleHistory.isEmpty
                            ? 'Qui compariranno le tue sessioni complete in formato chat.'
                            : '${visibleHistory.length} sessioni disponibili con testo selezionabile e copia rapida.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: HistoryChatList(
              entries: visibleHistory,
              onDelete: (id) => ref.read(historyListProvider.notifier).delete(id),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Svuotare tutta la cronologia?'),
        content: const Text(
          'Tutte le sessioni salvate verranno eliminate in modo permanente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina tutto'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await ref.read(historyListProvider.notifier).deleteAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cronologia eliminata'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}
