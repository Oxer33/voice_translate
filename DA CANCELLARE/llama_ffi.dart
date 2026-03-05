/// Binding FFI per llama.cpp (Phi-3 Mini).
/// Fornisce l'interfaccia Dart per la correzione del testo trascritto.
/// La libreria nativa libllama.so viene compilata da CMake per ARM64.
library;

import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:voice_translate/core/constants/app_constants.dart';
import 'package:voice_translate/core/utils/logger.dart';

/// Tag per i log di questo modulo
const String _tag = 'LlamaFFI';

// --- Token speciali Phi-3 chat template ---
// Definiti come costanti per evitare problemi di parsing
const String _sysOpen = '\x3c|system|\x3e';
const String _sysClose = '\x3c|end|\x3e';
const String _userOpen = '\x3c|user|\x3e';
const String _assistOpen = '\x3c|assistant|\x3e';

// --- Typedef per le funzioni C di llama.cpp ---

/// llama_backend_init()
typedef LlamaBackendInitC = Void Function();
typedef LlamaBackendInitDart = void Function();

/// llama_backend_free()
typedef LlamaBackendFreeC = Void Function();
typedef LlamaBackendFreeDart = void Function();

/// llama_model_default_params()
typedef LlamaModelDefaultParamsNative = Pointer<Void> Function();
typedef LlamaModelDefaultParamsDart = Pointer<Void> Function();

/// llama_load_model_from_file(path, params)
typedef LlamaLoadModelNative = Pointer<Void> Function(
    Pointer<Utf8> path, Pointer<Void> params);
typedef LlamaLoadModelDart = Pointer<Void> Function(
    Pointer<Utf8> path, Pointer<Void> params);

/// llama_free_model(model)
typedef LlamaFreeModelNative = Void Function(Pointer<Void> model);
typedef LlamaFreeModelDart = void Function(Pointer<Void> model);

/// int llama_simple_chat(void* model, const char* prompt, char* output, int max_len)
typedef LlamaSimpleChatNative = Int32 Function(
    Pointer<Void> model,
    Pointer<Utf8> prompt,
    Pointer<Uint8> output,
    Int32 maxLen);
typedef LlamaSimpleChatDart = int Function(
    Pointer<Void> model,
    Pointer<Utf8> prompt,
    Pointer<Uint8> output,
    int maxLen);

/// Dati da passare all'Isolate per la correzione
class LlamaIsolateRequest {
  /// Percorso della libreria nativa .so
  final String libraryPath;

  /// Percorso del file modello .gguf
  final String modelPath;

  /// Testo da correggere
  final String inputText;

  /// Numero massimo di token in output
  final int maxTokens;

  const LlamaIsolateRequest({
    required this.libraryPath,
    required this.modelPath,
    required this.inputText,
    this.maxTokens = 512,
  });
}

/// Costruisce il prompt Phi-3 per la correzione del testo
String buildCorrectionPrompt(String inputText) {
  final sb = StringBuffer();
  sb.writeln(_sysOpen);
  sb.writeln('Sei un assistente che corregge testi trascritti.');
  sb.writeln(_sysClose);
  sb.writeln(_userOpen);
  sb.write(kCorrectionPrompt);
  sb.writeln(inputText);
  sb.writeln(_sysClose);
  sb.writeln(_assistOpen);
  return sb.toString();
}

/// Classe wrapper per i binding FFI di llama.cpp
class LlamaFFI {
  /// Percorso alla libreria .so
  final String libraryPath;

  /// Percorso al file modello .gguf
  final String modelPath;

  LlamaFFI({
    required this.libraryPath,
    required this.modelPath,
  });

  /// Esegue la correzione del testo in un Isolate separato
  static Future<String> correctInIsolate({
    required String libraryPath,
    required String modelPath,
    required String inputText,
    int maxTokens = 512,
  }) async {
    AppLogger.info(_tag, 'Avvio correzione testo in Isolate separato...');
    final previewLen = inputText.length.clamp(0, 100);
    AppLogger.debug(
        _tag, 'Testo input: ${inputText.substring(0, previewLen)}...');

    final data = LlamaIsolateRequest(
      libraryPath: libraryPath,
      modelPath: modelPath,
      inputText: inputText,
      maxTokens: maxTokens,
    );

    final result = await Isolate.run(() => _correctWorker(data));
    AppLogger.info(_tag, 'Correzione completata');
    return result;
  }

  /// Worker function che gira nell'Isolate per eseguire la correzione
  static String _correctWorker(LlamaIsolateRequest data) {
    // Carica la libreria nativa nell'Isolate
    final lib = DynamicLibrary.open(data.libraryPath);

    // Inizializza il backend llama
    final backendInitFn =
        lib.lookupFunction<LlamaBackendInitC, LlamaBackendInitDart>(
            'llama_backend_init');
    backendInitFn();

    // Ottieni parametri di default per il modello
    final defaultParamsFn = lib.lookupFunction<LlamaModelDefaultParamsNative,
        LlamaModelDefaultParamsDart>('llama_model_default_params');
    final modelParams = defaultParamsFn();

    // Carica il modello
    final loadFn =
        lib.lookupFunction<LlamaLoadModelNative, LlamaLoadModelDart>(
            'llama_load_model_from_file');

    final modelPathPtr = data.modelPath.toNativeUtf8();
    final model = loadFn(modelPathPtr, modelParams);
    calloc.free(modelPathPtr);

    if (model == nullptr) {
      throw Exception(
          'Impossibile caricare il modello Phi-3 da ${data.modelPath}');
    }

    try {
      // Costruisce il prompt completo con il formato Phi-3 chat template
      final fullPrompt = buildCorrectionPrompt(data.inputText);

      // Alloca buffer per il prompt e l'output
      final promptPtr = fullPrompt.toNativeUtf8();
      final outputBufferSize = data.maxTokens * 4; // 4 byte per carattere UTF-8
      final outputPtr = calloc<Uint8>(outputBufferSize);

      // NOTE: L'implementazione effettiva della generazione richiede
      // l'uso delle API complete di llama.cpp (tokenize, decode loop, sample).
      // Questa e' una versione semplificata che assume l'esistenza di una
      // funzione wrapper 'llama_simple_chat' nella libreria compilata.

      // Usa la funzione wrapper semplificata compilata in llama_wrapper.cpp
      final chatFn =
          lib.lookupFunction<LlamaSimpleChatNative, LlamaSimpleChatDart>(
              'llama_simple_chat');

      final resultCode =
          chatFn(model, promptPtr, outputPtr, outputBufferSize);

      calloc.free(promptPtr);

      if (resultCode != 0) {
        calloc.free(outputPtr);
        throw Exception(
            'llama_simple_chat ha restituito errore: $resultCode');
      }

      // Legge l'output come stringa UTF-8
      final outputStr = outputPtr.cast<Utf8>().toDartString();
      calloc.free(outputPtr);

      return outputStr.trim();
    } finally {
      // Libera il modello
      final freeModelFn =
          lib.lookupFunction<LlamaFreeModelNative, LlamaFreeModelDart>(
              'llama_free_model');
      freeModelFn(model);

      // Libera il backend
      final backendFreeFn =
          lib.lookupFunction<LlamaBackendFreeC, LlamaBackendFreeDart>(
              'llama_backend_free');
      backendFreeFn();
    }
  }
}
