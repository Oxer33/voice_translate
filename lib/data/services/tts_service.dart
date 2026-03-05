/// Servizio Text-to-Speech per la modalità parlato.
/// Usa il TTS nativo di Android tramite flutter_tts.
/// Supporta tutte le lingue disponibili sul dispositivo.
library;

import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:voice_translate/core/utils/logger.dart';

/// Tag per i log di questo modulo
const String _tag = 'TtsService';

/// Servizio per la sintesi vocale (Text-to-Speech)
class TtsService {
  /// Istanza flutter_tts
  final FlutterTts _tts = FlutterTts();

  /// Se il TTS è inizializzato
  bool _isInitialized = false;

  /// Se il TTS sta parlando
  bool _isSpeaking = false;

  /// Completer per attendere la fine della riproduzione
  Completer<void>? _speakCompleter;

  /// Callback quando il TTS finisce di parlare
  void Function()? onComplete;

  /// Inizializza il TTS con la lingua target
  Future<void> init({
    required String languageCode,
    double speed = 1.0,
    double volume = 1.0,
  }) async {
    AppLogger.info(_tag, 'Inizializzazione TTS...');

    // Imposta il motore TTS di default
    await _tts.setEngine('com.google.android.tts');

    // Imposta la lingua (converte codice NLLB in BCP-47)
    final bcp47 = _nllbToBcp47(languageCode);
    final result = await _tts.setLanguage(bcp47);
    if (result == 1) {
      AppLogger.info(_tag, 'Lingua TTS impostata: $bcp47');
    } else {
      AppLogger.warning(_tag, 'Lingua $bcp47 non disponibile, uso default');
      // Fallback a inglese
      await _tts.setLanguage('en-US');
    }

    // Imposta velocità e volume
    await _tts.setSpeechRate(speed.clamp(0.1, 2.0));
    await _tts.setVolume(volume.clamp(0.0, 1.0));
    await _tts.setPitch(1.0);

    // Handler di completamento
    _tts.setCompletionHandler(() {
      AppLogger.debug(_tag, 'TTS completato');
      _isSpeaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
      onComplete?.call();
    });

    // Handler di errore
    _tts.setErrorHandler((msg) {
      AppLogger.error(_tag, 'Errore TTS: $msg');
      _isSpeaking = false;
      _speakCompleter?.completeError(Exception('Errore TTS: $msg'));
      _speakCompleter = null;
    });

    _isInitialized = true;
    AppLogger.info(_tag, 'TTS inizializzato con lingua: $bcp47, velocità: $speed');
  }

  /// Pronuncia un testo e attende il completamento
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      AppLogger.warning(_tag, 'TTS non inizializzato, chiamo init()');
      await init(languageCode: 'eng_Latn');
    }

    if (text.trim().isEmpty) {
      AppLogger.debug(_tag, 'Testo vuoto, niente da pronunciare');
      return;
    }

    // Se sta già parlando, ferma e riparti
    if (_isSpeaking) {
      await stop();
    }

    AppLogger.debug(_tag, 'Pronuncia: "${text.substring(0, text.length.clamp(0, 50))}..."');

    _isSpeaking = true;
    _speakCompleter = Completer<void>();

    await _tts.speak(text);
    return _speakCompleter!.future;
  }

  /// Pronuncia senza attendere il completamento (fire-and-forget)
  Future<void> speakAsync(String text) async {
    if (!_isInitialized) {
      await init(languageCode: 'eng_Latn');
    }

    if (text.trim().isEmpty) return;

    if (_isSpeaking) {
      await stop();
    }

    _isSpeaking = true;
    _speakCompleter = Completer<void>();
    await _tts.speak(text);
  }

  /// Ferma la riproduzione in corso
  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
      AppLogger.debug(_tag, 'TTS fermato');
    }
  }

  /// Cambia la lingua del TTS
  Future<void> setLanguage(String nllbLanguageCode) async {
    final bcp47 = _nllbToBcp47(nllbLanguageCode);
    final result = await _tts.setLanguage(bcp47);
    AppLogger.info(_tag, 'Lingua TTS cambiata: $bcp47 (result: $result)');
  }

  /// Cambia la velocità del TTS
  Future<void> setSpeed(double speed) async {
    await _tts.setSpeechRate(speed.clamp(0.1, 2.0));
    AppLogger.debug(_tag, 'Velocità TTS: $speed');
  }

  /// Verifica se una lingua è disponibile per il TTS
  Future<bool> isLanguageAvailable(String nllbLanguageCode) async {
    final bcp47 = _nllbToBcp47(nllbLanguageCode);
    final result = await _tts.isLanguageAvailable(bcp47);
    return result == 1;
  }

  /// Ottiene la lista delle lingue disponibili sul dispositivo
  Future<List<String>> getAvailableLanguages() async {
    final languages = await _tts.getLanguages;
    if (languages is List) {
      return languages.cast<String>();
    }
    return [];
  }

  /// Se il TTS sta parlando
  bool get isSpeaking => _isSpeaking;

  /// Converte codice lingua NLLB in codice BCP-47 per il TTS
  String _nllbToBcp47(String nllbCode) {
    // Mappa dei codici NLLB più comuni verso BCP-47
    const nllbToBcp47Map = {
      'ita_Latn': 'it-IT',
      'eng_Latn': 'en-US',
      'fra_Latn': 'fr-FR',
      'deu_Latn': 'de-DE',
      'spa_Latn': 'es-ES',
      'por_Latn': 'pt-BR',
      'rus_Cyrl': 'ru-RU',
      'zho_Hans': 'zh-CN',
      'zho_Hant': 'zh-TW',
      'jpn_Jpan': 'ja-JP',
      'kor_Hang': 'ko-KR',
      'ara_Arab': 'ar-SA',
      'hin_Deva': 'hi-IN',
      'tur_Latn': 'tr-TR',
      'pol_Latn': 'pl-PL',
      'nld_Latn': 'nl-NL',
      'swe_Latn': 'sv-SE',
      'dan_Latn': 'da-DK',
      'nor_Latn': 'nb-NO',
      'fin_Latn': 'fi-FI',
      'ell_Grek': 'el-GR',
      'ces_Latn': 'cs-CZ',
      'ron_Latn': 'ro-RO',
      'hun_Latn': 'hu-HU',
      'ukr_Cyrl': 'uk-UA',
      'tha_Thai': 'th-TH',
      'vie_Latn': 'vi-VN',
      'ind_Latn': 'id-ID',
      'msa_Latn': 'ms-MY',
      'heb_Hebr': 'he-IL',
      'bul_Cyrl': 'bg-BG',
      'hrv_Latn': 'hr-HR',
      'slk_Latn': 'sk-SK',
      'cat_Latn': 'ca-ES',
    };

    return nllbToBcp47Map[nllbCode] ?? 'en-US';
  }

  /// Rilascia le risorse
  Future<void> dispose() async {
    AppLogger.info(_tag, 'Rilascio risorse TtsService...');
    await stop();
    await _tts.stop();
    AppLogger.info(_tag, 'TtsService disposed');
  }
}
