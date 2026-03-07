/// Stato del download dei modelli.
/// Traccia progresso, velocità e stato di ogni singolo file.
library;

const Object _downloadStateUnset = Object();

/// Stato di un singolo download
enum DownloadStatus {
  /// In attesa di iniziare
  pending,

  /// Download in corso
  downloading,

  /// Download in pausa
  paused,

  /// Verifica integrità (checksum)
  verifying,

  /// Completato con successo
  completed,

  /// Errore durante il download
  error,
}

/// Stato di download di un singolo file modello
class ModelDownloadState {
  /// Indice del modello nella lista kModelFiles
  final int modelIndex;

  /// Nome visualizzato del modello
  final String displayName;

  /// Stato corrente del download
  final DownloadStatus status;

  /// Byte totali del file
  final int totalBytes;

  /// Byte scaricati finora
  final int downloadedBytes;

  /// Velocità corrente in byte/secondo
  final double speedBytesPerSec;

  /// Messaggio di errore (se status == error)
  final String? errorMessage;

  /// Numero di tentativi effettuati
  final int retryCount;

  const ModelDownloadState({
    required this.modelIndex,
    required this.displayName,
    this.status = DownloadStatus.pending,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.speedBytesPerSec = 0,
    this.errorMessage,
    this.retryCount = 0,
  });

  /// Progresso da 0.0 a 1.0
  double get progress =>
      totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  /// Velocità formattata in MB/s
  String get speedFormatted {
    final mbPerSec = speedBytesPerSec / (1024 * 1024);
    return '${mbPerSec.toStringAsFixed(1)} MB/s';
  }

  /// Dimensione scaricata formattata
  String get downloadedFormatted => _formatBytes(downloadedBytes);

  /// Dimensione totale formattata
  String get totalFormatted => _formatBytes(totalBytes);

  /// Formatta i byte in formato leggibile
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Crea una copia con i campi modificati
  ModelDownloadState copyWith({
    DownloadStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    double? speedBytesPerSec,
    Object? errorMessage = _downloadStateUnset,
    int? retryCount,
  }) =>
      ModelDownloadState(
        modelIndex: modelIndex,
        displayName: displayName,
        status: status ?? this.status,
        totalBytes: totalBytes ?? this.totalBytes,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
        errorMessage: identical(errorMessage, _downloadStateUnset)
            ? this.errorMessage
            : errorMessage as String?,
        retryCount: retryCount ?? this.retryCount,
      );

  @override
  String toString() =>
      'ModelDownloadState($displayName: $status, ${(progress * 100).toStringAsFixed(1)}%)';
}

/// Stato globale del download di tutti i modelli
class AllDownloadsState {
  /// Lista degli stati di download per ogni modello
  final List<ModelDownloadState> models;

  /// Spazio disponibile su disco in byte
  final int availableDiskSpace;

  /// Se tutti i modelli sono stati scaricati con successo
  final bool allCompleted;

  /// Se c'è un errore globale (es. spazio insufficiente)
  final String? globalError;

  const AllDownloadsState({
    this.models = const [],
    this.availableDiskSpace = 0,
    this.allCompleted = false,
    this.globalError,
  });

  /// Progresso totale da 0.0 a 1.0
  double get totalProgress {
    if (models.isEmpty) return 0.0;
    final totalBytes = models.fold<int>(0, (sum, m) => sum + m.totalBytes);
    final downloadedBytes =
        models.fold<int>(0, (sum, m) => sum + m.downloadedBytes);
    return totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
  }

  /// Numero di modelli completati
  int get completedCount =>
      models.where((m) => m.status == DownloadStatus.completed).length;

  /// Spazio disponibile formattato
  String get availableSpaceFormatted =>
      ModelDownloadState._formatBytes(availableDiskSpace);

  /// Crea una copia con i campi modificati
  AllDownloadsState copyWith({
    List<ModelDownloadState>? models,
    int? availableDiskSpace,
    bool? allCompleted,
    Object? globalError = _downloadStateUnset,
  }) =>
      AllDownloadsState(
        models: models ?? this.models,
        availableDiskSpace: availableDiskSpace ?? this.availableDiskSpace,
        allCompleted: allCompleted ?? this.allCompleted,
        globalError: identical(globalError, _downloadStateUnset)
            ? this.globalError
            : globalError as String?,
      );
}
