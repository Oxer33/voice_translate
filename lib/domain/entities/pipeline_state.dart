/// Stati della pipeline di elaborazione vocale.
/// Rappresenta ogni fase del processo: registrazione -> trascrizione -> correzione -> traduzione.
library;

/// Fase corrente della pipeline
enum PipelinePhase {
  /// In attesa, nessuna elaborazione in corso
  idle,

  /// Registrazione audio in corso
  recording,

  /// Trascrizione audio con Whisper
  transcribing,

  /// Correzione testo con Phi-3
  correcting,

  /// Traduzione testo con NLLB-200
  translating,

  /// Elaborazione completata con successo
  completed,

  /// Errore durante l'elaborazione
  error,
}

/// Restituisce il nome italiano della fase per l'UI
String phaseDisplayName(PipelinePhase phase) {
  switch (phase) {
    case PipelinePhase.idle:
      return 'In attesa';
    case PipelinePhase.recording:
      return 'Registrazione...';
    case PipelinePhase.transcribing:
      return 'Trascrizione...';
    case PipelinePhase.correcting:
      return 'Correzione...';
    case PipelinePhase.translating:
      return 'Traduzione...';
    case PipelinePhase.completed:
      return 'Completato';
    case PipelinePhase.error:
      return 'Errore';
  }
}

/// Stato completo della pipeline con risultati parziali
class PipelineState {
  /// Fase corrente
  final PipelinePhase phase;

  /// Testo trascritto grezzo (dopo Whisper)
  final String? rawText;

  /// Testo corretto (dopo Phi-3)
  final String? correctedText;

  /// Testo tradotto (dopo NLLB)
  final String? translatedText;

  /// Lingua sorgente rilevata da Whisper
  final String? detectedLanguage;

  /// Messaggio di errore (se phase == error)
  final String? errorMessage;

  /// Secondi rimanenti nella registrazione
  final int remainingSeconds;

  /// Se la correzione Phi-3 è abilitata
  final bool correctionEnabled;

  const PipelineState({
    this.phase = PipelinePhase.idle,
    this.rawText,
    this.correctedText,
    this.translatedText,
    this.detectedLanguage,
    this.errorMessage,
    this.remainingSeconds = 60,
    this.correctionEnabled = true,
  });

  /// Crea una copia con i campi modificati
  PipelineState copyWith({
    PipelinePhase? phase,
    String? rawText,
    String? correctedText,
    String? translatedText,
    String? detectedLanguage,
    String? errorMessage,
    int? remainingSeconds,
    bool? correctionEnabled,
  }) =>
      PipelineState(
        phase: phase ?? this.phase,
        rawText: rawText ?? this.rawText,
        correctedText: correctedText ?? this.correctedText,
        translatedText: translatedText ?? this.translatedText,
        detectedLanguage: detectedLanguage ?? this.detectedLanguage,
        errorMessage: errorMessage ?? this.errorMessage,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        correctionEnabled: correctionEnabled ?? this.correctionEnabled,
      );

  /// Stato iniziale/reset
  factory PipelineState.initial({bool correctionEnabled = true}) =>
      PipelineState(correctionEnabled: correctionEnabled);

  /// Stato di errore
  factory PipelineState.error(String message) => PipelineState(
        phase: PipelinePhase.error,
        errorMessage: message,
      );

  /// Verifica se la pipeline è in elaborazione
  bool get isProcessing =>
      phase == PipelinePhase.transcribing ||
      phase == PipelinePhase.correcting ||
      phase == PipelinePhase.translating;

  @override
  String toString() => 'PipelineState(phase: $phase)';
}
