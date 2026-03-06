/// Configurazione dei modelli ML usati dall'app.
/// URL verificati su Hugging Face, dimensioni reali, supporto multi-modello Whisper.
/// NLLB-200 usa il repo Xenova con modelli ONNX quantizzati (encoder+decoder).
library;

// ============================================================
// CLASSE CONFIGURAZIONE MODELLO
// ============================================================

/// Rappresenta la configurazione di un singolo file modello da scaricare
class ModelFileConfig {
  /// Nome leggibile del modello
  final String displayName;

  /// URL di download da Hugging Face
  final String url;

  /// Nome del file salvato localmente
  final String fileName;

  /// Dimensione attesa in byte (approssimativa, usata per la progress bar)
  final int expectedSizeBytes;

  /// Checksum SHA256 per verifica integrita' (null se non disponibile)
  final String? sha256;

  /// Sottocartella dove salvare il file
  final String subFolder;

  /// Se questo modello e' obbligatorio (true) o opzionale (false)
  final bool isRequired;

  const ModelFileConfig({
    required this.displayName,
    required this.url,
    required this.fileName,
    required this.expectedSizeBytes,
    this.sha256,
    this.subFolder = '',
    this.isRequired = true,
  });
}

// ============================================================
// MODELLI WHISPER (utente sceglie quale usare)
// ============================================================

/// Configurazione di un modello Whisper selezionabile dall'utente
class WhisperModelConfig {
  /// ID univoco del modello (es. 'tiny', 'small', 'medium')
  final String id;

  /// Nome leggibile (es. 'Whisper Tiny')
  final String displayName;

  /// Descrizione breve delle caratteristiche
  final String description;

  /// Configurazione del file da scaricare
  final ModelFileConfig fileConfig;

  /// Velocita' relativa (1 = piu' veloce, 3 = piu' lento)
  final int speedRating;

  /// Accuratezza relativa (1 = meno accurato, 3 = piu' accurato)
  final int accuracyRating;

  const WhisperModelConfig({
    required this.id,
    required this.displayName,
    required this.description,
    required this.fileConfig,
    required this.speedRating,
    required this.accuracyRating,
  });
}

/// Modelli Whisper disponibili per il download
const List<WhisperModelConfig> kWhisperModels = [
  // --- Whisper Tiny: velocissimo, meno accurato ---
  WhisperModelConfig(
    id: 'tiny',
    displayName: 'Whisper Tiny',
    description: 'Velocissimo (~75 MB). Ideale per test rapidi.',
    speedRating: 3,
    accuracyRating: 1,
    fileConfig: ModelFileConfig(
      displayName: 'Whisper Tiny (Trascrizione)',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
      fileName: 'ggml-tiny.bin',
      expectedSizeBytes: 77700000, // ~75 MB
      subFolder: 'whisper',
      isRequired: false,
    ),
  ),

  // --- Whisper Small: buon compromesso ---
  WhisperModelConfig(
    id: 'small',
    displayName: 'Whisper Small',
    description: 'Buon compromesso velocita\'/accuratezza (~466 MB).',
    speedRating: 2,
    accuracyRating: 2,
    fileConfig: ModelFileConfig(
      displayName: 'Whisper Small (Trascrizione)',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
      fileName: 'ggml-small.bin',
      expectedSizeBytes: 488000000, // ~466 MB
      subFolder: 'whisper',
      isRequired: false,
    ),
  ),

  // --- Whisper Medium: migliore accuratezza ---
  WhisperModelConfig(
    id: 'medium',
    displayName: 'Whisper Medium',
    description: 'Migliore accuratezza (~1.5 GB). Consigliato.',
    speedRating: 1,
    accuracyRating: 3,
    fileConfig: ModelFileConfig(
      displayName: 'Whisper Medium (Trascrizione)',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin',
      fileName: 'ggml-medium.bin',
      expectedSizeBytes: 1533000000, // ~1.5 GB
      subFolder: 'whisper',
      isRequired: false,
    ),
  ),

  // --- Whisper Large V2: massima accuratezza ---
  WhisperModelConfig(
    id: 'large-v2',
    displayName: 'Whisper Large V2',
    description: 'Massima accuratezza V2 (~3.1 GB). Per telefoni potenti.',
    speedRating: 1,
    accuracyRating: 3,
    fileConfig: ModelFileConfig(
      displayName: 'Whisper Large V2 (Trascrizione)',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin',
      fileName: 'ggml-large-v2.bin',
      expectedSizeBytes: 3094000000, // ~3.1 GB
      subFolder: 'whisper',
      isRequired: false,
    ),
  ),

  // --- Whisper Large V3 Turbo: ultimo modello, veloce e accurato ---
  WhisperModelConfig(
    id: 'large-v3-turbo',
    displayName: 'Whisper Large V3 Turbo',
    description: 'Ultimo modello OpenAI (~1.6 GB). Veloce e accurato.',
    speedRating: 2,
    accuracyRating: 3,
    fileConfig: ModelFileConfig(
      displayName: 'Whisper Large V3 Turbo (Trascrizione)',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin',
      fileName: 'ggml-large-v3-turbo.bin',
      expectedSizeBytes: 1620000000, // ~1.6 GB
      subFolder: 'whisper',
      isRequired: false,
    ),
  ),
];

/// Modello Whisper di default (Small - buon compromesso)
const String kDefaultWhisperModelId = 'small';

/// Trova un modello Whisper per ID
WhisperModelConfig? findWhisperModelById(String id) {
  for (final model in kWhisperModels) {
    if (model.id == id) return model;
  }
  return null;
}

// ============================================================
// MODELLI NLLB-200 (OBBLIGATORI - traduzione)
// URL corretti dal repo Xenova/nllb-200-distilled-600M (ONNX quantizzato)
// ============================================================

/// File NLLB-200 obbligatori per la traduzione
const List<ModelFileConfig> kNllbModelFiles = [
  // --- Encoder ONNX quantizzato (~419 MB) ---
  ModelFileConfig(
    displayName: 'NLLB-200 Encoder',
    url:
        'https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/onnx/encoder_model_quantized.onnx',
    fileName: 'encoder_model_quantized.onnx',
    expectedSizeBytes: 419120483, // ~419 MB
    subFolder: 'nllb',
  ),

  // --- Decoder ONNX quantizzato merged (~475 MB) ---
  ModelFileConfig(
    displayName: 'NLLB-200 Decoder',
    url:
        'https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/onnx/decoder_model_merged_quantized.onnx',
    fileName: 'decoder_model_merged_quantized.onnx',
    expectedSizeBytes: 475505771, // ~475 MB
    subFolder: 'nllb',
  ),

  // --- Tokenizer JSON (~17 MB) ---
  ModelFileConfig(
    displayName: 'NLLB-200 Tokenizer',
    url:
        'https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/tokenizer.json',
    fileName: 'tokenizer.json',
    expectedSizeBytes: 17100000, // ~17 MB
    subFolder: 'nllb',
  ),

  // --- Tokenizer Config ---
  ModelFileConfig(
    displayName: 'NLLB-200 Config Tokenizer',
    url:
        'https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/tokenizer_config.json',
    fileName: 'tokenizer_config.json',
    expectedSizeBytes: 700000, // ~700 KB
    subFolder: 'nllb',
  ),

  // --- Config modello ---
  ModelFileConfig(
    displayName: 'NLLB-200 Config',
    url:
        'https://huggingface.co/Xenova/nllb-200-distilled-600M/resolve/main/config.json',
    fileName: 'config.json',
    expectedSizeBytes: 250000, // ~250 KB
    subFolder: 'nllb',
  ),
];

// ============================================================
// LISTE AGGREGATE
// ============================================================

/// Tutti i file obbligatori da scaricare al primo avvio
/// Include il modello Whisper di default + tutti i file NLLB
List<ModelFileConfig> getRequiredModelFiles({String whisperModelId = kDefaultWhisperModelId}) {
  final whisperModel = findWhisperModelById(whisperModelId);
  if (whisperModel == null) {
    return [...kNllbModelFiles];
  }
  return [whisperModel.fileConfig, ...kNllbModelFiles];
}

/// Tutti i file modello (per compatibilita' con il download provider)
List<ModelFileConfig> get kModelFiles => getRequiredModelFiles();

/// Dimensione totale stimata di tutti i modelli obbligatori in byte
int get kTotalModelsSize =>
    kModelFiles.fold(0, (sum, m) => sum + m.expectedSizeBytes);
