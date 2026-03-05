/// Configurazione dei modelli ML usati dall'app.
/// Contiene URL di download, dimensioni attese e checksum SHA256.
library;

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

  /// Checksum SHA256 per verifica integrità (null se non disponibile)
  final String? sha256;

  /// Sottocartella dove salvare il file
  final String subFolder;

  const ModelFileConfig({
    required this.displayName,
    required this.url,
    required this.fileName,
    required this.expectedSizeBytes,
    this.sha256,
    this.subFolder = '',
  });
}

/// Tutti i file modello da scaricare
/// Stack ottimizzato: Whisper Medium (1.5GB) + NLLB-200 ONNX (1.2GB)
/// Rimosso Phi-3 per semplicità e risparmio RAM/storage
const List<ModelFileConfig> kModelFiles = [
  // --- Whisper Medium multilingual (migliore accuratezza) ---
  ModelFileConfig(
    displayName: 'Whisper Medium (Trascrizione)',
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin',
    fileName: 'ggml-medium.bin',
    expectedSizeBytes: 1533000000, // ~1.5 GB
    subFolder: 'whisper',
  ),

  // --- NLLB-200 distilled 600M (ONNX) ---
  ModelFileConfig(
    displayName: 'NLLB-200 Modello (Traduzione)',
    url:
        'https://huggingface.co/facebook/nllb-200-distilled-600M/resolve/main/onnx/model.onnx',
    fileName: 'model.onnx',
    expectedSizeBytes: 1200000000, // ~1.2 GB
    subFolder: 'nllb',
  ),
  ModelFileConfig(
    displayName: 'NLLB-200 Tokenizer',
    url:
        'https://huggingface.co/facebook/nllb-200-distilled-600M/resolve/main/tokenizer.json',
    fileName: 'tokenizer.json',
    expectedSizeBytes: 17000000, // ~17 MB
    subFolder: 'nllb',
  ),
  ModelFileConfig(
    displayName: 'NLLB-200 SentencePiece',
    url:
        'https://huggingface.co/facebook/nllb-200-distilled-600M/resolve/main/sentencepiece.bpe.model',
    fileName: 'sentencepiece.bpe.model',
    expectedSizeBytes: 4800000, // ~4.8 MB
    subFolder: 'nllb',
  ),
  ModelFileConfig(
    displayName: 'NLLB-200 Vocabolario',
    url:
        'https://huggingface.co/facebook/nllb-200-distilled-600M/resolve/main/vocab.json',
    fileName: 'vocab.json',
    expectedSizeBytes: 3500000, // ~3.5 MB
    subFolder: 'nllb',
  ),
];

/// Dimensione totale stimata di tutti i modelli in byte
int get kTotalModelsSize =>
    kModelFiles.fold(0, (sum, m) => sum + m.expectedSizeBytes);
