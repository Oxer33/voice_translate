/// Schermata di download dei modelli ML.
/// Mostra il progresso di download di ogni modello con barra, velocita' e stato.
/// Gestisce errori, retry e verifica spazio su disco.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/domain/entities/download_state.dart';
import 'package:voice_translate/presentation/providers/download_provider.dart';
import 'package:voice_translate/presentation/router/app_router.dart';
import 'package:voice_translate/presentation/widgets/download_progress_card.dart';

/// Tag per i log di questo modulo
const String _tag = 'DownloadScreen';

/// Schermata di setup iniziale con download automatico dei modelli
class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({super.key});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  @override
  void initState() {
    super.initState();
    AppLogger.info(_tag, 'DownloadScreen inizializzata');
    // Avvia la verifica iniziale e il download
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDownloads();
    });
  }

  /// Avvia il processo di verifica e download
  Future<void> _startDownloads() async {
    AppLogger.info(_tag, 'Avvio processo download...');
    final notifier = ref.read(downloadStateProvider.notifier);

    // Verifica stato iniziale (spazio disco, modelli gia' presenti)
    await notifier.checkInitialState();

    // Se tutti i modelli sono pronti, vai alla home
    final state = ref.read(downloadStateProvider);
    if (state.allCompleted) {
      AppLogger.info(_tag, 'Tutti i modelli pronti, navigazione alla home');
      if (mounted) {
        context.go(AppRoutes.home);
      }
      return;
    }

    // Se c'e' errore globale (spazio insufficiente), non avviare i download
    if (state.globalError != null) {
      AppLogger.warning(_tag, 'Errore globale: ${state.globalError}');
      return;
    }

    // Avvia i download
    await notifier.startAllDownloads();

    // Dopo i download, naviga alla home se tutto ok
    final finalState = ref.read(downloadStateProvider);
    if (finalState.allCompleted && mounted) {
      AppLogger.info(_tag, 'Download completati, navigazione alla home');
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Icona app
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.primaryBlueLight
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'VoiceTranslate',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Preparazione dei modelli di intelligenza artificiale',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Errore globale (spazio insufficiente) ---
            if (downloadState.globalError != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: AppColors.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        downloadState.globalError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // --- Progresso totale ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progresso totale',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '${(downloadState.totalProgress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: downloadState.totalProgress,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Spazio disponibile: ${downloadState.availableSpaceFormatted}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- Lista modelli con progresso individuale ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: downloadState.models.length,
                itemBuilder: (context, index) {
                  final modelState = downloadState.models[index];
                  return DownloadProgressCard(
                    downloadState: modelState,
                    onRetry: () {
                      ref
                          .read(downloadStateProvider.notifier)
                          .retryDownload(index);
                    },
                    onPause: () {
                      ref
                          .read(downloadStateProvider.notifier)
                          .pauseDownload(index);
                    },
                  );
                },
              ),
            ),

            // --- Pulsanti azione in basso ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Pulsante annulla
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref
                            .read(downloadStateProvider.notifier)
                            .cancelAllDownloads();
                      },
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Pulsante riprova tutto
                  Expanded(
                    child: ElevatedButton(
                      onPressed: downloadState.models.any(
                              (m) => m.status == DownloadStatus.error)
                          ? _startDownloads
                          : null,
                      child: const Text('Riprova tutto'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
