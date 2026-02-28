/// Provider per la pipeline di elaborazione vocale.
/// Coordina registrazione -> trascrizione -> correzione -> traduzione.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:voice_translate/core/constants/languages.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/data/datasources/llama_ffi.dart';
import 'package:voice_translate/data/datasources/onnx_ffi.dart';
import 'package:voice_translate/data/datasources/whisper_ffi.dart';
import 'package:voice_translate/data/repositories/history_repository.dart';
import 'package:voice_translate/data/services/audio_service.dart';
import 'package:voice_translate/data/services/download_service.dart';
import 'package:voice_translate/domain/entities/pipeline_state.dart';
import 'package:voice_translate/domain/entities/translation_entry.dart';
import 'package:voice_translate/presentation/providers/app_providers.dart';

/// Tag per i log di questo modulo
const String _tag = 'PipelineProvider';

/// UUID generator
const _uuid = Uuid();

/// Provider per lo stato della pipeline
final pipelineStateProvider =
    StateNotifierProvider<PipelineNotifier, PipelineState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final downloadService = ref.watch(downloadServiceProvider);
  final historyRepo = ref.watch(historyRepositoryProvider);
  final settings = ref.watch(appSettingsProvider);
  return PipelineNotifier(
    audioService: audioService,
    downloadService: downloadService,
    historyRepository: historyRepo,
    correctionEnabled: settings.correctionEnabled,
  );
});

/// Notifier per la gestione della pipeline di elaborazione
class PipelineNotifier extends StateNotifier<PipelineState> {
  final AudioService _audioService;
  final DownloadService _downloadService;
  final HistoryRepository _historyRepository;

  /// Lingua sorgente selezionata
  SupportedLanguage _sourceLanguage = kAutoDetectLanguage;

  /// Lingua target selezionata
  SupportedLanguage _targetLanguage = kSupportedLanguages[1]; // Inglese default

  PipelineNotifier({
    required AudioService audioService,
    required DownloadService downloadService,
    required HistoryRepository historyRepository,
    required bool correctionEnabled,
  })  : _audioService = audioService,
        _downloadService = downloadService,
        _historyRepository = historyRepository,
        super(PipelineState.initial(correctionEnabled: correctionEnabled));

  /// Imposta la lingua sorgente
  void setSourceLanguage(SupportedLanguage lang) {
    AppLogger.info(_tag, 'Lingua sorgente: ${lang.nameIt}');
    _sourceLanguage = lang;
  }

  /// Imposta la lingua target
  void setTargetLanguage(SupportedLanguage lang) {
    AppLogger.info(_tag, 'Lingua target: ${lang.nameIt}');
    _targetLanguage = lang;
  }

  /// Abilita/disabilita la correzione
  void setCorrectionEnabled(bool enabled) {
    AppLogger.info(_tag, 'Correzione: $enabled');
    state = state.copyWith(correctionEnabled: enabled);
  }

  /// Getter per lingua sorgente corrente
  SupportedLanguage get sourceLanguage => _sourceLanguage;

  /// Getter per lingua target corrente
  SupportedLanguage get targetLanguage => _targetLanguage;

  /// Avvia la registrazione audio
  Future<void> startRecording() async {
    AppLogger.info(_tag, 'Avvio registrazione...');
    state = PipelineState.initial(
        correctionEnabled: state.correctionEnabled)
      .copyWith(phase: PipelinePhase.recording);

    try {
      await _audioService.startRecording(
        onCountdown: (remaining) {
          if (mounted) {
            state = state.copyWith(remainingSeconds: remaining);
          }
        },
        onAmplitude: (amp) {
          // L'ampiezza viene usata per l'animazione del pulsante
          // Non modifichiamo lo stato qui per evitare rebuild eccessivi
        },
        onSilenceDetected: () {
          AppLogger.info(_tag, 'Silenzio rilevato, stop automatico');
          stopRecordingAndProcess();
        },
        onMaxDurationReached: () {
          AppLogger.info(_tag, 'Durata massima raggiunta');
          stopRecordingAndProcess();
        },
      );
    } catch (e) {
      AppLogger.error(_tag, 'Errore avvio registrazione', e);
      state = PipelineState.error('Errore registrazione: $e');
    }
  }

  /// Ferma la registrazione e avvia la pipeline di elaborazione
  Future<void> stopRecordingAndProcess() async {
    AppLogger.info(_tag, 'Stop registrazione e avvio elaborazione...');

    try {
      final audioPath = await _audioService.stopRecording();
      if (audioPath == null) {
        state = PipelineState.error('Nessun file audio registrato');
        return;
      }

      AppLogger.info(_tag, 'File audio: $audioPath');

      // Converti WAV in campioni float32
      final samples = await _audioService.wavToFloat32Samples(audioPath);
      AppLogger.info(_tag, 'Campioni audio: ${samples.length}');

      // --- FASE 1: Trascrizione con Whisper ---
      await _transcribe(samples);

      if (state.rawText == null || state.rawText!.isEmpty) {
        state = PipelineState.error(
            'Nessun testo trascritto. Prova a parlare piu\' chiaramente.');
        return;
      }

      // --- FASE 2: Correzione con Phi-3 (opzionale) ---
      if (state.correctionEnabled) {
        await _correct(state.rawText!);
      }

      // --- FASE 3: Traduzione con NLLB ---
      final textToTranslate =
          state.correctedText ?? state.rawText!;
      await _translate(textToTranslate);

      // Pipeline completata
      state = state.copyWith(phase: PipelinePhase.completed);
      AppLogger.info(_tag, 'Pipeline completata con successo!');

      // Salva nella cronologia
      await _saveToHistory();
    } catch (e) {
      AppLogger.error(_tag, 'Errore pipeline', e);
      state = PipelineState.error('Errore: $e');
    }
  }

  /// Fase 1: Trascrizione audio con Whisper.cpp
  Future<void> _transcribe(List<double> samples) async {
    AppLogger.info(_tag, 'FASE 1: Trascrizione con Whisper...');
    state = state.copyWith(phase: PipelinePhase.transcribing);

    final modelsPath = await _downloadService.getModelsBasePath();
    final whisperModelPath = '$modelsPath/whisper/ggml-small.bin';

    // Determina il codice lingua per Whisper
    final langCode = _sourceLanguage.nllbCode == 'auto'
        ? null
        : _sourceLanguage.whisperCode;

    final result = await WhisperFFI.transcribeInIsolate(
      libraryPath: 'libwhisper.so',
      modelPath: whisperModelPath,
      audioSamples: samples,
      languageCode: langCode,
    );

    AppLogger.info(
        _tag, 'Trascrizione: "${result.text}" (lingua: ${result.detectedLanguage})');

    state = state.copyWith(
      rawText: result.text,
      detectedLanguage: result.detectedLanguage,
    );

    // Se la lingua sorgente era "auto", aggiorna con quella rilevata
    if (_sourceLanguage.nllbCode == 'auto') {
      final detected =
          findLanguageByWhisperCode(result.detectedLanguage);
      if (detected != null) {
        AppLogger.info(
            _tag, 'Lingua rilevata automaticamente: ${detected.nameIt}');
      }
    }
  }

  /// Fase 2: Correzione testo con Phi-3 via llama.cpp
  Future<void> _correct(String text) async {
    AppLogger.info(_tag, 'FASE 2: Correzione con Phi-3...');
    state = state.copyWith(phase: PipelinePhase.correcting);

    final modelsPath = await _downloadService.getModelsBasePath();
    final phi3ModelPath =
        '$modelsPath/phi3/Phi-3-mini-4k-instruct-q4.gguf';

    try {
      final corrected = await LlamaFFI.correctInIsolate(
        libraryPath: 'libllama.so',
        modelPath: phi3ModelPath,
        inputText: text,
      );

      AppLogger.info(_tag, 'Testo corretto: "$corrected"');
      state = state.copyWith(correctedText: corrected);
    } catch (e) {
      AppLogger.error(_tag, 'Errore correzione (continuiamo senza)', e);
      // Se la correzione fallisce, usiamo il testo originale
      state = state.copyWith(correctedText: text);
    }
  }

  /// Fase 3: Traduzione con NLLB-200 via ONNX
  Future<void> _translate(String text) async {
    AppLogger.info(_tag, 'FASE 3: Traduzione con NLLB-200...');
    state = state.copyWith(phase: PipelinePhase.translating);

    final modelsPath = await _downloadService.getModelsBasePath();
    final nllbModelDir = '$modelsPath/nllb';

    // Determina la lingua sorgente per NLLB
    String srcLangCode;
    if (_sourceLanguage.nllbCode == 'auto' &&
        state.detectedLanguage != null) {
      final detected =
          findLanguageByWhisperCode(state.detectedLanguage!);
      srcLangCode = detected?.nllbCode ?? 'eng_Latn';
    } else {
      srcLangCode = _sourceLanguage.nllbCode;
    }

    final translated = await OnnxFFI.translateInIsolate(
      libraryPath: 'libonnxruntime.so',
      modelDir: nllbModelDir,
      inputText: text,
      sourceLanguageCode: srcLangCode,
      targetLanguageCode: _targetLanguage.nllbCode,
    );

    AppLogger.info(_tag, 'Testo tradotto: "$translated"');
    state = state.copyWith(translatedText: translated);
  }

  /// Salva il risultato nella cronologia
  Future<void> _saveToHistory() async {
    AppLogger.info(_tag, 'Salvataggio in cronologia...');

    String srcLangCode = _sourceLanguage.nllbCode;
    String srcLangName = _sourceLanguage.nameIt;

    // Se auto-detect, usa la lingua rilevata
    if (_sourceLanguage.nllbCode == 'auto' &&
        state.detectedLanguage != null) {
      final detected =
          findLanguageByWhisperCode(state.detectedLanguage!);
      if (detected != null) {
        srcLangCode = detected.nllbCode;
        srcLangName = detected.nameIt;
      }
    }

    final entry = TranslationEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      sourceLanguageCode: srcLangCode,
      targetLanguageCode: _targetLanguage.nllbCode,
      sourceLanguageName: srcLangName,
      targetLanguageName: _targetLanguage.nameIt,
      rawText: state.rawText ?? '',
      correctedText: state.correctedText,
      translatedText: state.translatedText ?? '',
    );

    try {
      await _historyRepository.add(entry);
      AppLogger.info(_tag, 'Salvato in cronologia: ${entry.id}');
    } catch (e) {
      AppLogger.error(_tag, 'Errore salvataggio cronologia', e);
    }
  }

  /// Resetta la pipeline allo stato iniziale
  void reset() {
    AppLogger.info(_tag, 'Reset pipeline');
    state = PipelineState.initial(
        correctionEnabled: state.correctionEnabled);
  }
}
