/// Binding FFI per ONNX Runtime (NLLB-200 distilled).
/// Fornisce l'interfaccia Dart per la traduzione tramite NLLB-200.
/// Utilizza ONNX Runtime con supporto NNAPI dove disponibile.
library;

import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:voice_translate/core/utils/logger.dart';

/// Tag per i log di questo modulo
const String _tag = 'OnnxFFI';

// --- Typedef per le funzioni C di ONNX Runtime ---

/// OrtCreateEnv(OrtLoggingLevel, const char* logid, OrtEnv** out)
typedef OrtCreateEnvNative = Int32 Function(
    Int32 logLevel, Pointer<Utf8> logId, Pointer<Pointer<Void>> out);
typedef OrtCreateEnvDart = int Function(
    int logLevel, Pointer<Utf8> logId, Pointer<Pointer<Void>> out);

/// OrtCreateSession(OrtEnv*, const char* model_path, OrtSessionOptions*, OrtSession** out)
typedef OrtCreateSessionNative = Int32 Function(
    Pointer<Void> env,
    Pointer<Utf8> modelPath,
    Pointer<Void> options,
    Pointer<Pointer<Void>> out);
typedef OrtCreateSessionDart = int Function(
    Pointer<Void> env,
    Pointer<Utf8> modelPath,
    Pointer<Void> options,
    Pointer<Pointer<Void>> out);

/// OrtReleaseEnv(OrtEnv*)
typedef OrtReleaseEnvNative = Void Function(Pointer<Void> env);
typedef OrtReleaseEnvDart = void Function(Pointer<Void> env);

/// OrtReleaseSession(OrtSession*)
typedef OrtReleaseSessionNative = Void Function(Pointer<Void> session);
typedef OrtReleaseSessionDart = void Function(Pointer<Void> session);

/// int nllb_translate(OrtSession*, const char* src, const char* src_lang,
///                    const char* tgt_lang, char* output, int max_len)
typedef NllbTranslateNative = Int32 Function(
    Pointer<Void> session,
    Pointer<Utf8> srcText,
    Pointer<Utf8> srcLang,
    Pointer<Utf8> tgtLang,
    Pointer<Uint8> output,
    Int32 maxLen);
typedef NllbTranslateDart = int Function(
    Pointer<Void> session,
    Pointer<Utf8> srcText,
    Pointer<Utf8> srcLang,
    Pointer<Utf8> tgtLang,
    Pointer<Uint8> output,
    int maxLen);

/// Dati da passare all'Isolate per la traduzione
class OnnxIsolateRequest {
  /// Percorso della libreria ONNX Runtime .so
  final String libraryPath;

  /// Percorso della cartella contenente model.onnx e tokenizer
  final String modelDir;

  /// Testo sorgente da tradurre
  final String inputText;

  /// Codice lingua sorgente NLLB (es. "ita_Latn")
  final String sourceLanguageCode;

  /// Codice lingua target NLLB (es. "eng_Latn")
  final String targetLanguageCode;

  const OnnxIsolateRequest({
    required this.libraryPath,
    required this.modelDir,
    required this.inputText,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });
}

/// Classe wrapper per i binding FFI di ONNX Runtime
class OnnxFFI {
  /// Percorso alla libreria .so di ONNX Runtime
  final String libraryPath;

  /// Percorso alla cartella dei modelli NLLB
  final String modelDir;

  OnnxFFI({
    required this.libraryPath,
    required this.modelDir,
  });

  /// Esegue la traduzione in un Isolate separato
  static Future<String> translateInIsolate({
    required String libraryPath,
    required String modelDir,
    required String inputText,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    AppLogger.info(_tag, 'Avvio traduzione in Isolate separato...');
    AppLogger.debug(_tag,
        'Traduzione: $sourceLanguageCode -> $targetLanguageCode');
    AppLogger.debug(_tag, 'Testo: $inputText');

    final data = OnnxIsolateRequest(
      libraryPath: libraryPath,
      modelDir: modelDir,
      inputText: inputText,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );

    final result = await Isolate.run(() => _translateWorker(data));
    AppLogger.info(_tag, 'Traduzione completata: $result');
    return result;
  }

  /// Worker function che gira nell'Isolate per eseguire la traduzione
  static String _translateWorker(OnnxIsolateRequest data) {
    AppLogger.debug(_tag, 'Worker Isolate avviato per traduzione NLLB');

    // Carica la libreria ONNX Runtime
    final lib = DynamicLibrary.open(data.libraryPath);

    // Crea l'ambiente ONNX Runtime
    final createEnvFn =
        lib.lookupFunction<OrtCreateEnvNative, OrtCreateEnvDart>(
            'OrtCreateEnv');

    final envPtr = calloc<Pointer<Void>>();
    final logIdPtr = 'VoiceTranslate'.toNativeUtf8();

    // ORT_LOGGING_LEVEL_WARNING = 2
    final envResult = createEnvFn(2, logIdPtr, envPtr);
    calloc.free(logIdPtr);

    if (envResult != 0) {
      calloc.free(envPtr);
      throw Exception('Errore creazione ambiente ONNX: codice $envResult');
    }

    final env = envPtr.value;
    calloc.free(envPtr);

    try {
      // Carica la sessione con il modello ONNX
      final modelPath = '${data.modelDir}/model.onnx';
      final modelPathPtr = modelPath.toNativeUtf8();

      final createSessionFn =
          lib.lookupFunction<OrtCreateSessionNative, OrtCreateSessionDart>(
              'OrtCreateSession');

      final sessionPtr = calloc<Pointer<Void>>();
      final sessionResult =
          createSessionFn(env, modelPathPtr, nullptr, sessionPtr);
      calloc.free(modelPathPtr);

      if (sessionResult != 0) {
        calloc.free(sessionPtr);
        throw Exception(
            'Errore creazione sessione ONNX: codice $sessionResult');
      }

      final session = sessionPtr.value;
      calloc.free(sessionPtr);

      try {
        // NOTE: L'implementazione completa della traduzione NLLB richiede:
        // 1. Tokenizzazione del testo sorgente usando sentencepiece.bpe.model
        // 2. Aggiunta dei token speciali di lingua sorgente e target
        // 3. Esecuzione dell'inferenza encoder-decoder
        // 4. Decodifica dei token di output in testo
        //
        // Questa implementazione usa un wrapper C che gestisce tutti questi passaggi.
        // Il wrapper 'nllb_translate' deve essere compilato insieme al modello.

        // Usa la funzione wrapper di traduzione compilata nativamente
        final translateFn =
            lib.lookupFunction<NllbTranslateNative, NllbTranslateDart>(
                'nllb_translate');

        final srcTextPtr = data.inputText.toNativeUtf8();
        final srcLangPtr = data.sourceLanguageCode.toNativeUtf8();
        final tgtLangPtr = data.targetLanguageCode.toNativeUtf8();
        const maxOutputLen = 4096;
        final outputPtr = calloc<Uint8>(maxOutputLen);

        final translateResult = translateFn(
            session, srcTextPtr, srcLangPtr, tgtLangPtr, outputPtr, maxOutputLen);

        calloc.free(srcTextPtr);
        calloc.free(srcLangPtr);
        calloc.free(tgtLangPtr);

        if (translateResult != 0) {
          calloc.free(outputPtr);
          throw Exception(
              'Errore traduzione NLLB: codice $translateResult');
        }

        final translatedText = outputPtr.cast<Utf8>().toDartString();
        calloc.free(outputPtr);

        return translatedText.trim();
      } finally {
        // Rilascia la sessione
        final releaseSessionFn = lib.lookupFunction<OrtReleaseSessionNative,
            OrtReleaseSessionDart>('OrtReleaseSession');
        releaseSessionFn(session);
      }
    } finally {
      // Rilascia l'ambiente
      final releaseEnvFn =
          lib.lookupFunction<OrtReleaseEnvNative, OrtReleaseEnvDart>(
              'OrtReleaseEnv');
      releaseEnvFn(env);
    }
  }
}
