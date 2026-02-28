/// Widget card per mostrare il progresso di download di un singolo modello.
/// Mostra nome, dimensione, velocita', barra di progresso e stato.
library;

import 'package:flutter/material.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/domain/entities/download_state.dart';

/// Card che mostra il progresso di download di un singolo modello
class DownloadProgressCard extends StatelessWidget {
  /// Stato del download del modello
  final ModelDownloadState downloadState;

  /// Callback per il retry manuale
  final VoidCallback? onRetry;

  /// Callback per la pausa
  final VoidCallback? onPause;

  const DownloadProgressCard({
    super.key,
    required this.downloadState,
    this.onRetry,
    this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header: nome modello e stato ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    downloadState.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(theme),
              ],
            ),

            const SizedBox(height: 12),

            // --- Barra di progresso ---
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: downloadState.status == DownloadStatus.completed
                    ? 1.0
                    : downloadState.progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // --- Info: dimensione scaricata / totale e velocita' ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${downloadState.downloadedFormatted} / ${downloadState.totalFormatted}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (downloadState.status == DownloadStatus.downloading)
                  Text(
                    downloadState.speedFormatted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),

            // --- Messaggio di errore e pulsante retry ---
            if (downloadState.status == DownloadStatus.error &&
                downloadState.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                downloadState.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onRetry != null)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Riprova'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                      ),
                    ),
                ],
              ),
            ],

            // --- Pulsante pausa per download in corso ---
            if (downloadState.status == DownloadStatus.downloading &&
                onPause != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause, size: 18),
                  label: const Text('Pausa'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warning,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Costruisce il badge di stato
  Widget _buildStatusBadge(ThemeData theme) {
    String label;
    Color color;
    IconData icon;

    switch (downloadState.status) {
      case DownloadStatus.pending:
        label = 'In attesa';
        color = theme.colorScheme.onSurface.withValues(alpha: 0.4);
        icon = Icons.hourglass_empty;
      case DownloadStatus.downloading:
        label = '${(downloadState.progress * 100).toStringAsFixed(0)}%';
        color = AppColors.primaryBlue;
        icon = Icons.download;
      case DownloadStatus.paused:
        label = 'In pausa';
        color = AppColors.warning;
        icon = Icons.pause_circle;
      case DownloadStatus.verifying:
        label = 'Verifica...';
        color = AppColors.info;
        icon = Icons.verified_user;
      case DownloadStatus.completed:
        label = 'Completato';
        color = AppColors.success;
        icon = Icons.check_circle;
      case DownloadStatus.error:
        label = 'Errore';
        color = AppColors.error;
        icon = Icons.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Colore della barra di progresso in base allo stato
  Color _getProgressColor() {
    switch (downloadState.status) {
      case DownloadStatus.completed:
        return AppColors.success;
      case DownloadStatus.error:
        return AppColors.error;
      case DownloadStatus.paused:
        return AppColors.warning;
      default:
        return AppColors.primaryBlue;
    }
  }
}
