/// Widget pulsante di registrazione con animazione.
/// Mostra un pulsante circolare animato con countdown.
library;

import 'package:flutter/material.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/domain/entities/pipeline_state.dart';

/// Pulsante di registrazione con animazione pulsante e countdown
class RecordingButton extends StatefulWidget {
  /// Fase corrente della pipeline
  final PipelinePhase phase;

  /// Secondi rimanenti (0-60)
  final int remainingSeconds;

  /// Callback quando si preme il pulsante
  final VoidCallback onPressed;

  const RecordingButton({
    super.key,
    required this.phase,
    required this.remainingSeconds,
    required this.onPressed,
  });

  @override
  State<RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<RecordingButton>
    with SingleTickerProviderStateMixin {
  /// Controller per l'animazione pulsante
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(RecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Avvia/ferma l'animazione in base alla fase
    if (widget.phase == PipelinePhase.recording) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = widget.phase == PipelinePhase.recording;
    final isProcessing = widget.phase == PipelinePhase.transcribing ||
        widget.phase == PipelinePhase.correcting ||
        widget.phase == PipelinePhase.translating;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Countdown timer ---
        if (isRecording) ...[
          Text(
            _formatSeconds(widget.remainingSeconds),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                  color: widget.remainingSeconds <= 10
                      ? AppColors.error
                      : AppColors.primaryBlue,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 16),
        ],

        // --- Pulsante principale ---
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isRecording ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: isProcessing ? null : widget.onPressed,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? AppColors.error
                    : isProcessing
                        ? AppColors.darkTextTertiary
                        : AppColors.primaryBlue,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording
                            ? AppColors.error
                            : AppColors.primaryBlue)
                        .withValues(alpha: 0.4),
                    blurRadius: isRecording ? 24 : 16,
                    spreadRadius: isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: Center(
                child: isProcessing
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 36,
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // --- Label stato ---
        Text(
          _getStatusLabel(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  /// Formatta i secondi come "0:45"
  String _formatSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  /// Testo dello stato corrente
  String _getStatusLabel() {
    switch (widget.phase) {
      case PipelinePhase.idle:
        return 'Tocca per registrare';
      case PipelinePhase.recording:
        return 'Registrazione in corso...';
      case PipelinePhase.transcribing:
        return 'Trascrizione...';
      case PipelinePhase.correcting:
        return 'Correzione...';
      case PipelinePhase.translating:
        return 'Traduzione...';
      case PipelinePhase.completed:
        return 'Completato!';
      case PipelinePhase.error:
        return 'Errore';
    }
  }
}
