/// Costanti globali dell'applicazione VoiceTranslate.
/// Contiene limiti, configurazioni audio e parametri streaming.
library;

// ============================================================
// AUDIO
// ============================================================

/// Sample rate audio per Whisper (16 kHz obbligatorio)
const int kAudioSampleRate = 16000;

/// Canali audio (mono)
const int kAudioChannels = 1;

/// Bit depth audio
const int kAudioBitDepth = 16;

// ============================================================
// STREAMING
// ============================================================

/// Durata di ogni chunk audio in secondi per lo streaming live
/// Un valore di 3s offre un buon compromesso latenza/accuratezza
const int kStreamingChunkDurationSec = 3;

/// Overlap tra chunk successivi in secondi (per evitare tagli a metà parola)
const int kStreamingOverlapSec = 1;

/// Durata del silenzio per pausa automatica nello streaming in secondi
const int kStreamingSilenceThresholdSec = 3;

/// Soglia di ampiezza per rilevamento silenzio (0.0 - 1.0)
const double kDefaultSilenceSensitivity = 0.03;

// ============================================================
// DOWNLOAD
// ============================================================

/// Spazio minimo richiesto su disco in byte (~3 GB per i modelli)
const int kMinDiskSpaceBytes = 3 * 1024 * 1024 * 1024;

/// Numero massimo di tentativi download per ogni file
const int kMaxDownloadRetries = 5;

/// Dimensione del buffer di download in byte (1 MB)
const int kDownloadBufferSize = 1024 * 1024;

/// Timeout connessione download in secondi
const int kDownloadConnectTimeoutSec = 30;

/// Timeout ricezione download in secondi (per chunk singolo)
const int kDownloadReceiveTimeoutSec = 60;

// ============================================================
// CRONOLOGIA E STORAGE
// ============================================================

/// Numero massimo voci cronologia
const int kMaxHistoryEntries = 20;

/// Timeout inattività background per scarico modelli (5 minuti)
const int kBackgroundUnloadMinutes = 5;
