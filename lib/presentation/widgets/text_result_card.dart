/// Widget card per mostrare un risultato testuale con pulsante copia.
/// Usato per testo grezzo, corretto e tradotto.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:voice_translate/core/theme/app_theme.dart';

/// Card per mostrare un risultato testuale con titolo e pulsante copia
class TextResultCard extends StatelessWidget {
  /// Titolo della sezione (es. "Testo trascritto")
  final String title;

  /// Testo da mostrare
  final String? text;

  /// Icona del titolo
  final IconData icon;

  /// Se la card e' visibile
  final bool visible;

  const TextResultCard({
    super.key,
    required this.title,
    required this.text,
    required this.icon,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || text == null || text!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header con titolo e pulsante copia ---
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Pulsante copia negli appunti
                IconButton(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copia negli appunti',
                  style: IconButton.styleFrom(
                    foregroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // --- Testo ---
            SelectableText(
              text!,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Copia il testo negli appunti e mostra una notifica
  void _copyToClipboard(BuildContext context) {
    if (text == null || text!.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title copiato negli appunti'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
