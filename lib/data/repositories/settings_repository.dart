/// Repository per le impostazioni dell'app.
/// Usa SharedPreferences per la persistenza delle preferenze utente.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/domain/entities/app_settings.dart';

/// Tag per i log di questo modulo
const String _tag = 'SettingsRepository';

// --- Chiavi SharedPreferences ---
const String _keyShowRawText = 'settings_show_raw_text';
const String _keyCorrectionEnabled = 'settings_correction_enabled';
const String _keySilenceSensitivity = 'settings_silence_sensitivity';
const String _keyLastSourceLang = 'settings_last_source_lang';
const String _keyLastTargetLang = 'settings_last_target_lang';

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
      showRawText: _prefs!.getBool(_keyShowRawText) ?? true,
      correctionEnabled: _prefs!.getBool(_keyCorrectionEnabled) ?? true,
      silenceSensitivity:
          _prefs!.getDouble(_keySilenceSensitivity) ?? 0.03,
      lastSourceLanguageCode:
          _prefs!.getString(_keyLastSourceLang) ?? 'auto',
      lastTargetLanguageCode:
          _prefs!.getString(_keyLastTargetLang) ?? 'eng_Latn',
    );

    AppLogger.debug(_tag, 'Impostazioni caricate: $settings');
    return settings;
  }

  /// Salva le impostazioni
  Future<void> save(AppSettings settings) async {
    _ensureInit();
    AppLogger.info(_tag, 'Salvataggio impostazioni: $settings');

    await Future.wait([
      _prefs!.setBool(_keyShowRawText, settings.showRawText),
      _prefs!.setBool(_keyCorrectionEnabled, settings.correctionEnabled),
      _prefs!.setDouble(_keySilenceSensitivity, settings.silenceSensitivity),
      _prefs!.setString(_keyLastSourceLang, settings.lastSourceLanguageCode),
      _prefs!.setString(_keyLastTargetLang, settings.lastTargetLanguageCode),
    ]);

    AppLogger.info(_tag, 'Impostazioni salvate con successo');
  }

  /// Aggiorna un singolo campo delle impostazioni
  Future<AppSettings> update({
    bool? showRawText,
    bool? correctionEnabled,
    double? silenceSensitivity,
    String? lastSourceLanguageCode,
    String? lastTargetLanguageCode,
  }) async {
    final current = load();
    final updated = current.copyWith(
      showRawText: showRawText,
      correctionEnabled: correctionEnabled,
      silenceSensitivity: silenceSensitivity,
      lastSourceLanguageCode: lastSourceLanguageCode,
      lastTargetLanguageCode: lastTargetLanguageCode,
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
