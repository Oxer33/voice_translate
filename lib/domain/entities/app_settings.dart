/// Entità per le impostazioni dell'app.
/// Gestisce preferenze utente persistenti.
library;

/// Impostazioni dell'applicazione
class AppSettings {
  /// Se mostrare il testo trascritto originale nella schermata principale
  final bool showTranscription;

  /// Sensibilità del rilevamento silenzio (0.0 - 1.0)
  final double silenceSensitivity;

  /// Codice NLLB dell'ultima lingua sorgente usata
  final String lastSourceLanguageCode;

  /// Codice NLLB dell'ultima lingua target usata
  final String lastTargetLanguageCode;

  /// Ultima modalità usata ('text' o 'speech')
  final String lastMode;

  /// Velocità TTS per la modalità parlato (0.0 - 2.0, default 1.0)
  final double ttsSpeed;

  /// ID del modello Whisper selezionato ('tiny', 'small', 'medium')
  final String selectedWhisperModelId;

  const AppSettings({
    this.showTranscription = true,
    this.silenceSensitivity = 0.03,
    this.lastSourceLanguageCode = 'auto',
    this.lastTargetLanguageCode = 'eng_Latn',
    this.lastMode = 'text',
    this.ttsSpeed = 1.0,
    this.selectedWhisperModelId = 'small',
  });

  /// Crea una copia con i campi modificati
  AppSettings copyWith({
    bool? showTranscription,
    double? silenceSensitivity,
    String? lastSourceLanguageCode,
    String? lastTargetLanguageCode,
    String? lastMode,
    double? ttsSpeed,
    String? selectedWhisperModelId,
  }) =>
      AppSettings(
        showTranscription: showTranscription ?? this.showTranscription,
        silenceSensitivity: silenceSensitivity ?? this.silenceSensitivity,
        lastSourceLanguageCode:
            lastSourceLanguageCode ?? this.lastSourceLanguageCode,
        lastTargetLanguageCode:
            lastTargetLanguageCode ?? this.lastTargetLanguageCode,
        lastMode: lastMode ?? this.lastMode,
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        selectedWhisperModelId:
            selectedWhisperModelId ?? this.selectedWhisperModelId,
      );

  /// Serializza in Map per SharedPreferences
  Map<String, dynamic> toMap() => {
        'showTranscription': showTranscription,
        'silenceSensitivity': silenceSensitivity,
        'lastSourceLanguageCode': lastSourceLanguageCode,
        'lastTargetLanguageCode': lastTargetLanguageCode,
        'lastMode': lastMode,
        'ttsSpeed': ttsSpeed,
        'selectedWhisperModelId': selectedWhisperModelId,
      };

  /// Deserializza da Map
  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        showTranscription: map['showTranscription'] as bool? ?? true,
        silenceSensitivity: map['silenceSensitivity'] as double? ?? 0.03,
        lastSourceLanguageCode:
            map['lastSourceLanguageCode'] as String? ?? 'auto',
        lastTargetLanguageCode:
            map['lastTargetLanguageCode'] as String? ?? 'eng_Latn',
        lastMode: map['lastMode'] as String? ?? 'text',
        ttsSpeed: map['ttsSpeed'] as double? ?? 1.0,
        selectedWhisperModelId:
            map['selectedWhisperModelId'] as String? ?? 'small',
      );

  @override
  String toString() => 'AppSettings('
      'showTranscr: $showTranscription, '
      'sensitivity: $silenceSensitivity, '
      'src: $lastSourceLanguageCode, '
      'tgt: $lastTargetLanguageCode, '
      'mode: $lastMode, '
      'ttsSpeed: $ttsSpeed, '
      'whisper: $selectedWhisperModelId)';
}
