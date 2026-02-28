/// Le 50 lingue più comuni supportate da NLLB-200
/// con codici nel formato NLLB e nomi in italiano.
library;

/// Rappresenta una lingua supportata dal sistema di traduzione
class SupportedLanguage {
  /// Codice NLLB-200 (es. "ita_Latn")
  final String nllbCode;

  /// Nome della lingua in italiano
  final String nameIt;

  /// Codice ISO 639-1 (es. "it") - usato da Whisper
  final String whisperCode;

  const SupportedLanguage({
    required this.nllbCode,
    required this.nameIt,
    required this.whisperCode,
  });

  @override
  String toString() => nameIt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportedLanguage && nllbCode == other.nllbCode;

  @override
  int get hashCode => nllbCode.hashCode;
}

/// Opzione speciale "Rilevamento automatico" per la lingua sorgente
const SupportedLanguage kAutoDetectLanguage = SupportedLanguage(
  nllbCode: 'auto',
  nameIt: 'Rilevamento automatico',
  whisperCode: 'auto',
);

/// Lista delle 50 lingue più comuni con codici NLLB e nomi in italiano
const List<SupportedLanguage> kSupportedLanguages = [
  SupportedLanguage(nllbCode: 'ita_Latn', nameIt: 'Italiano', whisperCode: 'it'),
  SupportedLanguage(nllbCode: 'eng_Latn', nameIt: 'Inglese', whisperCode: 'en'),
  SupportedLanguage(nllbCode: 'fra_Latn', nameIt: 'Francese', whisperCode: 'fr'),
  SupportedLanguage(nllbCode: 'deu_Latn', nameIt: 'Tedesco', whisperCode: 'de'),
  SupportedLanguage(nllbCode: 'spa_Latn', nameIt: 'Spagnolo', whisperCode: 'es'),
  SupportedLanguage(nllbCode: 'por_Latn', nameIt: 'Portoghese', whisperCode: 'pt'),
  SupportedLanguage(nllbCode: 'ron_Latn', nameIt: 'Romeno', whisperCode: 'ro'),
  SupportedLanguage(nllbCode: 'nld_Latn', nameIt: 'Olandese', whisperCode: 'nl'),
  SupportedLanguage(nllbCode: 'pol_Latn', nameIt: 'Polacco', whisperCode: 'pl'),
  SupportedLanguage(nllbCode: 'ces_Latn', nameIt: 'Ceco', whisperCode: 'cs'),
  SupportedLanguage(nllbCode: 'slk_Latn', nameIt: 'Slovacco', whisperCode: 'sk'),
  SupportedLanguage(nllbCode: 'hun_Latn', nameIt: 'Ungherese', whisperCode: 'hu'),
  SupportedLanguage(nllbCode: 'hrv_Latn', nameIt: 'Croato', whisperCode: 'hr'),
  SupportedLanguage(nllbCode: 'bul_Cyrl', nameIt: 'Bulgaro', whisperCode: 'bg'),
  SupportedLanguage(nllbCode: 'srp_Cyrl', nameIt: 'Serbo', whisperCode: 'sr'),
  SupportedLanguage(nllbCode: 'slv_Latn', nameIt: 'Sloveno', whisperCode: 'sl'),
  SupportedLanguage(nllbCode: 'ukr_Cyrl', nameIt: 'Ucraino', whisperCode: 'uk'),
  SupportedLanguage(nllbCode: 'rus_Cyrl', nameIt: 'Russo', whisperCode: 'ru'),
  SupportedLanguage(nllbCode: 'ell_Grek', nameIt: 'Greco', whisperCode: 'el'),
  SupportedLanguage(nllbCode: 'tur_Latn', nameIt: 'Turco', whisperCode: 'tr'),
  SupportedLanguage(nllbCode: 'ara_Arab', nameIt: 'Arabo', whisperCode: 'ar'),
  SupportedLanguage(nllbCode: 'heb_Hebr', nameIt: 'Ebraico', whisperCode: 'he'),
  SupportedLanguage(nllbCode: 'pes_Arab', nameIt: 'Persiano', whisperCode: 'fa'),
  SupportedLanguage(nllbCode: 'hin_Deva', nameIt: 'Hindi', whisperCode: 'hi'),
  SupportedLanguage(nllbCode: 'urd_Arab', nameIt: 'Urdu', whisperCode: 'ur'),
  SupportedLanguage(nllbCode: 'ben_Beng', nameIt: 'Bengalese', whisperCode: 'bn'),
  SupportedLanguage(nllbCode: 'tam_Taml', nameIt: 'Tamil', whisperCode: 'ta'),
  SupportedLanguage(nllbCode: 'tel_Telu', nameIt: 'Telugu', whisperCode: 'te'),
  SupportedLanguage(nllbCode: 'mar_Deva', nameIt: 'Marathi', whisperCode: 'mr'),
  SupportedLanguage(nllbCode: 'guj_Gujr', nameIt: 'Gujarati', whisperCode: 'gu'),
  SupportedLanguage(nllbCode: 'kan_Knda', nameIt: 'Kannada', whisperCode: 'kn'),
  SupportedLanguage(nllbCode: 'mal_Mlym', nameIt: 'Malayalam', whisperCode: 'ml'),
  SupportedLanguage(nllbCode: 'pan_Guru', nameIt: 'Punjabi', whisperCode: 'pa'),
  SupportedLanguage(nllbCode: 'tha_Thai', nameIt: 'Tailandese', whisperCode: 'th'),
  SupportedLanguage(nllbCode: 'vie_Latn', nameIt: 'Vietnamita', whisperCode: 'vi'),
  SupportedLanguage(nllbCode: 'ind_Latn', nameIt: 'Indonesiano', whisperCode: 'id'),
  SupportedLanguage(nllbCode: 'zsm_Latn', nameIt: 'Malese', whisperCode: 'ms'),
  SupportedLanguage(nllbCode: 'tgl_Latn', nameIt: 'Filippino', whisperCode: 'tl'),
  SupportedLanguage(nllbCode: 'jpn_Jpan', nameIt: 'Giapponese', whisperCode: 'ja'),
  SupportedLanguage(nllbCode: 'kor_Hang', nameIt: 'Coreano', whisperCode: 'ko'),
  SupportedLanguage(nllbCode: 'zho_Hans', nameIt: 'Cinese (Semplificato)', whisperCode: 'zh'),
  SupportedLanguage(nllbCode: 'zho_Hant', nameIt: 'Cinese (Tradizionale)', whisperCode: 'zh'),
  SupportedLanguage(nllbCode: 'swe_Latn', nameIt: 'Svedese', whisperCode: 'sv'),
  SupportedLanguage(nllbCode: 'dan_Latn', nameIt: 'Danese', whisperCode: 'da'),
  SupportedLanguage(nllbCode: 'nob_Latn', nameIt: 'Norvegese', whisperCode: 'no'),
  SupportedLanguage(nllbCode: 'fin_Latn', nameIt: 'Finlandese', whisperCode: 'fi'),
  SupportedLanguage(nllbCode: 'cat_Latn', nameIt: 'Catalano', whisperCode: 'ca'),
  SupportedLanguage(nllbCode: 'afr_Latn', nameIt: 'Afrikaans', whisperCode: 'af'),
  SupportedLanguage(nllbCode: 'swh_Latn', nameIt: 'Swahili', whisperCode: 'sw'),
  SupportedLanguage(nllbCode: 'lit_Latn', nameIt: 'Lituano', whisperCode: 'lt'),
];

/// Cerca una lingua per codice NLLB
SupportedLanguage? findLanguageByNllbCode(String code) {
  try {
    return kSupportedLanguages.firstWhere((l) => l.nllbCode == code);
  } catch (_) {
    return null;
  }
}

/// Cerca una lingua per codice Whisper
SupportedLanguage? findLanguageByWhisperCode(String code) {
  try {
    return kSupportedLanguages.firstWhere((l) => l.whisperCode == code);
  } catch (_) {
    return null;
  }
}

/// Filtra le lingue per nome (ricerca)
List<SupportedLanguage> searchLanguages(String query) {
  if (query.isEmpty) return kSupportedLanguages;
  final lowerQuery = query.toLowerCase();
  return kSupportedLanguages
      .where((l) => l.nameIt.toLowerCase().contains(lowerQuery))
      .toList();
}
