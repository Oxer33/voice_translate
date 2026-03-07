/// Servizio per il download dei modelli ML da Hugging Face.
/// Resume robusto byte-level: se il download si interrompe,
/// riprende esattamente dal byte dove era rimasto.
/// Usa streaming manuale con IOSink per non perdere mai dati.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:voice_translate/core/constants/app_constants.dart';
import 'package:voice_translate/core/constants/model_config.dart';
import 'package:voice_translate/core/errors/app_exceptions.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/domain/entities/download_state.dart';

/// Tag per i log di questo modulo
const String _tag = 'DownloadService';

/// Callback per aggiornamento progresso download
typedef DownloadProgressCallback = void Function(
  int modelIndex,
  int downloadedBytes,
  int totalBytes,
  double speedBytesPerSec,
);

/// Callback per cambio stato download
typedef DownloadStatusCallback = void Function(
  int modelIndex,
  DownloadStatus status,
  String? errorMessage,
);

/// Servizio per scaricare i modelli con resume robusto byte-level
class DownloadService {
  /// Client HTTP Dio per i download
  late final Dio _dio;

  /// Token di cancellazione per i download in corso
  final Map<int, CancelToken> _cancelTokens = {};

  /// Flag di pausa per ogni download
  final Map<int, bool> _pauseFlags = {};

  DownloadService() {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: kDownloadConnectTimeoutSec),
      // NESSUN receiveTimeout: lo streaming puo' durare ore per file grandi
      // Il timeout per singolo chunk e' gestito dal server
      receiveTimeout: const Duration(minutes: 30),
      headers: {
        'User-Agent': 'VoiceTranslate/2.0',
        'Accept': '*/*',
      },
      followRedirects: true,
      maxRedirects: 10,
    ));
    AppLogger.info(_tag, 'DownloadService inizializzato (resume robusto v2)');
  }

  /// Ottiene la cartella base per i modelli
  Future<String> getModelsBasePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(appDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
      AppLogger.info(_tag, 'Cartella modelli creata: ${modelsDir.path}');
    }
    return modelsDir.path;
  }

  /// Ottiene il percorso completo di un file modello
  Future<String> getModelFilePath(ModelFileConfig config) async {
    final basePath = await getModelsBasePath();
    final subDir = Directory(p.join(basePath, config.subFolder));
    if (!await subDir.exists()) {
      await subDir.create(recursive: true);
    }
    return p.join(subDir.path, config.fileName);
  }

  /// Verifica se un modello e' gia' stato scaricato completamente
  Future<bool> isModelDownloaded(ModelFileConfig config) async {
    final filePath = await getModelFilePath(config);
    final file = File(filePath);
    if (!await file.exists()) {
      AppLogger.debug(_tag, 'File non trovato: $filePath');
      return false;
    }

    final fileSize = await file.length();

    if (config.expectedSizeBytes <= 64 * 1024) {
      final isValid = await _isSmallMetadataFileValid(file, fileSize);
      AppLogger.debug(
        _tag,
        'File metadata ${config.fileName}: $fileSize bytes, valido: $isValid',
      );
      return isValid;
    }

    // Controlla che la dimensione sia ragionevole (almeno 90% della dimensione attesa)
    final minExpectedSize = (config.expectedSizeBytes * 0.9).toInt();
    final isValid = fileSize >= minExpectedSize;
    AppLogger.debug(_tag,
        'File ${config.fileName}: $fileSize bytes (attesi ~${config.expectedSizeBytes}), valido: $isValid');
    return isValid;
  }

  /// Verifica se tutti i modelli OBBLIGATORI per un dato modello Whisper
  /// sono scaricati. Questo include:
  /// - NLLB-200 (sempre obbligatori)
  /// - Il modello Whisper selezionato (passato da whisperModelId)
  Future<bool> areAllModelsDownloaded({
    String whisperModelId = kDefaultWhisperModelId,
  }) async {
    AppLogger.info(
        _tag, 'Verifica completezza modelli per whisper=$whisperModelId...');

    final requiredModels = getRequiredModelFiles(whisperModelId: whisperModelId);

    for (final config in requiredModels) {
      if (!await isModelDownloaded(config)) {
        AppLogger.info(_tag, 'Modello mancante: ${config.displayName}');
        return false;
      }
    }
    AppLogger.info(_tag, 'Tutti i modelli richiesti sono presenti');
    return true;
  }

  Future<bool> _isSmallMetadataFileValid(File file, int fileSize) async {
    if (fileSize < 64) {
      return false;
    }

    try {
      final previewBytes = await file.openRead(0, 1024).fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      final preview = utf8.decode(previewBytes, allowMalformed: true).trimLeft();
      return preview.startsWith('{') || preview.startsWith('[');
    } catch (e) {
      AppLogger.warning(_tag, 'Impossibile validare metadata file ${file.path}: $e');
      return false;
    }
  }

  /// Verifica lo spazio disponibile su disco.
  /// Su Android usa stat() sul filesystem che funziona correttamente.
  Future<int> getAvailableDiskSpace() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final stat = await FileStat.stat(appDir.path);
      if (stat.type != FileSystemEntityType.notFound) {
        // Su Android, usiamo stat sul path per verificare che esista,
        // poi usiamo il fallback generoso perché Dart non espone statvfs.
        // Il check reale avviene prima del download tramite la dimensione
        // dei file attesi vs spazio stimato.
        AppLogger.info(_tag, 'Directory modelli accessibile: ${appDir.path}');
      }
    } catch (e) {
      AppLogger.error(_tag, 'Errore verifica directory modelli', e);
    }
    // Dart non espone statvfs/StatFs nativamente.
    // Il fallback generoso evita falsi blocchi; il download fallirà
    // con errore IO chiaro se lo spazio è effettivamente insufficiente.
    return 10 * 1024 * 1024 * 1024; // 10 GB fallback
  }

  /// Scarica un singolo modello con resume ROBUSTO byte-level.
  /// Usa streaming manuale: apre un IOSink in append e scrive chunk per chunk.
  /// Se il download si interrompe, il file .tmp contiene esattamente
  /// i byte scaricati e il resume riparte da li'.
  Future<void> downloadModel({
    required int modelIndex,
    required ModelFileConfig config,
    required DownloadProgressCallback onProgress,
    required DownloadStatusCallback onStatus,
  }) async {
    AppLogger.info(
        _tag, 'Inizio download: ${config.displayName} da ${config.url}');

    final filePath = await getModelFilePath(config);
    final file = File(filePath);
    final tempPath = '$filePath.tmp';
    final tempFile = File(tempPath);

    // Cancella il cancel token precedente se esiste
    _cancelTokens[modelIndex]?.cancel();
    var cancelToken = CancelToken();
    _cancelTokens[modelIndex] = cancelToken;
    _pauseFlags[modelIndex] = false;

    int retryCount = 0;

    while (retryCount < kMaxDownloadRetries) {
      IOSink? sink;
      try {
        onStatus(modelIndex, DownloadStatus.downloading, null);

        // Determina quanti byte sono gia' stati scaricati (resume esatto)
        int downloadedBytes = 0;
        if (await tempFile.exists()) {
          downloadedBytes = await tempFile.length();
          AppLogger.info(_tag,
              'RESUME: riprendo da byte $downloadedBytes per ${config.fileName}');
        }

        // Prima richiesta HEAD per ottenere la dimensione totale del file
        int totalBytes = config.expectedSizeBytes;
        try {
          final headResponse = await _dio.head(
            config.url,
            cancelToken: cancelToken,
          );
          final contentLength =
              headResponse.headers.value('content-length');
          if (contentLength != null) {
            totalBytes = int.tryParse(contentLength) ?? config.expectedSizeBytes;
            AppLogger.info(_tag,
                'Dimensione totale server: $totalBytes bytes');
          }
        } catch (e) {
          AppLogger.warning(_tag, 'HEAD fallita, uso dimensione attesa: $e');
        }

        // Se il file e' gia' completo, skip
        if (downloadedBytes >= totalBytes && totalBytes > 0) {
          AppLogger.info(_tag,
              'File gia\' completo ($downloadedBytes >= $totalBytes), rinomino');
          if (await tempFile.exists()) {
            // Se il file finale esiste già, eliminalo prima di rinominare
            if (await file.exists()) {
              await file.delete();
            }
            await tempFile.rename(filePath);
          }
          onStatus(modelIndex, DownloadStatus.completed, null);
          return;
        }

        // Headers per il resume (HTTP Range)
        final headers = <String, dynamic>{};
        if (downloadedBytes > 0) {
          headers['Range'] = 'bytes=$downloadedBytes-';
          AppLogger.info(_tag, 'Range header: bytes=$downloadedBytes-');
        }

        // Richiesta GET con ResponseType.stream per ricevere i dati come stream
        final response = await _dio.get<ResponseBody>(
          config.url,
          cancelToken: cancelToken,
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
          ),
        );

        // Verifica che il server supporti il resume (206 Partial Content)
        final statusCode = response.statusCode ?? 200;
        AppLogger.info(_tag, 'Risposta server: HTTP $statusCode');

        if (statusCode == 200 && downloadedBytes > 0) {
          // Il server non supporta Range, ricominciamo da zero
          AppLogger.warning(_tag,
              'Server non supporta Range, ricominciamo da zero');
          downloadedBytes = 0;
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }

        // Apri il file in modalita' APPEND (aggiunge byte al fondo)
        final fileSink = tempFile.openWrite(mode: FileMode.append);
        sink = fileSink;

        // Variabili per calcolo velocita'
        int lastProgressBytes = downloadedBytes;
        DateTime lastProgressTime = DateTime.now();
        int currentBytes = downloadedBytes;

        // Leggi lo stream chunk per chunk e scrivi su disco
        final stream = response.data?.stream;
        if (stream == null) {
          throw Exception('Stream di risposta null');
        }

        await for (final chunk in stream) {
          // Controlla pausa/cancellazione
          if (_pauseFlags[modelIndex] == true) {
            AppLogger.info(_tag,
                'Pausa richiesta a byte $currentBytes');
            await fileSink.flush();
            await fileSink.close();
            sink = null;
            onStatus(modelIndex, DownloadStatus.paused, null);
            return;
          }

          if (cancelToken.isCancelled) {
            AppLogger.info(_tag, 'Download annullato a byte $currentBytes');
            await fileSink.flush();
            await fileSink.close();
            sink = null;
            onStatus(modelIndex, DownloadStatus.error, 'Download annullato');
            return;
          }

          // Scrivi il chunk su disco IMMEDIATAMENTE
          fileSink.add(chunk);
          currentBytes += chunk.length;

          // Calcola velocita' (aggiorna ogni 500ms)
          final now = DateTime.now();
          final elapsed = now.difference(lastProgressTime).inMilliseconds;
          double speed = 0;
          if (elapsed > 500) {
            speed = (currentBytes - lastProgressBytes) / (elapsed / 1000);
            lastProgressBytes = currentBytes;
            lastProgressTime = now;
          }

          // Notifica progresso
          onProgress(modelIndex, currentBytes, totalBytes, speed);
        }

        // Flush e chiudi il file
        await fileSink.flush();
        await fileSink.close();
        sink = null;

        AppLogger.info(_tag,
            'Stream completato: $currentBytes bytes scritti per ${config.fileName}');

        // Rinomina il file temporaneo nel file finale
        if (await tempFile.exists()) {
          if (await file.exists()) {
            await file.delete();
          }
          await tempFile.rename(filePath);
          AppLogger.info(_tag, 'Download completato: ${config.fileName}');
        }

        // Verifica integrita'
        onStatus(modelIndex, DownloadStatus.verifying, null);
        final finalSize = await file.length();
        AppLogger.info(_tag,
            'Verifica integrita ${config.fileName}: $finalSize bytes (attesi: $totalBytes)');

        // Se il checksum SHA256 e' disponibile, verificalo
        if (config.sha256 != null) {
          final isValid =
              await _verifyChecksum(filePath, config.sha256!);
          if (!isValid) {
            await file.delete();
            throw ChecksumException(
              fileName: config.fileName,
              expectedHash: config.sha256!,
              actualHash: 'non corrispondente',
            );
          }
        }

        final isDownloaded = await isModelDownloaded(config);
        if (!isDownloaded) {
          if (await file.exists()) {
            await file.delete();
          }
          throw ModelDownloadException(
            'Il file scaricato non supera la verifica finale di integrita\'.',
            modelName: config.displayName,
            downloadedBytes: finalSize,
          );
        }

        onStatus(modelIndex, DownloadStatus.completed, null);
        AppLogger.info(
            _tag, 'Modello ${config.displayName} scaricato e verificato!');
        return;
      } on DioException catch (e) {
        // Chiudi il sink se aperto
        try {
          await sink?.flush();
          await sink?.close();
        } catch (_) {}
        sink = null;

        if (e.type == DioExceptionType.cancel) {
          if (_pauseFlags[modelIndex] == true) {
            AppLogger.info(_tag, 'Download in pausa: ${config.fileName}');
            onStatus(modelIndex, DownloadStatus.paused, null);
            return;
          }
          AppLogger.info(_tag, 'Download annullato: ${config.fileName}');
          onStatus(modelIndex, DownloadStatus.error, 'Download annullato');
          return;
        }

        retryCount++;
        // Backoff esponenziale: 2, 4, 8, 16, 32 secondi
        final waitSeconds = min(pow(2, retryCount).toInt(), 60);

        // Salva i byte scaricati finora (il file .tmp e' gia' su disco)
        int savedBytes = 0;
        if (await tempFile.exists()) {
          savedBytes = await tempFile.length();
        }
        AppLogger.warning(_tag,
            'Errore download ${config.fileName} (tentativo $retryCount/$kMaxDownloadRetries), '
            'salvati $savedBytes bytes. Errore: ${e.message}');

        if (retryCount < kMaxDownloadRetries) {
          onStatus(modelIndex, DownloadStatus.error,
              'Errore di rete. Salvati ${_formatBytes(savedBytes)}. '
              'Riprovo tra $waitSeconds s... ($retryCount/$kMaxDownloadRetries)');
          await Future.delayed(Duration(seconds: waitSeconds));
          // Il prossimo ciclo riprende dal file .tmp esistente!
          // Crea un nuovo cancel token per il retry e aggiorna la variabile locale
          cancelToken = CancelToken();
          _cancelTokens[modelIndex] = cancelToken;
        } else {
          onStatus(modelIndex, DownloadStatus.error,
              'Download fallito dopo $kMaxDownloadRetries tentativi. '
              'Salvati ${_formatBytes(savedBytes)}. Riprova piu\' tardi.');
          throw ModelDownloadException(
            'Download fallito: ${e.message}',
            modelName: config.displayName,
            downloadedBytes: savedBytes,
            originalError: e,
          );
        }
      } catch (e) {
        // Chiudi il sink se aperto
        try {
          await sink?.flush();
          await sink?.close();
        } catch (_) {}
        sink = null;

        retryCount++;
        AppLogger.error(_tag, 'Errore inaspettato download', e);
        if (retryCount >= kMaxDownloadRetries) {
          onStatus(modelIndex, DownloadStatus.error, 'Errore: $e');
          rethrow;
        }
        final waitSeconds = min(pow(2, retryCount).toInt(), 60);
        onStatus(modelIndex, DownloadStatus.error,
            'Errore. Riprovo tra $waitSeconds s... ($retryCount/$kMaxDownloadRetries)');
        await Future.delayed(Duration(seconds: waitSeconds));
        cancelToken = CancelToken();
        _cancelTokens[modelIndex] = cancelToken;
      }
    }
  }

  /// Mette in pausa un download specifico
  void pauseDownload(int modelIndex) {
    AppLogger.info(_tag, 'Pausa download modello index: $modelIndex');
    _pauseFlags[modelIndex] = true;
  }

  /// Annulla un download specifico
  void cancelDownload(int modelIndex) {
    AppLogger.info(_tag, 'Annullamento download modello index: $modelIndex');
    _cancelTokens[modelIndex]?.cancel('Annullato dall\'utente');
    _pauseFlags.remove(modelIndex);
  }

  /// Annulla tutti i download in corso
  void cancelAllDownloads() {
    AppLogger.info(_tag, 'Annullamento di tutti i download');
    for (final entry in _cancelTokens.entries) {
      entry.value.cancel('Annullamento globale');
    }
    _cancelTokens.clear();
    _pauseFlags.clear();
  }

  /// Elimina un modello scaricato per ri-scaricarlo
  Future<void> deleteModel(ModelFileConfig config) async {
    final filePath = await getModelFilePath(config);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      AppLogger.info(_tag, 'Modello eliminato: ${config.fileName}');
    }
    final tempFile = File('$filePath.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
      AppLogger.info(_tag, 'File temporaneo eliminato: ${config.fileName}.tmp');
    }
  }

  /// Verifica il checksum SHA256 di un file
  Future<bool> _verifyChecksum(String filePath, String expectedHash) async {
    AppLogger.info(_tag, 'Verifica checksum SHA256 per $filePath...');
    try {
      final file = File(filePath);
      final stream = file.openRead();
      final digest = await sha256.bind(stream).first;
      final actualHash = digest.toString();
      final isValid = actualHash == expectedHash;
      AppLogger.info(_tag,
          'Checksum: atteso=$expectedHash, attuale=$actualHash, valido=$isValid');
      return isValid;
    } catch (e) {
      AppLogger.error(_tag, 'Errore verifica checksum', e);
      return false;
    }
  }

  /// Formatta i byte in formato leggibile
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Rilascia le risorse del servizio
  void dispose() {
    cancelAllDownloads();
    _dio.close();
    AppLogger.info(_tag, 'DownloadService disposed');
  }
}
