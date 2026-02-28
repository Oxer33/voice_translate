/// Servizio per il download dei modelli ML da Hugging Face.
/// Supporta resume, retry con backoff esponenziale e verifica SHA256.
library;

import 'dart:async';
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

/// Servizio per scaricare i modelli con supporto resume e retry
class DownloadService {
  /// Client HTTP Dio per i download
  late final Dio _dio;

  /// Token di cancellazione per i download in corso
  final Map<int, CancelToken> _cancelTokens = {};

  /// Flag di pausa per ogni download
  final Map<int, bool> _pauseFlags = {};

  DownloadService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
      headers: {
        'User-Agent': 'VoiceTranslate/1.0',
      },
    ));
    AppLogger.info(_tag, 'DownloadService inizializzato');
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
    // Controlla che la dimensione sia ragionevole (almeno 90% della dimensione attesa)
    final minExpectedSize = (config.expectedSizeBytes * 0.9).toInt();
    final isValid = fileSize >= minExpectedSize;
    AppLogger.debug(
        _tag, 'File ${config.fileName}: $fileSize bytes (attesi ~${config.expectedSizeBytes}), valido: $isValid');
    return isValid;
  }

  /// Verifica se tutti i modelli sono stati scaricati
  Future<bool> areAllModelsDownloaded() async {
    AppLogger.info(_tag, 'Verifica completezza modelli...');
    for (final config in kModelFiles) {
      if (!await isModelDownloaded(config)) {
        AppLogger.info(_tag, 'Modello mancante: ${config.displayName}');
        return false;
      }
    }
    AppLogger.info(_tag, 'Tutti i modelli sono presenti');
    return true;
  }

  /// Verifica lo spazio disponibile su disco
  Future<int> getAvailableDiskSpace() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // Su Android usiamo 'df' per ottenere lo spazio libero
      final result = await Process.run('df', [appDir.path]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            // Il quarto campo e' lo spazio disponibile in blocchi da 1KB
            final availableKB = int.tryParse(parts[3]) ?? 0;
            final availableBytes = availableKB * 1024;
            AppLogger.info(
                _tag, 'Spazio disponibile: ${availableBytes ~/ (1024 * 1024)} MB');
            return availableBytes;
          }
        }
      }
    } catch (e) {
      AppLogger.error(_tag, 'Errore lettura spazio disco', e);
    }
    // Fallback: restituisce un valore alto per non bloccare
    AppLogger.warning(_tag, 'Impossibile determinare spazio disco, uso fallback');
    return 10 * 1024 * 1024 * 1024; // 10 GB fallback
  }

  /// Scarica un singolo modello con supporto resume e retry
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
    final cancelToken = CancelToken();
    _cancelTokens[modelIndex] = cancelToken;
    _pauseFlags[modelIndex] = false;

    int retryCount = 0;

    while (retryCount < kMaxDownloadRetries) {
      try {
        onStatus(modelIndex, DownloadStatus.downloading, null);

        // Determina quanti byte sono gia' stati scaricati (per resume)
        int downloadedBytes = 0;
        if (await tempFile.exists()) {
          downloadedBytes = await tempFile.length();
          AppLogger.info(_tag,
              'Resume download da $downloadedBytes bytes per ${config.fileName}');
        }

        // Headers per il resume (HTTP Range)
        final headers = <String, dynamic>{};
        if (downloadedBytes > 0) {
          headers['Range'] = 'bytes=$downloadedBytes-';
        }

        // Variabili per calcolo velocita'
        int lastBytes = downloadedBytes;
        DateTime lastTime = DateTime.now();

        // Esegue il download
        await _dio.download(
          config.url,
          tempPath,
          cancelToken: cancelToken,
          deleteOnError: false,
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
          ),
          onReceiveProgress: (received, total) {
            // Se in pausa, annulla il download
            if (_pauseFlags[modelIndex] == true) {
              cancelToken.cancel('Pausa richiesta');
              return;
            }

            // Calcola i byte totali considerando il resume
            final actualReceived = downloadedBytes + received;
            final actualTotal =
                total > 0 ? downloadedBytes + total : config.expectedSizeBytes;

            // Calcola velocita' (aggiorna ogni 500ms)
            final now = DateTime.now();
            final elapsed = now.difference(lastTime).inMilliseconds;
            double speed = 0;
            if (elapsed > 500) {
              speed = (actualReceived - lastBytes) / (elapsed / 1000);
              lastBytes = actualReceived;
              lastTime = now;
            }

            onProgress(modelIndex, actualReceived, actualTotal, speed);
          },
        );

        // Download completato - rinomina il file temporaneo
        if (await tempFile.exists()) {
          await tempFile.rename(filePath);
          AppLogger.info(
              _tag, 'Download completato: ${config.fileName}');
        }

        // Verifica integrita' (se il file e' abbastanza grande)
        onStatus(modelIndex, DownloadStatus.verifying, null);
        final finalSize = await file.length();
        AppLogger.info(
            _tag, 'Verifica integrita ${config.fileName}: $finalSize bytes');

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

        onStatus(modelIndex, DownloadStatus.completed, null);
        AppLogger.info(
            _tag, 'Modello ${config.displayName} scaricato e verificato');
        return;
      } on DioException catch (e) {
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
        final waitSeconds = pow(2, retryCount).toInt();
        AppLogger.warning(_tag,
            'Errore download ${config.fileName} (tentativo $retryCount/$kMaxDownloadRetries): $e');
        AppLogger.info(_tag, 'Riprovo tra $waitSeconds secondi...');

        if (retryCount < kMaxDownloadRetries) {
          onStatus(modelIndex, DownloadStatus.error,
              'Errore di rete. Riprovo tra $waitSeconds secondi... (tentativo $retryCount/$kMaxDownloadRetries)');
          await Future.delayed(Duration(seconds: waitSeconds));
        } else {
          onStatus(modelIndex, DownloadStatus.error,
              'Download fallito dopo $kMaxDownloadRetries tentativi: ${e.message}');
          throw ModelDownloadException(
            'Download fallito: ${e.message}',
            modelName: config.displayName,
            downloadedBytes:
                await tempFile.exists() ? await tempFile.length() : 0,
            originalError: e,
          );
        }
      } catch (e) {
        retryCount++;
        AppLogger.error(_tag, 'Errore inaspettato download', e);
        if (retryCount >= kMaxDownloadRetries) {
          onStatus(modelIndex, DownloadStatus.error, 'Errore: $e');
          rethrow;
        }
        final waitSeconds = pow(2, retryCount).toInt();
        await Future.delayed(Duration(seconds: waitSeconds));
      }
    }
  }

  /// Mette in pausa un download specifico
  void pauseDownload(int modelIndex) {
    AppLogger.info(_tag, 'Pausa download modello index: $modelIndex');
    _pauseFlags[modelIndex] = true;
    _cancelTokens[modelIndex]?.cancel('Pausa richiesta');
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
    for (final token in _cancelTokens.values) {
      token.cancel('Annullamento globale');
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
    // Elimina anche il file temporaneo se esiste
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

  /// Rilascia le risorse del servizio
  void dispose() {
    cancelAllDownloads();
    _dio.close();
    AppLogger.info(_tag, 'DownloadService disposed');
  }
}
