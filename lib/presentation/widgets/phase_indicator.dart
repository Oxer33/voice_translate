/// Widget indicatore della fase corrente della pipeline streaming.
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
        phase == PipelinePhase.translating;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getColor(theme).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getColor(theme).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Spinner o icona stato
          if (isProcessing || phase == PipelinePhase.listening)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getColor(theme),
                ),
              ),
            )
          else
            Icon(
              _getIcon(),
              size: 20,
              color: _getColor(theme),
            ),

          const SizedBox(width: 12),

          // Nome della fase
          Text(
            phaseDisplayName(phase),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _getColor(theme),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Colore in base alla fase
  Color _getColor(ThemeData theme) {
    switch (phase) {
      case PipelinePhase.listening:
        return AppColors.success;
      case PipelinePhase.transcribing:
      case PipelinePhase.translating:
        return AppColors.primaryBlue;
      case PipelinePhase.speaking:
        return AppColors.info;
      case PipelinePhase.error:
        return AppColors.error;
      default:
        return theme.colorScheme.onSurface;
    }
  }

  /// Icona in base alla fase
  IconData _getIcon() {
    switch (phase) {
      case PipelinePhase.listening:
        return Icons.hearing;
      case PipelinePhase.speaking:
        return Icons.volume_up;
      case PipelinePhase.error:
        return Icons.error;
      default:
        return Icons.pending;
    }
  }
}
