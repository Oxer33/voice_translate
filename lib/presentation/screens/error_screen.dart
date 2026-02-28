/// Schermata di errore dell'app VoiceTranslate.
/// Mostrata quando un modello non riesce a caricarsi.
/// Offre azioni suggerite: riavvia, ri-scarica, salta.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/presentation/router/app_router.dart';

/// Schermata di errore con messaggi chiari e azioni suggerite
class ErrorScreen extends StatelessWidget {
  /// Messaggio di errore da mostrare
  final String errorMessage;

  const ErrorScreen({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- Icona errore ---
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 56,
                    color: AppColors.error,
                  ),
                ),

                const SizedBox(height: 32),

                // --- Titolo ---
                Text(
                  'Si e\' verificato un errore',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // --- Messaggio di errore ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    errorMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // --- Suggerimenti ---
                Text(
                  'Azioni suggerite:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                // Suggerimento 1: chiudi app
                _buildSuggestion(
                  theme,
                  icon: Icons.close,
                  text: 'Chiudi altre app per liberare memoria',
                ),

                // Suggerimento 2: ri-scarica
                _buildSuggestion(
                  theme,
                  icon: Icons.download,
                  text: 'Ri-scarica il modello dalla schermata impostazioni',
                ),

                // Suggerimento 3: riavvia
                _buildSuggestion(
                  theme,
                  icon: Icons.restart_alt,
                  text: 'Riavvia l\'app e riprova',
                ),

                const SizedBox(height: 32),

                // --- Pulsanti azione ---
                Row(
                  children: [
                    // Torna alla home
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go(AppRoutes.home),
                        icon: const Icon(Icons.home),
                        label: const Text('Torna alla home'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Vai ai download
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.go(AppRoutes.download),
                        icon: const Icon(Icons.download),
                        label: const Text('Ri-scarica'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Costruisce una riga di suggerimento
  Widget _buildSuggestion(
    ThemeData theme, {
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
