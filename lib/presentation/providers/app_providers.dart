/// Provider centrali dell'applicazione VoiceTranslate.
/// Gestisce l'inizializzazione e l'accesso ai servizi e repository.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_translate/data/repositories/history_repository.dart';
import 'package:voice_translate/data/repositories/settings_repository.dart';
import 'package:voice_translate/data/services/audio_service.dart';
import 'package:voice_translate/data/services/download_service.dart';
import 'package:voice_translate/data/services/tts_service.dart';
import 'package:voice_translate/domain/entities/app_settings.dart';

/// Provider per il servizio di download dei modelli
final downloadServiceProvider = Provider<DownloadService>((ref) {
  final service = DownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider per il servizio audio
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider per il servizio TTS (Text-to-Speech)
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider per il repository della cronologia
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});

/// Provider per il repository delle impostazioni
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Provider per le impostazioni correnti dell'app (reattivo)
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return AppSettingsNotifier(repo);
});

/// Notifier per le impostazioni dell'app
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  AppSettingsNotifier(this._repo) : super(const AppSettings());

  /// Carica le impostazioni dal repository
  Future<void> load() async {
    await _repo.init();
    state = _repo.load();
  }

  /// Aggiorna le impostazioni
  Future<void> update({
    bool? showTranscription,
    double? silenceSensitivity,
    String? lastSourceLanguageCode,
    String? lastTargetLanguageCode,
    String? lastMode,
    double? ttsSpeed,
    String? selectedWhisperModelId,
  }) async {
    state = await _repo.update(
      showTranscription: showTranscription,
      silenceSensitivity: silenceSensitivity,
      lastSourceLanguageCode: lastSourceLanguageCode,
      lastTargetLanguageCode: lastTargetLanguageCode,
      lastMode: lastMode,
      ttsSpeed: ttsSpeed,
      selectedWhisperModelId: selectedWhisperModelId,
    );
  }
}

/// Provider per sapere se tutti i modelli sono pronti
final modelsReadyProvider = FutureProvider<bool>((ref) async {
  final downloadService = ref.watch(downloadServiceProvider);
  return await downloadService.areAllModelsDownloaded();
});
