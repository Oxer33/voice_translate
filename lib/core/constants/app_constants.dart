/// Costanti globali dell'applicazione VoiceTranslate.
/// Contiene URL dei modelli, dimensioni attese, limiti e configurazioni.
library;

/// Durata massima della registrazione in secondi
const int kMaxRecordingDurationSec = 60;

/// Durata del silenzio per stop automatico in secondi
const int kSilenceThresholdSec = 2;

/// Soglia di ampiezza per rilevamento silenzio (0.0 - 1.0)
const double kDefaultSilenceSensitivity = 0.03;

/// Spazio minimo richiesto su disco in byte (6 GB)
const int kMinDiskSpaceBytes = 6 * 1024 * 1024 * 1024;

/// Numero massimo di tentativi download
const int kMaxDownloadRetries = 3;

/// Numero massimo voci cronologia
const int kMaxHistoryEntries = 10;

/// Soglia RAM minima per Phi-3 in MB
const int kMinRamForPhi3MB = 3072;

/// Timeout inattività background per scarico modelli (5 minuti)
const int kBackgroundUnloadMinutes = 5;

/// Sample rate audio per Whisper
const int kAudioSampleRate = 16000;

/// Canali audio (mono)
const int kAudioChannels = 1;

/// Bit depth audio
const int kAudioBitDepth = 16;

/// Prompt di correzione per Phi-3
const String kCorrectionPrompt =
    'Correggi il seguente testo trascritto da un sistema STT. '
    'Mantieni il significato originale, correggi solo errori grammaticali, '
    'punteggiatura e parole errate tipiche della trascrizione automatica. '
    'Rispondi solo con il testo corretto, senza spiegazioni: ';
