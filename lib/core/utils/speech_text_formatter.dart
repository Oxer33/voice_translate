library;

const Set<String> _nonSpeechPhrases = {
  'silence',
  'silenzio',
  'noise',
  'rumore',
  'background noise',
  'rumore di fondo',
  'music',
  'musica',
  'applause',
  'applausi',
  'laugh',
  'laughter',
  'laughing',
  'risata',
  'risate',
  'cough',
  'tosse',
  'breathing',
  'respiro',
  'wind',
  'static',
  'beep',
  'blank audio',
  'no speech',
  'nessun parlato',
};

const Set<String> _nonSpeechWords = {
  'silence',
  'silenzio',
  'noise',
  'rumore',
  'background',
  'fondo',
  'music',
  'musica',
  'applause',
  'applausi',
  'laugh',
  'laughter',
  'laughing',
  'risata',
  'risate',
  'cough',
  'tosse',
  'breathing',
  'respiro',
  'wind',
  'static',
  'beep',
  'blank',
  'audio',
  'speech',
  'parlato',
  'nessun',
  'no',
  'di',
};

final List<RegExp> _annotationPatterns = [
  RegExp(
    r'\[(?:[^\]]*?(?:silence|silenzio|noise|rumore|music|musica|applause|applausi|laugh(?:ter|ing)?|risat\w*|cough|toss\w*|breath(?:ing)?|respiro|wind|static|beep|background noise|rumore di fondo|blank audio|no speech|nessun parlato)[^\]]*)\]',
    caseSensitive: false,
  ),
  RegExp(
    r'\((?:[^)]*?(?:silence|silenzio|noise|rumore|music|musica|applause|applausi|laugh(?:ter|ing)?|risat\w*|cough|toss\w*|breath(?:ing)?|respiro|wind|static|beep|background noise|rumore di fondo|blank audio|no speech|nessun parlato)[^)]*)\)',
    caseSensitive: false,
  ),
  RegExp(
    r'<(?:[^>]*?(?:silence|silenzio|noise|rumore|music|musica|applause|applausi|laugh(?:ter|ing)?|risat\w*|cough|toss\w*|breath(?:ing)?|respiro|wind|static|beep|background noise|rumore di fondo|blank audio|no speech|nessun parlato)[^>]*)>',
    caseSensitive: false,
  ),
];

final RegExp _musicNotesOnlyPattern = RegExp(r'^[\s♪♫♬♩]+$');
final RegExp _nonTextCleanupPattern = RegExp(r'[^a-z0-9àèéìíîòóùúçñ ]', caseSensitive: false);

String sanitizeSpeechText(String text) {
  var cleaned = text.trim();
  if (cleaned.isEmpty) {
    return '';
  }

  for (final pattern in _annotationPatterns) {
    cleaned = cleaned.replaceAll(pattern, ' ');
  }

  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  cleaned = cleaned.replaceAll(RegExp(r'^[\-–—:;,\.\s]+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'[\-–—:;,\.\s]+$'), '');
  cleaned = cleaned.trim();

  if (isNonSpeechOnlyText(cleaned)) {
    return '';
  }

  return cleaned;
}

bool isNonSpeechOnlyText(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) {
    return true;
  }

  if (_musicNotesOnlyPattern.hasMatch(cleaned)) {
    return true;
  }

  final normalized = cleaned
      .toLowerCase()
      .replaceAll(_nonTextCleanupPattern, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized.isEmpty) {
    return true;
  }

  if (_nonSpeechPhrases.contains(normalized)) {
    return true;
  }

  final words = normalized.split(' ').where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) {
    return true;
  }

  final containsNonSpeechWord = words.any(_nonSpeechWords.contains);
  final onlyNonSpeechWords = words.every(_nonSpeechWords.contains);
  return containsNonSpeechWord && onlyNonSpeechWords;
}
