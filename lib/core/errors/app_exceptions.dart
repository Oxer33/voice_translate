/// Eccezioni personalizzate dell'applicazione VoiceTranslate.
/// Ogni tipo di errore ha la sua classe per gestione granulare.
library;

/// Eccezione base dell'app
class AppException implements Exception {
  /// Messaggio di errore leggibile
  final String message;

  /// Codice di errore (opzionale)
  final String? code;

  /// Errore originale (opzionale)
  final Object? originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException($code): $message';
}

/// Errore durante il download dei modelli
class ModelDownloadException extends AppException {
  /// Nome del modello che ha fallito
  final String modelName;

  /// Byte scaricati prima dell'errore
  final int downloadedBytes;

  const ModelDownloadException(
    super.message, {
    required this.modelName,
    this.downloadedBytes = 0,
    super.code,
    super.originalError,
  });

  @override
  String toString() =>
      'ModelDownloadException($modelName): $message [scaricati: $downloadedBytes bytes]';
}

/// Errore di spazio su disco insufficiente
class InsufficientStorageException extends AppException {
  /// Spazio richiesto in byte
  final int requiredBytes;

  /// Spazio disponibile in byte
  final int availableBytes;

  const InsufficientStorageException({
    required this.requiredBytes,
    required this.availableBytes,
  }) : super(
          'Spazio su disco insufficiente. '
          'Richiesti: ${requiredBytes ~/ (1024 * 1024)} MB, '
          'Disponibili: ${availableBytes ~/ (1024 * 1024)} MB',
        );
}

/// Errore di integrità del file (checksum non valido)
class ChecksumException extends AppException {
  final String fileName;
  final String expectedHash;
  final String actualHash;

  const ChecksumException({
    required this.fileName,
    required this.expectedHash,
    required this.actualHash,
  }) : super('Checksum non valido per $fileName');
}

/// Errore durante la trascrizione audio
class TranscriptionException extends AppException {
  const TranscriptionException(super.message, {super.originalError});
}

/// Errore durante la correzione del testo
class CorrectionException extends AppException {
  const CorrectionException(super.message, {super.originalError});
}

/// Errore durante la traduzione
class TranslationException extends AppException {
  const TranslationException(super.message, {super.originalError});
}

/// Errore di caricamento del modello in memoria
class ModelLoadException extends AppException {
  final String modelName;

  const ModelLoadException(
    super.message, {
    required this.modelName,
    super.originalError,
  });
}

/// Errore di memoria insufficiente (OutOfMemory)
class OutOfMemoryException extends AppException {
  const OutOfMemoryException([
    super.message = 'Memoria insufficiente. Prova a chiudere altre app e riavvia.',
  ]);
}

/// Errore di registrazione audio
class AudioRecordingException extends AppException {
  const AudioRecordingException(super.message, {super.originalError});
}

/// Errore di permessi non concessi
class PermissionDeniedException extends AppException {
  final String permissionName;

  const PermissionDeniedException(this.permissionName)
      : super('Permesso "$permissionName" non concesso');
}

/// Errore di rete
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Errore di connessione. Controlla la tua connessione internet.',
  ]);
}
