/// Schermata impostazioni dell'app VoiceTranslate.
/// Gestisce toggle trascrizione, slider sensibilita'/TTS, gestione modelli e info.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voice_translate/core/constants/model_config.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/presentation/providers/app_providers.dart';
import 'package:voice_translate/presentation/providers/download_provider.dart';

/// Tag per i log di questo modulo
const String _tag = 'SettingsScreen';

/// Schermata delle impostazioni
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ========== SEZIONE: VISUALIZZAZIONE ==========
          _buildSectionHeader(theme, 'Visualizzazione'),

          // Toggle trascrizione originale
          _buildSwitchTile(
            theme: theme,
            title: 'Mostra trascrizione originale',
            subtitle:
                'Mostra il testo nella lingua originale oltre alla traduzione',
            value: settings.showTranscription,
            onChanged: (value) {
              AppLogger.info(_tag, 'Toggle trascrizione: $value');
              settingsNotifier.update(showTranscription: value);
            },
          ),

          const SizedBox(height: 8),

          // ========== SEZIONE: AUDIO ==========
          _buildSectionHeader(theme, 'Audio e Rilevamento'),

          // Slider sensibilita' silenzio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sensibilita\' silenzio',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          '${(settings.silenceSensitivity * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Piu\' alto = si ferma con suoni piu\' deboli',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    Slider(
                      value: settings.silenceSensitivity,
                      min: 0.01,
                      max: 0.15,
                      divisions: 14,
                      onChanged: (value) {
                        settingsNotifier.update(
                            silenceSensitivity: value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ========== SEZIONE: TTS ==========
          _buildSectionHeader(theme, 'Modalita\' Parlato (TTS)'),

          // Slider velocita' TTS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Velocita\' parlato',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          '${settings.ttsSpeed.toStringAsFixed(1)}x',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Regola la velocita\' della voce nella modalita\' parlato',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    Slider(
                      value: settings.ttsSpeed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: '${settings.ttsSpeed.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        settingsNotifier.update(ttsSpeed: value);
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lento',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                            )),
                        Text('Veloce',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ========== SEZIONE: MODELLI ==========
          _buildSectionHeader(theme, 'Modelli IA'),

          ...List.generate(kModelFiles.length, (index) {
            final config = kModelFiles[index];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                child: ListTile(
                  title: Text(
                    config.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '~${(config.expectedSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () => _confirmRedownload(
                        context, ref, index, config.displayName),
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Ri-scarica',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // ========== SEZIONE: INFO ==========
          _buildSectionHeader(theme, 'Informazioni'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(theme, 'Versione app', '2.0.0'),
                    const Divider(height: 16),
                    _buildInfoRow(theme, 'Trascrizione',
                        'Whisper Medium (1.5 GB)'),
                    const Divider(height: 16),
                    _buildInfoRow(theme, 'Traduzione',
                        'NLLB-200 distilled 600M'),
                    const Divider(height: 16),
                    _buildInfoRow(theme, 'Parlato',
                        'TTS nativo Android'),
                    const Divider(height: 16),
                    _buildInfoRow(theme, 'Modalita\'',
                        'Streaming live + offline'),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        child: SwitchListTile(
          title: Text(title, style: theme.textTheme.bodyLarge),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          value: value,
          onChanged: onChanged,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color:
                theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _confirmRedownload(
    BuildContext context,
    WidgetRef ref,
    int index,
    String modelName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ri-scarica modello'),
        content: Text(
            'Vuoi eliminare e ri-scaricare "$modelName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppLogger.info(_tag, 'Ri-download modello $index');
              ref
                  .read(downloadStateProvider.notifier)
                  .redownloadModel(index);
            },
            child: const Text('Ri-scarica'),
          ),
        ],
      ),
    );
  }
}
