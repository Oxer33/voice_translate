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

  /// Colore principale della card
  final Color accentColor;

  /// Colore di sfondo opzionale della card
  final Color? backgroundColor;

  const TextResultCard({
    super.key,
    required this.title,
    required this.text,
    required this.icon,
    this.visible = true,
    this.accentColor = AppColors.primaryBlue,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || text == null || text!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: backgroundColor ?? accentColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header con titolo e pulsante copia ---
            Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accentColor,
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
