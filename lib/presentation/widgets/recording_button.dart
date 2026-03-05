/// Widget pulsante streaming con animazione.
/// Mostra un pulsante circolare che avvia/ferma lo streaming live.
library;

import 'package:flutter/material.dart';
import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/domain/entities/pipeline_state.dart';

/// Pulsante di streaming con animazione pulsante
class RecordingButton extends StatefulWidget {
  /// Fase corrente della pipeline
  final PipelinePhase phase;

  /// Se lo streaming e' attivo
  final bool isStreaming;

  /// Callback quando si preme il pulsante
  final VoidCallback onPressed;

  const RecordingButton({
    super.key,
    required this.phase,
    required this.isStreaming,
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
    // Avvia/ferma l'animazione in base allo streaming
    if (widget.isStreaming) {
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
    final isProcessing = widget.phase == PipelinePhase.transcribing ||
        widget.phase == PipelinePhase.translating ||
        widget.phase == PipelinePhase.speaking;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Pulsante principale ---
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isStreaming ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isStreaming
                    ? AppColors.error
                    : AppColors.primaryBlue,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isStreaming
                            ? AppColors.error
                            : AppColors.primaryBlue)
                        .withValues(alpha: 0.4),
                    blurRadius: widget.isStreaming ? 24 : 16,
                    spreadRadius: widget.isStreaming ? 4 : 0,
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
                        widget.isStreaming ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 40,
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // --- Label stato ---
        Text(
          widget.isStreaming
              ? 'Tocca per fermare'
              : phaseDisplayName(widget.phase),
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
}
