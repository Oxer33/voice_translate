/// Schermata principale dell'app VoiceTranslate.
/// Contiene selettori lingua, pulsante registrazione, risultati e cronologia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voice_translate/core/constants/languages.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/core/utils/permissions_helper.dart';
import 'package:voice_translate/domain/entities/pipeline_state.dart';
import 'package:voice_translate/presentation/providers/app_providers.dart';
import 'package:voice_translate/presentation/providers/history_provider.dart';
import 'package:voice_translate/presentation/providers/pipeline_provider.dart';
import 'package:voice_translate/presentation/router/app_router.dart';
import 'package:voice_translate/presentation/widgets/history_list.dart';
import 'package:voice_translate/presentation/widgets/language_selector.dart';
import 'package:voice_translate/presentation/widgets/phase_indicator.dart';
import 'package:voice_translate/presentation/widgets/recording_button.dart';
import 'package:voice_translate/presentation/widgets/text_result_card.dart';

/// Tag per i log di questo modulo
const String _tag = 'HomeScreen';

/// Schermata principale con registrazione e risultati
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    AppLogger.info(_tag, 'HomeScreen inizializzata');
    _initPermissionsAndHistory();
  }

  /// Inizializza permessi e carica cronologia
  Future<void> _initPermissionsAndHistory() async {
    // Richiedi permesso microfono
    await PermissionsHelper.requestMicrophonePermission();

    // Carica cronologia
    ref.read(historyListProvider.notifier).load();

    // Carica impostazioni e ripristina ultime lingue
    await ref.read(appSettingsProvider.notifier).load();
    final settings = ref.read(appSettingsProvider);

    // Ripristina lingue dalla sessione precedente
    final pipeline = ref.read(pipelineStateProvider.notifier);

    if (settings.lastSourceLanguageCode == 'auto') {
      pipeline.setSourceLanguage(kAutoDetectLanguage);
    } else {
      final srcLang =
          findLanguageByNllbCode(settings.lastSourceLanguageCode);
      if (srcLang != null) pipeline.setSourceLanguage(srcLang);
    }

    final tgtLang =
        findLanguageByNllbCode(settings.lastTargetLanguageCode);
    if (tgtLang != null) pipeline.setTargetLanguage(tgtLang);

    // Sincronizza stato correzione
    pipeline.setCorrectionEnabled(settings.correctionEnabled);
  }

  /// Gestisce la pressione del pulsante di registrazione
  Future<void> _handleRecordButton() async {
    final pipeline = ref.read(pipelineStateProvider.notifier);
    final currentPhase = ref.read(pipelineStateProvider).phase;

    if (currentPhase == PipelinePhase.recording) {
      // Ferma registrazione e processa
      AppLogger.info(_tag, 'Stop registrazione da pulsante');
      await pipeline.stopRecordingAndProcess();
      // Aggiorna cronologia dopo elaborazione
      ref.read(historyListProvider.notifier).refresh();
    } else if (currentPhase == PipelinePhase.idle ||
        currentPhase == PipelinePhase.completed ||
        currentPhase == PipelinePhase.error) {
      // Verifica permesso microfono
      final hasPermission =
          await PermissionsHelper.isMicrophoneGranted();
      if (!hasPermission) {
        final granted =
            await PermissionsHelper.requestMicrophonePermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Permesso microfono necessario per la registrazione'),
              ),
            );
          }
          return;
        }
      }

      // Avvia registrazione
      AppLogger.info(_tag, 'Avvio registrazione da pulsante');
      pipeline.reset();
      await pipeline.startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipelineState = ref.watch(pipelineStateProvider);
    final pipeline = ref.read(pipelineStateProvider.notifier);
    final settings = ref.watch(appSettingsProvider);
    final history = ref.watch(historyListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VoiceTranslate'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Impostazioni',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // --- Selettori lingua ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Lingua sorgente
                  Expanded(
                    child: LanguageSelector(
                      label: 'Da',
                      selectedLanguage: pipeline.sourceLanguage,
                      onChanged: (lang) {
                        pipeline.setSourceLanguage(lang);
                        ref.read(appSettingsProvider.notifier).update(
                              lastSourceLanguageCode: lang.nllbCode,
                            );
                      },
                      showAutoDetect: true,
                    ),
                  ),

                  // Pulsante scambia lingue
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                      onPressed: () {
                        final src = pipeline.sourceLanguage;
                        final tgt = pipeline.targetLanguage;
                        // Non scambiare se sorgente e' "auto"
                        if (src.nllbCode == 'auto') return;
                        pipeline.setSourceLanguage(tgt);
                        pipeline.setTargetLanguage(src);
                        ref.read(appSettingsProvider.notifier).update(
                              lastSourceLanguageCode: tgt.nllbCode,
                              lastTargetLanguageCode: src.nllbCode,
                            );
                      },
                      icon: const Icon(Icons.swap_horiz),
                      tooltip: 'Scambia lingue',
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                      ),
                    ),
                  ),

                  // Lingua target
                  Expanded(
                    child: LanguageSelector(
                      label: 'A',
                      selectedLanguage: pipeline.targetLanguage,
                      onChanged: (lang) {
                        pipeline.setTargetLanguage(lang);
                        ref.read(appSettingsProvider.notifier).update(
                              lastTargetLanguageCode: lang.nllbCode,
                            );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- Pulsante registrazione ---
            Center(
              child: RecordingButton(
                phase: pipelineState.phase,
                remainingSeconds: pipelineState.remainingSeconds,
                onPressed: _handleRecordButton,
              ),
            ),

            const SizedBox(height: 16),

            // --- Indicatore fase corrente ---
            PhaseIndicator(phase: pipelineState.phase),

            const SizedBox(height: 16),

            // --- Risultati ---
            // Testo trascritto grezzo
            TextResultCard(
              title: 'Testo trascritto',
              text: pipelineState.rawText,
              icon: Icons.text_fields,
              visible: settings.showRawText,
            ),

            // Testo corretto
            TextResultCard(
              title: 'Testo corretto',
              text: pipelineState.correctedText,
              icon: Icons.auto_fix_high,
              visible: settings.correctionEnabled,
            ),

            // Testo tradotto
            TextResultCard(
              title: 'Testo tradotto',
              text: pipelineState.translatedText,
              icon: Icons.translate,
            ),

            // --- Errore ---
            if (pipelineState.phase == PipelinePhase.error &&
                pipelineState.errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
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
                    const Icon(Icons.error_outline,
                        color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pipelineState.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // --- Sezione cronologia ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Cronologia',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${history.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            HistoryList(
              entries: history,
              onDelete: (id) {
                ref.read(historyListProvider.notifier).delete(id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
