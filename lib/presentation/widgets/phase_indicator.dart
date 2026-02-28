/// Widget indicatore della fase corrente della pipeline.
/// Mostra spinner e nome della fase in corso.
library;

import 'package:flutter/material.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/domain/entities/pipeline_state.dart';

/// Indicatore visivo della fase corrente con spinner
class PhaseIndicator extends StatelessWidget {
  /// Fase corrente della pipeline
  final PipelinePhase phase;

  const PhaseIndicator({
    super.key,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    // Non mostrare nulla se in idle
    if (phase == PipelinePhase.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isProcessing = phase == PipelinePhase.transcribing ||
        phase == PipelinePhase.correcting ||
        phase == PipelinePhase.translating;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBackgroundColor(theme).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Spinner o icona stato
          if (isProcessing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getBackgroundColor(theme),
                ),
              ),
            )
          else
            Icon(
              _getIcon(),
              size: 20,
              color: _getBackgroundColor(theme),
            ),

          const SizedBox(width: 12),

          // Nome della fase
          Text(
            phaseDisplayName(phase),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _getBackgroundColor(theme),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Colore di sfondo in base alla fase
  Color _getBackgroundColor(ThemeData theme) {
    switch (phase) {
      case PipelinePhase.recording:
        return AppColors.error;
      case PipelinePhase.transcribing:
      case PipelinePhase.correcting:
      case PipelinePhase.translating:
        return AppColors.primaryBlue;
      case PipelinePhase.completed:
        return AppColors.success;
      case PipelinePhase.error:
        return AppColors.error;
      default:
        return theme.colorScheme.onSurface;
    }
  }

  /// Icona in base alla fase
  IconData _getIcon() {
    switch (phase) {
      case PipelinePhase.recording:
        return Icons.fiber_manual_record;
      case PipelinePhase.completed:
        return Icons.check_circle;
      case PipelinePhase.error:
        return Icons.error;
      default:
        return Icons.pending;
    }
  }
}
