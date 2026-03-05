/// Stati della pipeline di elaborazione vocale streaming.
/// Supporta due modalità: TEXT (sottotitoli) e SPEECH (parlato TTS).
/// Pipeline semplificata: registrazione -> trascrizione -> traduzione (no correzione).
library;

// ============================================================
// MODALITÀ DELL'APP
// ============================================================

/// Modalità di funzionamento dell'app
enum AppMode {
  /// Modalità sottotitoli: mostra traduzione come testo a schermo
  text,

  /// Modalità parlato: pronuncia la traduzione con TTS
  speech,
}

/// Nome italiano della modalità per l'UI
String modeDisplayName(AppMode mode) {
  switch (mode) {
    case AppMode.text:
      return 'Sottotitoli';
    case AppMode.speech:
      return 'Parlato';
  }
}

// ============================================================
// FASI DELLA PIPELINE
// ============================================================

/// Fase corrente della pipeline streaming
enum PipelinePhase {
  /// In attesa, nessuna elaborazione in corso
  idle,

  /// Streaming attivo: ascolto continuo dal microfono
  listening,

  /// Trascrizione chunk audio con Whisper
  transcribing,

  /// Traduzione testo con NLLB-200
  translating,

  /// Riproduzione TTS della traduzione (solo modalità speech)
  speaking,

  /// Errore durante l'elaborazione
  error,
}

/// Nome italiano della fase per l'UI
String phaseDisplayName(PipelinePhase phase) {
  switch (phase) {
    case PipelinePhase.idle:
      return 'Tocca per iniziare';
    case PipelinePhase.listening:
      return 'In ascolto...';
    case PipelinePhase.transcribing:
      return 'Trascrizione...';
    case PipelinePhase.translating:
      return 'Traduzione...';
    case PipelinePhase.speaking:
      return 'Riproduzione...';
    case PipelinePhase.error:
      return 'Errore';
  }
}

// ============================================================
// SINGOLO SEGMENTO TRASCRITTO/TRADOTTO
// ============================================================

/// Rappresenta un singolo segmento di testo trascritto e tradotto
class TranslatedSegment {
  /// Testo trascritto dal chunk audio (lingua originale)
  final String transcribedText;

  /// Testo tradotto nella lingua target
  final String translatedText;

  /// Timestamp di quando è stato generato
  final DateTime timestamp;

  const TranslatedSegment({
    required this.transcribedText,
    required this.translatedText,
    required this.timestamp,
  });
}

// ============================================================
// STATO COMPLETO DELLA PIPELINE
// ============================================================

/// Stato completo della pipeline streaming con segmenti live
class PipelineState {
  /// Modalità corrente (testo o parlato)
  final AppMode mode;

  /// Fase corrente della pipeline
  final PipelinePhase phase;

  /// Lista di segmenti trascritti e tradotti (cronologici)
  final List<TranslatedSegment> segments;

  /// Testo trascritto dell'ultimo chunk (aggiornato in tempo reale)
  final String? currentTranscription;

  /// Testo tradotto dell'ultimo chunk (aggiornato in tempo reale)
  final String? currentTranslation;

  /// Lingua sorgente rilevata da Whisper
  final String? detectedLanguage;

  /// Messaggio di errore (se phase == error)
  final String? errorMessage;

  /// Se lo streaming è attualmente attivo
  final bool isStreaming;

  const PipelineState({
    this.mode = AppMode.text,
    this.phase = PipelinePhase.idle,
    this.segments = const [],
    this.currentTranscription,
    this.currentTranslation,
    this.detectedLanguage,
    this.errorMessage,
    this.isStreaming = false,
  });

  /// Crea una copia con i campi modificati
  PipelineState copyWith({
    AppMode? mode,
    PipelinePhase? phase,
    List<TranslatedSegment>? segments,
    String? currentTranscription,
    String? currentTranslation,
    String? detectedLanguage,
    String? errorMessage,
    bool? isStreaming,
  }) =>
      PipelineState(
        mode: mode ?? this.mode,
        phase: phase ?? this.phase,
        segments: segments ?? this.segments,
        currentTranscription:
            currentTranscription ?? this.currentTranscription,
        currentTranslation:
            currentTranslation ?? this.currentTranslation,
        detectedLanguage: detectedLanguage ?? this.detectedLanguage,
        errorMessage: errorMessage ?? this.errorMessage,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  /// Stato iniziale/reset
  factory PipelineState.initial({AppMode mode = AppMode.text}) =>
      PipelineState(mode: mode);

  /// Stato di errore
  factory PipelineState.error(String message) => PipelineState(
        phase: PipelinePhase.error,
        errorMessage: message,
      );

  /// Testo trascritto completo (tutti i segmenti concatenati)
  String get fullTranscription =>
      segments.map((s) => s.transcribedText).join(' ');

  /// Testo tradotto completo (tutti i segmenti concatenati)
  String get fullTranslation =>
      segments.map((s) => s.translatedText).join(' ');

  /// Verifica se la pipeline è in elaborazione
  bool get isProcessing =>
      phase == PipelinePhase.transcribing ||
      phase == PipelinePhase.translating ||
      phase == PipelinePhase.speaking;

  @override
  String toString() =>
      'PipelineState(mode: $mode, phase: $phase, segments: ${segments.length})';
}
