/// Schermata principale dell'app VoiceTranslate.
/// Due modalita': sottotitoli (testo a schermo) e parlato (TTS).
/// Streaming live: trascrizione e traduzione in tempo reale.
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

/// Schermata principale con streaming live a due modalita'
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
    await PermissionsHelper.requestMicrophonePermission();
    ref.read(historyListProvider.notifier).load();
    await ref.read(appSettingsProvider.notifier).load();

    final settings = ref.read(appSettingsProvider);
    final pipeline = ref.read(pipelineStateProvider.notifier);

    // Ripristina lingue dalla sessione precedente
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

    // Ripristina modalita'
    final mode =
        settings.lastMode == 'speech' ? AppMode.speech : AppMode.text;
    pipeline.setMode(mode);

    // Ripristina modello Whisper selezionato
    pipeline.setWhisperModel(settings.selectedWhisperModelId);
  }

  /// Gestisce la pressione del pulsante streaming
  Future<void> _handleStreamButton() async {
    final pipeline = ref.read(pipelineStateProvider.notifier);
    final currentState = ref.read(pipelineStateProvider);

    if (currentState.isStreaming) {
      // Ferma lo streaming
      AppLogger.info(_tag, 'Stop streaming da pulsante');
      await pipeline.stopStreaming();
      ref.read(historyListProvider.notifier).refresh();
    } else {
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
                    'Permesso microfono necessario per lo streaming'),
              ),
            );
          }
          return;
        }
      }

      // Avvia streaming
      AppLogger.info(_tag, 'Avvio streaming da pulsante');
      pipeline.reset();
      await pipeline.startStreaming();
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

            // --- Toggle modalita' TEXT / SPEECH ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ModeToggle(
                currentMode: pipelineState.mode,
                onChanged: (mode) {
                  pipeline.setMode(mode);
                  ref.read(appSettingsProvider.notifier).update(
                        lastMode: mode == AppMode.speech ? 'speech' : 'text',
                      );
                },
              ),
            ),

            const SizedBox(height: 12),

            // --- Selettori lingua ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                      onPressed: () {
                        final src = pipeline.sourceLanguage;
                        final tgt = pipeline.targetLanguage;
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

            // --- Pulsante streaming ---
            Center(
              child: RecordingButton(
                phase: pipelineState.phase,
                isStreaming: pipelineState.isStreaming,
                onPressed: _handleStreamButton,
              ),
            ),

            const SizedBox(height: 16),

            // --- Indicatore fase corrente ---
            PhaseIndicator(phase: pipelineState.phase),

            const SizedBox(height: 16),

            // --- Area risultati live ---
            // Traduzione corrente (grande, in evidenza)
            if (pipelineState.currentTranslation != null)
              TextResultCard(
                title: 'Traduzione',
                text: pipelineState.currentTranslation,
                icon: Icons.translate,
              ),

            // Trascrizione corrente (piccola, opzionale)
            if (settings.showTranscription &&
                pipelineState.currentTranscription != null)
              TextResultCard(
                title: 'Trascrizione originale',
                text: pipelineState.currentTranscription,
                icon: Icons.text_fields,
              ),

            // --- Testo completo accumulato ---
            if (pipelineState.segments.length > 1)
              TextResultCard(
                title: 'Traduzione completa',
                text: pipelineState.fullTranslation,
                icon: Icons.list_alt,
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

/// Toggle per la modalita' TEXT / SPEECH
class _ModeToggle extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onChanged;

  const _ModeToggle({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Pulsante sottotitoli
          Expanded(
            child: _ModeButton(
              label: 'Sottotitoli',
              icon: Icons.subtitles,
              isSelected: currentMode == AppMode.text,
              onTap: () => onChanged(AppMode.text),
            ),
          ),
          // Pulsante parlato
          Expanded(
            child: _ModeButton(
              label: 'Parlato',
              icon: Icons.record_voice_over,
              isSelected: currentMode == AppMode.speech,
              onTap: () => onChanged(AppMode.speech),
            ),
          ),
        ],
      ),
    );
  }
}

/// Singolo pulsante del toggle modalita'
class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
