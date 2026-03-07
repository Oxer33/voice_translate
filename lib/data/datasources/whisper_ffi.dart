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

typedef VoiceTranslateWhisperTranscribeC = Int32 Function(
  Pointer<Utf8> modelPath,
  Pointer<Float> samples,
  Int32 nSamples,
  Pointer<Utf8> language,
  Pointer<Uint8> outputText,
  Int32 outputTextCapacity,
  Pointer<Uint8> detectedLanguage,
  Int32 detectedLanguageCapacity,
);
typedef VoiceTranslateWhisperTranscribeDart = int Function(
  Pointer<Utf8> modelPath,
  Pointer<Float> samples,
  int nSamples,
  Pointer<Utf8> language,
  Pointer<Uint8> outputText,
  int outputTextCapacity,
  Pointer<Uint8> detectedLanguage,
  int detectedLanguageCapacity,
);
typedef VoiceTranslateWhisperValidateModelC = Int32 Function(
  Pointer<Utf8> modelPath,
);
typedef VoiceTranslateWhisperValidateModelDart = int Function(
  Pointer<Utf8> modelPath,
);

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

/// Dati per l'Isolate di validazione modello
class _WhisperValidateData {
  final String libraryPath;
  final String modelPath;
  const _WhisperValidateData({required this.libraryPath, required this.modelPath});
}

class WhisperFFI {
  /// Valida il modello Whisper in modo SINCRONO (blocca il thread chiamante).
  /// ATTENZIONE: NON usare sul main thread, carica il modello in memoria.
  /// Usare validateModelInIsolate per non bloccare la UI.
  static String? validateModel({
    required String libraryPath,
    required String modelPath,
  }) {
    final lib = DynamicLibrary.open(libraryPath);
    final validateFn = lib.lookupFunction<
        VoiceTranslateWhisperValidateModelC,
        VoiceTranslateWhisperValidateModelDart>(
      'voice_translate_whisper_validate_model',
    );

    final modelPathPtr = modelPath.toNativeUtf8(allocator: calloc);
    try {
      final result = validateFn(modelPathPtr);
      if (result == 0) {
        return null;
      }
      return 'Il modello Whisper selezionato non e\' caricabile (codice $result).';
    } catch (e) {
      return 'Verifica modello Whisper fallita: $e';
    } finally {
      calloc.free(modelPathPtr);
    }
  }

  /// Valida il modello Whisper in un Isolate separato.
  /// Non blocca il main thread e pre-carica il modello nella cache nativa.
  static Future<String?> validateModelInIsolate({
    required String libraryPath,
    required String modelPath,
  }) async {
    AppLogger.info(_tag, 'Validazione modello Whisper in Isolate separato...');
    final data = _WhisperValidateData(libraryPath: libraryPath, modelPath: modelPath);
    try {
      return await Isolate.run(() => _validateWorker(data));
    } catch (e) {
      AppLogger.error(_tag, 'Errore validazione modello in Isolate', e);
      return 'Verifica modello Whisper fallita: $e';
    }
  }

  /// Worker function per la validazione del modello nell'Isolate
  static String? _validateWorker(_WhisperValidateData data) {
    return validateModel(
      libraryPath: data.libraryPath,
      modelPath: data.modelPath,
    );
  }

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
    final lib = DynamicLibrary.open(data.libraryPath);
    final transcribeFn = lib.lookupFunction<
        VoiceTranslateWhisperTranscribeC,
        VoiceTranslateWhisperTranscribeDart>(
      'voice_translate_whisper_transcribe',
    );

    final modelPathPtr = data.modelPath.toNativeUtf8(allocator: calloc);
    final samplesPtr = calloc<Float>(data.audioSamples.length);
    const outputTextCapacity = 16384;
    const detectedLanguageCapacity = 32;
    final outputTextPtr = calloc<Uint8>(outputTextCapacity);
    final detectedLanguagePtr = calloc<Uint8>(detectedLanguageCapacity);
    final languagePtr = data.languageCode == null || data.languageCode!.isEmpty
        ? nullptr.cast<Utf8>()
        : data.languageCode!.toNativeUtf8(allocator: calloc);

    try {
      for (var i = 0; i < data.audioSamples.length; i++) {
        samplesPtr[i] = data.audioSamples[i];
      }

      final result = transcribeFn(
        modelPathPtr,
        samplesPtr,
        data.audioSamples.length,
        languagePtr,
        outputTextPtr,
        outputTextCapacity,
        detectedLanguagePtr,
        detectedLanguageCapacity,
      );

      if (result != 0) {
        throw Exception(
          'voice_translate_whisper_transcribe ha restituito errore: $result',
        );
      }

      final text = outputTextPtr.cast<Utf8>().toDartString().trim();
      final detectedLang =
          detectedLanguagePtr.cast<Utf8>().toDartString().trim();

      return WhisperResult(
        text: text,
        detectedLanguage: detectedLang.isEmpty ? 'unknown' : detectedLang,
      );
    } finally {
      calloc.free(modelPathPtr);
      calloc.free(samplesPtr);
      calloc.free(outputTextPtr);
      calloc.free(detectedLanguagePtr);
      if (languagePtr != nullptr) {
        calloc.free(languagePtr);
      }
    }
  }
}
