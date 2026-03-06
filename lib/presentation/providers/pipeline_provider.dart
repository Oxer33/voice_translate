/// Provider per la pipeline di elaborazione vocale streaming.
/// Architettura CORRETTA: usa AudioRecorder.startStream() per cattura continua
/// senza gap. I chunk PCM vengono accumulati e processati in sequenza
/// con un lock per evitare sovrapposizioni.
///
/// Flusso: Microfono (stream continuo) -> Buffer PCM -> Whisper (Isolate) -> NLLB (Isolate) -> UI/TTS
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:voice_translate/core/constants/app_constants.dart';
import 'package:voice_translate/core/constants/languages.dart';
import 'package:voice_translate/core/constants/model_config.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/data/datasources/onnx_ffi.dart';
import 'package:voice_translate/data/datasources/whisper_ffi.dart';
import 'package:voice_translate/data/repositories/history_repository.dart';
import 'package:voice_translate/data/services/audio_service.dart';
import 'package:voice_translate/data/services/download_service.dart';
import 'package:voice_translate/data/services/tts_service.dart';
import 'package:voice_translate/domain/entities/pipeline_state.dart';
import 'package:voice_translate/domain/entities/translation_entry.dart';
import 'package:voice_translate/presentation/providers/app_providers.dart';

/// Tag per i log di questo modulo
const String _tag = 'PipelineProvider';

/// UUID generator
const _uuid = Uuid();

/// Provider per lo stato della pipeline streaming
final pipelineStateProvider =
    StateNotifierProvider<PipelineNotifier, PipelineState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final downloadService = ref.watch(downloadServiceProvider);
  final ttsService = ref.watch(ttsServiceProvider);
  final historyRepo = ref.watch(historyRepositoryProvider);
  return PipelineNotifier(
    audioService: audioService,
    downloadService: downloadService,
    ttsService: ttsService,
    historyRepository: historyRepo,
  );
});

/// Notifier per la gestione della pipeline streaming.
/// Usa un approccio a coda: i chunk audio arrivano dal microfono in continuo,
/// vengono messi in coda e processati uno alla volta senza gap.
class PipelineNotifier extends StateNotifier<PipelineState> {
  final AudioService _audioService;
  final DownloadService _downloadService;
  final TtsService _ttsService;
  final HistoryRepository _historyRepository;

  /// Lingua sorgente selezionata
  SupportedLanguage _sourceLanguage = kAutoDetectLanguage;

  /// Lingua target selezionata
  SupportedLanguage _targetLanguage = kSupportedLanguages[1]; // Inglese

  /// ID del modello Whisper selezionato
  String _selectedWhisperModelId = kDefaultWhisperModelId;

  /// Se lo streaming e' attivo
  bool _streamingActive = false;

  /// Lock per evitare processing concorrente di chunk
  bool _isProcessingChunk = false;

  /// Coda dei chunk audio da processare (FIFO)
  final Queue<List<double>> _chunkQueue = Queue<List<double>>();

  PipelineNotifier({
    required AudioService audioService,
    required DownloadService downloadService,
    required TtsService ttsService,
    required HistoryRepository historyRepository,
  })  : _audioService = audioService,
        _downloadService = downloadService,
        _ttsService = ttsService,
        _historyRepository = historyRepository,
        super(PipelineState.initial());

  // ============================================================
  // SETTERS
  // ============================================================

  /// Imposta la lingua sorgente
  void setSourceLanguage(SupportedLanguage lang) {
    AppLogger.info(_tag, 'Lingua sorgente: ${lang.nameIt}');
    _sourceLanguage = lang;
  }

  /// Imposta la lingua target
  void setTargetLanguage(SupportedLanguage lang) {
    AppLogger.info(_tag, 'Lingua target: ${lang.nameIt}');
    _targetLanguage = lang;
    _ttsService.setLanguage(lang.nllbCode);
  }

  /// Cambia la modalita' dell'app (TEXT o SPEECH)
  void setMode(AppMode mode) {
    AppLogger.info(_tag, 'Modalita\': ${modeDisplayName(mode)}');
    state = state.copyWith(mode: mode);
  }

  /// Imposta il modello Whisper da usare
  void setWhisperModel(String modelId) {
    AppLogger.info(_tag, 'Modello Whisper: $modelId');
    _selectedWhisperModelId = modelId;
  }

  // ============================================================
  // GETTERS
  // ============================================================

  SupportedLanguage get sourceLanguage => _sourceLanguage;
  SupportedLanguage get targetLanguage => _targetLanguage;

  // ============================================================
  // STREAMING LIVE
  // ============================================================

  /// Avvia lo streaming live.
  /// Il microfono cattura audio in continuo tramite startStream().
  /// Ogni ~3 secondi di audio accumulato viene processato (trascritto + tradotto).
  /// NON ci sono gap: il microfono resta sempre acceso.
  Future<void> startStreaming() async {
    if (_streamingActive) {
      AppLogger.warning(_tag, 'Streaming gia\' attivo');
      return;
    }

    AppLogger.info(_tag, '=== AVVIO STREAMING LIVE ===');

    // Inizializza TTS per la modalita' speech
    if (state.mode == AppMode.speech) {
      try {
        await _ttsService.init(
          languageCode: _targetLanguage.nllbCode,
          speed: 1.0,
        );
      } catch (e) {
        AppLogger.error(_tag, 'Errore init TTS (continuiamo senza)', e);
      }
    }

    _streamingActive = true;
    _isProcessingChunk = false;
    _chunkQueue.clear();

    state = state.copyWith(
      phase: PipelinePhase.listening,
      isStreaming: true,
      segments: [],
      currentTranscription: null,
      currentTranslation: null,
      errorMessage: null,
    );

    try {
      // Avvia lo streaming audio continuo
      // Il callback onChunkReady viene chiamato ogni volta che si accumulano
      // abbastanza byte PCM per un chunk di kStreamingChunkDurationSec secondi
      await _audioService.startStreaming(
        onChunkReady: _onAudioChunkReady,
        chunkDurationSec: kStreamingChunkDurationSec,
      );

      AppLogger.info(_tag, 'Streaming audio avviato con successo');
    } catch (e) {
      AppLogger.error(_tag, 'Errore avvio streaming', e);
      _streamingActive = false;
      state = PipelineState.error(
          'Errore avvio microfono: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// Callback chiamato dall'AudioService quando un chunk audio e' pronto.
  /// Aggiunge il chunk alla coda e avvia il processing se non e' in corso.
  void _onAudioChunkReady(List<double> samples) {
    if (!_streamingActive) return;

    AppLogger.debug(_tag,
        'Chunk audio ricevuto: ${samples.length} campioni '
        '(${(samples.length / kAudioSampleRate).toStringAsFixed(1)}s)');

    // Aggiungi alla coda
    _chunkQueue.add(samples);

    // Se non stiamo gia' processando un chunk, avvia il processing
    if (!_isProcessingChunk) {
      _processNextChunk();
    }
  }

  /// Processa il prossimo chunk dalla coda.
  /// Usa un lock per evitare processing concorrente.
  Future<void> _processNextChunk() async {
    if (_isProcessingChunk || _chunkQueue.isEmpty || !_streamingActive) {
      return;
    }

    _isProcessingChunk = true;

    try {
      // Prendi il prossimo chunk dalla coda
      final samples = _chunkQueue.removeFirst();

      // Ignora chunk troppo corti (meno di 0.5 secondi)
      if (samples.length < kAudioSampleRate ~/ 2) {
        AppLogger.debug(_tag, 'Chunk troppo corto, skip');
        _isProcessingChunk = false;
        _processNextChunk(); // Processa il prossimo
        return;
      }

      // --- FASE 1: TRASCRIZIONE con Whisper ---
      if (mounted) {
        state = state.copyWith(phase: PipelinePhase.transcribing);
      }

      final modelsPath = await _downloadService.getModelsBasePath();
      final whisperModel = findWhisperModelById(_selectedWhisperModelId);
      final whisperFileName =
          whisperModel?.fileConfig.fileName ?? 'ggml-small.bin';
      final whisperModelPath = '$modelsPath/whisper/$whisperFileName';

      final langCode = _sourceLanguage.nllbCode == 'auto'
          ? null
          : _sourceLanguage.whisperCode;

      String transcribedText;
      String detectedLang = '';

      try {
        final transcription = await WhisperFFI.transcribeInIsolate(
          libraryPath: 'libwhisper.so',
          modelPath: whisperModelPath,
          audioSamples: samples,
          languageCode: langCode,
        );
        transcribedText = transcription.text.trim();
        detectedLang = transcription.detectedLanguage;
      } catch (e) {
        // Se Whisper FFI fallisce (libreria non disponibile), mostra errore chiaro
        final errorMsg = e.toString();
        AppLogger.error(_tag, 'Errore Whisper FFI', e);

        if (errorMsg.contains('Failed to lookup') ||
            errorMsg.contains('Failed to load') ||
            errorMsg.contains('dlopen')) {
          // Libreria nativa non trovata - errore critico
          if (mounted) {
            state = state.copyWith(
              phase: PipelinePhase.error,
              errorMessage:
                  'Libreria whisper.cpp non trovata. '
                  'Le librerie native (libwhisper.so) devono essere compilate '
                  'con Android NDK e incluse nell\'APK. '
                  'Consulta il README per le istruzioni di build.',
            );
          }
          _isProcessingChunk = false;
          return;
        }

        // Altro errore (modello non trovato, ecc.)
        if (mounted) {
          state = state.copyWith(
            phase: PipelinePhase.error,
            errorMessage: 'Errore trascrizione: ${e.toString().substring(0, (e.toString().length).clamp(0, 150))}',
          );
        }
        _isProcessingChunk = false;
        return;
      }

      // Se la trascrizione e' vuota, skip
      if (transcribedText.isEmpty) {
        AppLogger.debug(_tag, 'Trascrizione vuota, skip');
        _isProcessingChunk = false;
        if (mounted && _streamingActive) {
          state = state.copyWith(phase: PipelinePhase.listening);
        }
        _processNextChunk();
        return;
      }

      AppLogger.info(_tag, 'Trascritto: "$transcribedText"');

      if (mounted) {
        state = state.copyWith(
          currentTranscription: transcribedText,
          detectedLanguage: detectedLang,
        );
      }

      // --- FASE 2: TRADUZIONE con NLLB-200 ---
      if (mounted) {
        state = state.copyWith(phase: PipelinePhase.translating);
      }

      final nllbModelDir = '$modelsPath/nllb';

      // Determina lingua sorgente per NLLB
      String srcLangCode;
      if (_sourceLanguage.nllbCode == 'auto' && detectedLang.isNotEmpty) {
        final detected = findLanguageByWhisperCode(detectedLang);
        srcLangCode = detected?.nllbCode ?? 'eng_Latn';
      } else {
        srcLangCode = _sourceLanguage.nllbCode;
      }

      String translatedText;

      try {
        translatedText = await OnnxFFI.translateInIsolate(
          libraryPath: 'libonnxruntime.so',
          modelDir: nllbModelDir,
          inputText: transcribedText,
          sourceLanguageCode: srcLangCode,
          targetLanguageCode: _targetLanguage.nllbCode,
        );
      } catch (e) {
        final errorMsg = e.toString();
        AppLogger.error(_tag, 'Errore ONNX FFI', e);

        if (errorMsg.contains('Failed to lookup') ||
            errorMsg.contains('Failed to load') ||
            errorMsg.contains('dlopen')) {
          if (mounted) {
            state = state.copyWith(
              phase: PipelinePhase.error,
              errorMessage:
                  'Libreria ONNX Runtime non trovata. '
                  'libonnxruntime.so deve essere compilata e inclusa nell\'APK. '
                  'Consulta il README per le istruzioni di build.',
            );
          }
          _isProcessingChunk = false;
          return;
        }

        if (mounted) {
          state = state.copyWith(
            phase: PipelinePhase.error,
            errorMessage: 'Errore traduzione: ${e.toString().substring(0, (e.toString().length).clamp(0, 150))}',
          );
        }
        _isProcessingChunk = false;
        return;
      }

      AppLogger.info(_tag, 'Tradotto: "$translatedText"');

      // Aggiungi il segmento alla lista
      final segment = TranslatedSegment(
        transcribedText: transcribedText,
        translatedText: translatedText,
        timestamp: DateTime.now(),
      );

      final updatedSegments = [...state.segments, segment];

      if (mounted) {
        state = state.copyWith(
          segments: updatedSegments,
          currentTranscription: transcribedText,
          currentTranslation: translatedText,
          phase: PipelinePhase.listening,
        );
      }

      // --- FASE 3: TTS (solo modalita' speech) ---
      if (state.mode == AppMode.speech && translatedText.isNotEmpty) {
        if (mounted) {
          state = state.copyWith(phase: PipelinePhase.speaking);
        }
        try {
          await _ttsService.speak(translatedText);
        } catch (e) {
          AppLogger.error(_tag, 'Errore TTS (continuiamo)', e);
        }
        if (mounted && _streamingActive) {
          state = state.copyWith(phase: PipelinePhase.listening);
        }
      }
    } catch (e) {
      AppLogger.error(_tag, 'Errore processamento chunk', e);
      // Non interrompere lo streaming per un singolo errore di chunk
      if (mounted && _streamingActive) {
        state = state.copyWith(
          phase: PipelinePhase.listening,
          errorMessage: 'Errore: ${e.toString().substring(0, (e.toString().length).clamp(0, 100))}',
        );
      }
    } finally {
      _isProcessingChunk = false;

      // Se ci sono altri chunk in coda, processali
      if (_streamingActive && _chunkQueue.isNotEmpty) {
        _processNextChunk();
      }
    }
  }

  // ============================================================
  // STOP STREAMING
  // ============================================================

  /// Ferma lo streaming e salva nella cronologia
  Future<void> stopStreaming() async {
    if (!_streamingActive) return;

    AppLogger.info(_tag, '=== STOP STREAMING ===');
    _streamingActive = false;

    // Ferma lo streaming audio
    await _audioService.stopStreaming();

    // Ferma il TTS se sta parlando
    await _ttsService.stop();

    // Pulisci la coda
    _chunkQueue.clear();

    state = state.copyWith(
      phase: PipelinePhase.idle,
      isStreaming: false,
    );

    // Salva nella cronologia se ci sono segmenti
    if (state.segments.isNotEmpty) {
      await _saveToHistory();
    }

    AppLogger.info(_tag, 'Streaming fermato. Segmenti: ${state.segments.length}');
  }

  // ============================================================
  // CRONOLOGIA
  // ============================================================

  /// Salva il risultato nella cronologia
  Future<void> _saveToHistory() async {
    if (state.segments.isEmpty) return;

    AppLogger.info(_tag, 'Salvataggio in cronologia...');

    String srcLangCode = _sourceLanguage.nllbCode;
    String srcLangName = _sourceLanguage.nameIt;

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
      rawText: state.fullTranscription,
      translatedText: state.fullTranslation,
    );

    try {
      await _historyRepository.add(entry);
      AppLogger.info(_tag, 'Salvato in cronologia: ${entry.id}');
    } catch (e) {
      AppLogger.error(_tag, 'Errore salvataggio cronologia', e);
    }
  }

  // ============================================================
  // RESET
  // ============================================================

  /// Resetta la pipeline allo stato iniziale
  void reset() {
    AppLogger.info(_tag, 'Reset pipeline');
    _streamingActive = false;
    _isProcessingChunk = false;
    _chunkQueue.clear();
    state = PipelineState.initial(mode: state.mode);
  }
}
