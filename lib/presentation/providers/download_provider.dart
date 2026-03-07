/// Provider per la gestione del download dei modelli.
/// Coordina il download di tutti i modelli con progresso e stato.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_translate/core/constants/app_constants.dart';
import 'package:voice_translate/core/constants/model_config.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/data/services/download_service.dart';
import 'package:voice_translate/domain/entities/download_state.dart';
import 'package:voice_translate/presentation/providers/app_providers.dart';

/// Tag per i log di questo modulo
const String _tag = 'DownloadProvider';

/// Provider per lo stato globale dei download
final downloadStateProvider =
    StateNotifierProvider<DownloadStateNotifier, AllDownloadsState>((ref) {
  final downloadService = ref.watch(downloadServiceProvider);
  return DownloadStateNotifier(downloadService);
});

/// Notifier per la gestione dello stato dei download
class DownloadStateNotifier extends StateNotifier<AllDownloadsState> {
  final DownloadService _downloadService;

  /// Lista corrente di modelli da gestire (dipende dal modello Whisper scelto)
  List<ModelFileConfig> _requiredModels = kModelFiles;

  DownloadStateNotifier(this._downloadService)
      : super(const AllDownloadsState()) {
    _initModelStates(_requiredModels);
  }

  /// Inizializza gli stati per ogni modello
  void _initModelStates(List<ModelFileConfig> models) {
    AppLogger.info(_tag, 'Inizializzazione stati download per ${models.length} modelli');
    final modelStates = <ModelDownloadState>[];
    for (var i = 0; i < models.length; i++) {
      modelStates.add(ModelDownloadState(
        modelIndex: i,
        displayName: models[i].displayName,
        totalBytes: models[i].expectedSizeBytes,
      ));
    }
    state = state.copyWith(
      models: modelStates,
      allCompleted: false,
      globalError: null,
    );
  }

  /// Verifica lo spazio disponibile e lo stato dei modelli
  Future<void> checkInitialState({String whisperModelId = kDefaultWhisperModelId}) async {
    AppLogger.info(_tag, 'Verifica stato iniziale download...');

    // Aggiorna la lista dei modelli richiesti in base al modello Whisper scelto
    _requiredModels = getRequiredModelFiles(whisperModelId: whisperModelId);
    _initModelStates(_requiredModels);

    // Verifica spazio su disco
    final availableSpace = await _downloadService.getAvailableDiskSpace();
    state = state.copyWith(
      availableDiskSpace: availableSpace,
      globalError: null,
    );

    if (availableSpace < kMinDiskSpaceBytes) {
      state = state.copyWith(
        globalError:
            'Spazio su disco insufficiente. Servono almeno 6 GB liberi. '
            'Disponibili: ${state.availableSpaceFormatted}',
      );
      AppLogger.warning(_tag, 'Spazio insufficiente: $availableSpace bytes');
      return;
    }

    // Verifica quali modelli sono gia' scaricati
    final updatedModels = <ModelDownloadState>[];
    bool allCompleted = true;

    for (var i = 0; i < _requiredModels.length; i++) {
      final isDownloaded =
          await _downloadService.isModelDownloaded(_requiredModels[i]);
      if (isDownloaded) {
        updatedModels.add(state.models[i].copyWith(
          status: DownloadStatus.completed,
          downloadedBytes: _requiredModels[i].expectedSizeBytes,
        ));
      } else {
        allCompleted = false;
        updatedModels.add(state.models[i]);
      }
    }

    state = state.copyWith(
      models: updatedModels,
      allCompleted: allCompleted,
    );

    AppLogger.info(_tag,
        'Stato iniziale: ${state.completedCount}/${_requiredModels.length} modelli pronti');
  }

  /// Avvia il download di tutti i modelli mancanti
  Future<void> startAllDownloads() async {
    AppLogger.info(_tag, 'Avvio download di tutti i modelli mancanti...');

    // Verifica spazio prima di iniziare
    if (state.globalError != null) {
      AppLogger.warning(_tag, 'Download bloccato: ${state.globalError}');
      return;
    }

    for (var i = 0; i < _requiredModels.length; i++) {
      if (state.models[i].status == DownloadStatus.completed) {
        AppLogger.debug(_tag, 'Modello $i gia\' scaricato, salto');
        continue;
      }
      await _downloadSingleModel(i);
    }

    // Verifica completamento
    final allDone = state.models.every(
        (m) => m.status == DownloadStatus.completed);
    state = state.copyWith(allCompleted: allDone);

    if (allDone) {
      AppLogger.info(_tag, 'Tutti i modelli scaricati con successo!');
    }
  }

  /// Scarica un singolo modello
  Future<void> _downloadSingleModel(int index) async {
    final config = _requiredModels[index];
    AppLogger.info(_tag, 'Download modello $index: ${config.displayName}');

    try {
      await _downloadService.downloadModel(
        modelIndex: index,
        config: config,
        onProgress: (modelIndex, downloaded, total, speed) {
          _updateModelState(modelIndex, (current) => current.copyWith(
            downloadedBytes: downloaded,
            totalBytes: total,
            speedBytesPerSec: speed,
            status: DownloadStatus.downloading,
          ));
        },
        onStatus: (modelIndex, status, errorMsg) {
          _updateModelState(modelIndex, (current) => current.copyWith(
            status: status,
            errorMessage: errorMsg,
          ));
        },
      );
    } catch (e) {
      AppLogger.error(_tag, 'Errore download modello $index', e);
      _updateModelState(index, (current) => current.copyWith(
        status: DownloadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Riprova il download di un singolo modello
  Future<void> retryDownload(int index) async {
    AppLogger.info(_tag, 'Riprova download modello $index');
    _updateModelState(index, (current) => current.copyWith(
      status: DownloadStatus.pending,
      errorMessage: null,
      retryCount: current.retryCount + 1,
    ));
    await _downloadSingleModel(index);
  }

  /// Mette in pausa un download
  void pauseDownload(int index) {
    AppLogger.info(_tag, 'Pausa download modello $index');
    _downloadService.pauseDownload(index);
  }

  /// Annulla tutti i download
  void cancelAllDownloads() {
    AppLogger.info(_tag, 'Annullamento tutti i download');
    _downloadService.cancelAllDownloads();
  }

  /// Ri-scarica un modello specifico (eliminandolo prima)
  Future<void> redownloadModel(int index) async {
    AppLogger.info(_tag, 'Ri-scaricamento modello $index');
    await _downloadService.deleteModel(_requiredModels[index]);
    _updateModelState(index, (current) => ModelDownloadState(
      modelIndex: index,
      displayName: _requiredModels[index].displayName,
      totalBytes: _requiredModels[index].expectedSizeBytes,
    ));
    await _downloadSingleModel(index);
  }

  Future<void> redownloadByConfig(ModelFileConfig config) async {
    final trackedIndex = _requiredModels.indexWhere(
      (model) =>
          model.fileName == config.fileName &&
          model.subFolder == config.subFolder,
    );

    if (trackedIndex != -1) {
      await redownloadModel(trackedIndex);
      return;
    }

    final transientIndex = -DateTime.now().microsecondsSinceEpoch;
    await _downloadService.deleteModel(config);
    await _downloadService.downloadModel(
      modelIndex: transientIndex,
      config: config,
      onProgress: (
        modelIndex,
        downloadedBytes,
        totalBytes,
        speedBytesPerSec,
      ) {},
      onStatus: (modelIndex, status, errorMessage) {},
    );
  }

  /// Aggiorna lo stato di un singolo modello
  void _updateModelState(
      int index, ModelDownloadState Function(ModelDownloadState) updater) {
    final updatedModels = List<ModelDownloadState>.from(state.models);
    if (index < updatedModels.length) {
      updatedModels[index] = updater(updatedModels[index]);
      final allCompleted = updatedModels.isNotEmpty &&
          updatedModels.every((model) => model.status == DownloadStatus.completed);
      state = state.copyWith(
        models: updatedModels,
        allCompleted: allCompleted,
      );
    }
  }
}
