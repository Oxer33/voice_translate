library;

import 'package:flutter/material.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/core/utils/speech_text_formatter.dart';
import 'package:voice_translate/domain/entities/pipeline_state.dart';
import 'package:voice_translate/presentation/widgets/text_result_card.dart';

class LiveResultsPanel extends StatelessWidget {
  final PipelineState pipelineState;
  final bool showFullTranscription;

  const LiveResultsPanel({
    super.key,
    required this.pipelineState,
    required this.showFullTranscription,
  });

  @override
  Widget build(BuildContext context) {
    final currentOriginal = sanitizeSpeechText(
      pipelineState.currentTranscription ?? '',
    );
    final currentTranslation = sanitizeSpeechText(
      pipelineState.currentTranslation ?? '',
    );
    final fullOriginal = sanitizeSpeechText(pipelineState.fullTranscription);
    final fullTranslation = sanitizeSpeechText(pipelineState.fullTranslation);

    final hasDistinctCurrentTranslation =
        currentTranslation.isNotEmpty && currentTranslation != currentOriginal;
    final hasDistinctFullTranslation =
        fullTranslation.isNotEmpty && fullTranslation != fullOriginal;

    final children = <Widget>[];

    if (currentOriginal.isNotEmpty) {
      children.add(
        TextResultCard(
          title: hasDistinctCurrentTranslation ? 'Originale live' : 'Testo live',
          text: currentOriginal,
          icon: Icons.graphic_eq_rounded,
          accentColor: AppColors.primaryBlue,
          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
        ),
      );
    }

    if (hasDistinctCurrentTranslation) {
      children.add(
        TextResultCard(
          title: 'Traduzione live',
          text: currentTranslation,
          icon: Icons.translate_rounded,
          accentColor: AppColors.success,
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
        ),
      );
    }

    if (pipelineState.segments.length > 1) {
      if (showFullTranscription && fullOriginal.isNotEmpty) {
        children.add(
          TextResultCard(
            title:
                hasDistinctFullTranslation ? 'Trascrizione completa' : 'Testo completo',
            text: fullOriginal,
            icon: Icons.notes_rounded,
            accentColor: AppColors.primaryBlue,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
          ),
        );
      }

      if (hasDistinctFullTranslation) {
        children.add(
          TextResultCard(
            title: 'Traduzione completa',
            text: fullTranslation,
            icon: Icons.auto_awesome_rounded,
            accentColor: AppColors.success,
            backgroundColor: AppColors.success.withValues(alpha: 0.1),
          ),
        );
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(children: children);
  }
}
