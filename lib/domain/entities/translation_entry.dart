/// Entità che rappresenta una voce nella cronologia delle traduzioni.
/// Contiene tutti i dati di una singola sessione di trascrizione/traduzione.
library;

/// Voce della cronologia traduzioni
class TranslationEntry {
  /// ID univoco della voce
  final String id;

  /// Data e ora della traduzione
  final DateTime timestamp;

  /// Codice NLLB della lingua sorgente
  final String sourceLanguageCode;

  /// Codice NLLB della lingua target
  final String targetLanguageCode;

  /// Nome italiano della lingua sorgente
  final String sourceLanguageName;

  /// Nome italiano della lingua target
  final String targetLanguageName;

  /// Testo trascritto grezzo (output Whisper)
  final String rawText;

  /// Testo tradotto (output NLLB)
  final String translatedText;

  const TranslationEntry({
    required this.id,
    required this.timestamp,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.sourceLanguageName,
    required this.targetLanguageName,
    required this.rawText,
    required this.translatedText,
  });

  /// Converte in Map per serializzazione Hive
  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'sourceLanguageCode': sourceLanguageCode,
        'targetLanguageCode': targetLanguageCode,
        'sourceLanguageName': sourceLanguageName,
        'targetLanguageName': targetLanguageName,
        'rawText': rawText,
        'translatedText': translatedText,
      };

  /// Crea un'istanza da Map (deserializzazione Hive)
  factory TranslationEntry.fromMap(Map<dynamic, dynamic> map) =>
      TranslationEntry(
        id: (map['id'] as String?) ?? '',
        timestamp: DateTime.tryParse((map['timestamp'] as String?) ?? '') ?? DateTime.now(),
        sourceLanguageCode: (map['sourceLanguageCode'] as String?) ?? '',
        targetLanguageCode: (map['targetLanguageCode'] as String?) ?? '',
        sourceLanguageName: (map['sourceLanguageName'] as String?) ?? '',
        targetLanguageName: (map['targetLanguageName'] as String?) ?? '',
        rawText: (map['rawText'] as String?) ?? '',
        translatedText: (map['translatedText'] as String?) ?? '',
      );

  @override
  String toString() =>
      'TranslationEntry(id: $id, $sourceLanguageName -> $targetLanguageName)';
}
