/// Binding FFI per whisper.cpp.
/// Fornisce l'interfaccia Dart per la trascrizione audio tramite dart:ffi.
/// La libreria nativa libwhisper.so viene compilata da CMake per ARM64.
library;

import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:voice_translate/core/utils/logger.dart';

/// Tag per i log di questo modulo
const String _tag = 'WhisperFFI';

// --- Typedef per le funzioni C di whisper.cpp ---

/// whisper_init_from_file(const char * path) -> struct whisper_context *
typedef WhisperInitFromFileC = Pointer<Void> Function(Pointer<Utf8> path);
typedef WhisperInitFromFileDart = Pointer<Void> Function(Pointer<Utf8> path);

/// whisper_free(struct whisper_context * ctx)
typedef WhisperFreeC = Void Function(Pointer<Void> ctx);
typedef WhisperFreeDart = void Function(Pointer<Void> ctx);

/// whisper_full(struct whisper_context * ctx, struct whisper_full_params params, const float * samples, int n_samples) -> int
typedef WhisperFullC = Int32 Function(
    Pointer<Void> ctx, Pointer<Void> params, Pointer<Float> samples, Int32 nSamples);
typedef WhisperFullDart = int Function(
    Pointer<Void> ctx, Pointer<Void> params, Pointer<Float> samples, int nSamples);

/// whisper_full_default_params(enum whisper_sampling_strategy strategy) -> struct whisper_full_params
typedef WhisperFullDefaultParamsC = Pointer<Void> Function(Int32 strategy);
typedef WhisperFullDefaultParamsDart = Pointer<Void> Function(int strategy);

/// whisper_full_n_segments(struct whisper_context * ctx) -> int
typedef WhisperFullNSegmentsC = Int32 Function(Pointer<Void> ctx);
typedef WhisperFullNSegmentsDart = int Function(Pointer<Void> ctx);

/// whisper_full_get_segment_text(struct whisper_context * ctx, int i_segment) -> const char *
typedef WhisperFullGetSegmentTextC = Pointer<Utf8> Function(Pointer<Void> ctx, Int32 iSegment);
typedef WhisperFullGetSegmentTextDart = Pointer<Utf8> Function(Pointer<Void> ctx, int iSegment);

/// whisper_full_lang_id(struct whisper_context * ctx) -> int
typedef WhisperFullLangIdC = Int32 Function(Pointer<Void> ctx);
typedef WhisperFullLangIdDart = int Function(Pointer<Void> ctx);

/// whisper_lang_str(int id) -> const char *
typedef WhisperLangStrC = Pointer<Utf8> Function(Int32 id);
typedef WhisperLangStrDart = Pointer<Utf8> Function(int id);

/// Risultato della trascrizione Whisper
class WhisperResult {
  /// Testo trascritto
  final String text;

  /// Codice lingua rilevata (es. "it", "en")
  final String detectedLanguage;

  const WhisperResult({required this.text, required this.detectedLanguage});

  @override
  String toString() => 'WhisperResult(lang: $detectedLanguage, text: $text)';
}

/// Dati da passare all'Isolate per la trascrizione
class _WhisperIsolateData {
  /// Percorso della libreria nativa .so
  final String libraryPath;

  /// Percorso del file modello .bin
  final String modelPath;

  /// Campioni audio float32 normalizzati [-1.0, 1.0]
  final List<double> audioSamples;

  /// Codice lingua forzata (null = auto-detect)
  final String? languageCode;

  const _WhisperIsolateData({
    required this.libraryPath,
    required this.modelPath,
    required this.audioSamples,
    this.languageCode,
  });
}

/// Classe wrapper per i binding FFI di whisper.cpp
class WhisperFFI {
  /// Libreria nativa caricata
  DynamicLibrary? _lib;

  /// Contesto whisper attivo
  Pointer<Void>? _ctx;

  /// Percorso alla libreria .so
  final String _libraryPath;

  /// Percorso al file modello
  final String _modelPath;

  WhisperFFI({
    required String libraryPath,
    required String modelPath,
  })  : _libraryPath = libraryPath,
        _modelPath = modelPath;

  /// Carica la libreria nativa e inizializza il modello
  void load() {
    AppLogger.info(_tag, 'Caricamento libreria whisper: $_libraryPath');
    _lib = DynamicLibrary.open(_libraryPath);

    AppLogger.info(_tag, 'Inizializzazione modello: $_modelPath');
    final initFn = _lib!.lookupFunction<WhisperInitFromFileC, WhisperInitFromFileDart>(
        'whisper_init_from_file');

    final pathPtr = _modelPath.toNativeUtf8();
    _ctx = initFn(pathPtr);
    calloc.free(pathPtr);

    if (_ctx == null || _ctx == nullptr) {
      throw Exception('Impossibile caricare il modello Whisper da $_modelPath');
    }
    AppLogger.info(_tag, 'Modello Whisper caricato con successo');
  }

  /// Libera le risorse native
  void dispose() {
    if (_ctx != null && _ctx != nullptr && _lib != null) {
      AppLogger.info(_tag, 'Rilascio risorse Whisper...');
      final freeFn =
          _lib!.lookupFunction<WhisperFreeC, WhisperFreeDart>('whisper_free');
      freeFn(_ctx!);
      _ctx = null;
      AppLogger.info(_tag, 'Risorse Whisper rilasciate');
    }
  }

  /// Esegue la trascrizione in un Isolate separato per non bloccare l'UI
  static Future<WhisperResult> transcribeInIsolate({
    required String libraryPath,
    required String modelPath,
    required List<double> audioSamples,
    String? languageCode,
  }) async {
    AppLogger.info(_tag, 'Avvio trascrizione in Isolate separato...');
    AppLogger.debug(_tag, 'Campioni audio: ${audioSamples.length}');

    final data = _WhisperIsolateData(
      libraryPath: libraryPath,
      modelPath: modelPath,
      audioSamples: audioSamples,
      languageCode: languageCode,
    );

    final result = await Isolate.run(() => _transcribeWorker(data));
    AppLogger.info(_tag, 'Trascrizione completata: $result');
    return result;
  }

  /// Worker function che gira nell'Isolate
  static WhisperResult _transcribeWorker(_WhisperIsolateData data) {
    // Carica la libreria nativa nell'Isolate
    final lib = DynamicLibrary.open(data.libraryPath);

    // Inizializza il modello
    final initFn = lib.lookupFunction<WhisperInitFromFileC, WhisperInitFromFileDart>(
        'whisper_init_from_file');
    final modelPathPtr = data.modelPath.toNativeUtf8();
    final ctx = initFn(modelPathPtr);
    calloc.free(modelPathPtr);

    if (ctx == nullptr) {
      throw Exception('Impossibile caricare Whisper nel worker Isolate');
    }

    try {
      // Prepara i parametri di default (WHISPER_SAMPLING_GREEDY = 0)
      final defaultParamsFn =
          lib.lookupFunction<WhisperFullDefaultParamsC, WhisperFullDefaultParamsDart>(
              'whisper_full_default_params');
      final params = defaultParamsFn(0);

      // Alloca i campioni audio in memoria nativa
      final samplesPtr = calloc<Float>(data.audioSamples.length);
      for (var i = 0; i < data.audioSamples.length; i++) {
        samplesPtr[i] = data.audioSamples[i];
      }

      // Esegue la trascrizione
      final fullFn = lib.lookupFunction<WhisperFullC, WhisperFullDart>('whisper_full');
      final result = fullFn(ctx, params, samplesPtr, data.audioSamples.length);

      calloc.free(samplesPtr);

      if (result != 0) {
        throw Exception('whisper_full ha restituito errore: $result');
      }

      // Legge i segmenti trascritti
      final nSegmentsFn =
          lib.lookupFunction<WhisperFullNSegmentsC, WhisperFullNSegmentsDart>(
              'whisper_full_n_segments');
      final getTextFn =
          lib.lookupFunction<WhisperFullGetSegmentTextC, WhisperFullGetSegmentTextDart>(
              'whisper_full_get_segment_text');

      final nSegments = nSegmentsFn(ctx);
      final buffer = StringBuffer();

      for (var i = 0; i < nSegments; i++) {
        final textPtr = getTextFn(ctx, i);
        if (textPtr != nullptr) {
          buffer.write(textPtr.toDartString());
        }
      }

      // Rileva la lingua
      final langIdFn =
          lib.lookupFunction<WhisperFullLangIdC, WhisperFullLangIdDart>(
              'whisper_full_lang_id');
      final langStrFn =
          lib.lookupFunction<WhisperLangStrC, WhisperLangStrDart>(
              'whisper_lang_str');

      final langId = langIdFn(ctx);
      final langPtr = langStrFn(langId);
      final detectedLang = langPtr != nullptr ? langPtr.toDartString() : 'unknown';

      return WhisperResult(
        text: buffer.toString().trim(),
        detectedLanguage: detectedLang,
      );
    } finally {
      // Libera il contesto whisper
      final freeFn =
          lib.lookupFunction<WhisperFreeC, WhisperFreeDart>('whisper_free');
      freeFn(ctx);
    }
  }
}
