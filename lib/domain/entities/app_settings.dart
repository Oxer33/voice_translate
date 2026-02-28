/// Entità per le impostazioni dell'app.
/// Gestisce preferenze utente persistenti.
library;

/// Impostazioni dell'applicazione
class AppSettings {
  /// Se mostrare il testo grezzo STT nella schermata principale
  final bool showRawText;

  /// Se abilitare la correzione Phi-3
  final bool correctionEnabled;

  /// Sensibilità del rilevamento silenzio (0.0 - 1.0)
  final double silenceSensitivity;

  /// Codice NLLB dell'ultima lingua sorgente usata
  final String lastSourceLanguageCode;

  /// Codice NLLB dell'ultima lingua target usata
  final String lastTargetLanguageCode;

  const AppSettings({
    this.showRawText = true,
    this.correctionEnabled = true,
    this.silenceSensitivity = 0.03,
    this.lastSourceLanguageCode = 'auto',
    this.lastTargetLanguageCode = 'eng_Latn',
  });

  /// Crea una copia con i campi modificati
  AppSettings copyWith({
    bool? showRawText,
    bool? correctionEnabled,
    double? silenceSensitivity,
    String? lastSourceLanguageCode,
    String? lastTargetLanguageCode,
  }) =>
      AppSettings(
        showRawText: showRawText ?? this.showRawText,
        correctionEnabled: correctionEnabled ?? this.correctionEnabled,
        silenceSensitivity: silenceSensitivity ?? this.silenceSensitivity,
        lastSourceLanguageCode:
            lastSourceLanguageCode ?? this.lastSourceLanguageCode,
        lastTargetLanguageCode:
            lastTargetLanguageCode ?? this.lastTargetLanguageCode,
      );

  /// Serializza in Map per SharedPreferences
  Map<String, dynamic> toMap() => {
        'showRawText': showRawText,
        'correctionEnabled': correctionEnabled,
        'silenceSensitivity': silenceSensitivity,
        'lastSourceLanguageCode': lastSourceLanguageCode,
        'lastTargetLanguageCode': lastTargetLanguageCode,
      };

  /// Deserializza da Map
  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        showRawText: map['showRawText'] as bool? ?? true,
        correctionEnabled: map['correctionEnabled'] as bool? ?? true,
        silenceSensitivity: map['silenceSensitivity'] as double? ?? 0.03,
        lastSourceLanguageCode:
            map['lastSourceLanguageCode'] as String? ?? 'auto',
        lastTargetLanguageCode:
            map['lastTargetLanguageCode'] as String? ?? 'eng_Latn',
      );

  @override
  String toString() => 'AppSettings('
      'showRaw: $showRawText, '
      'correction: $correctionEnabled, '
      'sensitivity: $silenceSensitivity, '
      'src: $lastSourceLanguageCode, '
      'tgt: $lastTargetLanguageCode)';
}
