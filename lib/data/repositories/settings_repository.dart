/// Repository per le impostazioni dell'app.
/// Usa SharedPreferences per la persistenza delle preferenze utente.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/domain/entities/app_settings.dart';

/// Tag per i log di questo modulo
const String _tag = 'SettingsRepository';

// --- Chiavi SharedPreferences ---
const String _keyShowTranscription = 'settings_show_transcription';
const String _keySilenceSensitivity = 'settings_silence_sensitivity';
const String _keyLastSourceLang = 'settings_last_source_lang';
const String _keyLastTargetLang = 'settings_last_target_lang';
const String _keyLastMode = 'settings_last_mode';
const String _keyTtsSpeed = 'settings_tts_speed';
const String _keySelectedWhisperModel = 'settings_selected_whisper_model';

/// Repository per la gestione delle impostazioni dell'app
class SettingsRepository {
  /// Istanza SharedPreferences
  SharedPreferences? _prefs;

  /// Inizializza il repository
  Future<void> init() async {
    AppLogger.info(_tag, 'Inizializzazione SettingsRepository...');
    _prefs = await SharedPreferences.getInstance();
    AppLogger.info(_tag, 'SettingsRepository inizializzato');
  }

  /// Carica le impostazioni salvate
  AppSettings load() {
    _ensureInit();
    AppLogger.debug(_tag, 'Caricamento impostazioni...');

    final settings = AppSettings(
      showTranscription: _prefs!.getBool(_keyShowTranscription) ?? true,
      silenceSensitivity:
          _prefs!.getDouble(_keySilenceSensitivity) ?? 0.03,
      lastSourceLanguageCode:
          _prefs!.getString(_keyLastSourceLang) ?? 'auto',
      lastTargetLanguageCode:
          _prefs!.getString(_keyLastTargetLang) ?? 'eng_Latn',
      lastMode: _prefs!.getString(_keyLastMode) ?? 'text',
      ttsSpeed: _prefs!.getDouble(_keyTtsSpeed) ?? 1.0,
      selectedWhisperModelId:
          _prefs!.getString(_keySelectedWhisperModel) ?? 'small',
    );

    AppLogger.debug(_tag, 'Impostazioni caricate: $settings');
    return settings;
  }

  /// Salva le impostazioni
  Future<void> save(AppSettings settings) async {
    _ensureInit();
    AppLogger.info(_tag, 'Salvataggio impostazioni: $settings');

    await Future.wait([
      _prefs!.setBool(_keyShowTranscription, settings.showTranscription),
      _prefs!.setDouble(_keySilenceSensitivity, settings.silenceSensitivity),
      _prefs!.setString(_keyLastSourceLang, settings.lastSourceLanguageCode),
      _prefs!.setString(_keyLastTargetLang, settings.lastTargetLanguageCode),
      _prefs!.setString(_keyLastMode, settings.lastMode),
      _prefs!.setDouble(_keyTtsSpeed, settings.ttsSpeed),
      _prefs!.setString(_keySelectedWhisperModel, settings.selectedWhisperModelId),
    ]);

    AppLogger.info(_tag, 'Impostazioni salvate con successo');
  }

  /// Aggiorna un singolo campo delle impostazioni
  Future<AppSettings> update({
    bool? showTranscription,
    double? silenceSensitivity,
    String? lastSourceLanguageCode,
    String? lastTargetLanguageCode,
    String? lastMode,
    double? ttsSpeed,
    String? selectedWhisperModelId,
  }) async {
    final current = load();
    final updated = current.copyWith(
      showTranscription: showTranscription,
      silenceSensitivity: silenceSensitivity,
      lastSourceLanguageCode: lastSourceLanguageCode,
      lastTargetLanguageCode: lastTargetLanguageCode,
      lastMode: lastMode,
      ttsSpeed: ttsSpeed,
      selectedWhisperModelId: selectedWhisperModelId,
    );
    await save(updated);
    return updated;
  }

  /// Verifica che SharedPreferences sia inizializzato
  void _ensureInit() {
    if (_prefs == null) {
      throw StateError(
          'SettingsRepository non inizializzato. Chiama init() prima.');
    }
  }
}
