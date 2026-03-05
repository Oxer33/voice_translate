/// Provider per la pipeline di elaborazione vocale streaming.
/// Coordina il flusso live: ascolto continuo -> trascrizione chunk -> traduzione -> TTS.
/// Supporta due modalità: TEXT (sottotitoli a schermo) e SPEECH (traduzione parlata).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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

/// Notifier per la gestione della pipeline streaming
class PipelineNotifier extends StateNotifier<PipelineState> {
  final AudioService _audioService;
  final DownloadService _downloadService;
  final TtsService _ttsService;
  final HistoryRepository _historyRepository;

  /// Lingua sorgente selezionata
  SupportedLanguage _sourceLanguage = kAutoDetectLanguage;

  /// Lingua target selezionata
  SupportedLanguage _targetLanguage = kSupportedLanguages[1]; // Inglese

  /// Timer per il chunk streaming
  Timer? _chunkTimer;

  /// Se lo streaming e' attivo
  bool _streamingActive = false;

  /// ID del modello Whisper selezionato
  String _selectedWhisperModelId = kDefaultWhisperModelId;

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

  /// Imposta la lingua sorgente
  void setSourceLanguage(SupportedLanguage lang) {
    AppLogger.info(_tag, 'Lingua sorgente: ${lang.nameIt}');
    _sourceLanguage = lang;
  }

  /// Imposta la lingua target
  void setTargetLanguage(SupportedLanguage lang) {
    AppLogger.info(_tag, 'Lingua target: ${lang.nameIt}');
    _targetLanguage = lang;
    // Aggiorna anche la lingua TTS
    _ttsService.setLanguage(lang.nllbCode);
  }

  /// Cambia la modalita' dell'app (TEXT o SPEECH)
  void setMode(AppMode mode) {
    AppLogger.info(_tag, 'Modalita\' cambiata: ${modeDisplayName(mode)}');
    state = state.copyWith(mode: mode);
  }

  /// Getter per lingua sorgente corrente
  SupportedLanguage get sourceLanguage => _sourceLanguage;

  /// Getter per lingua target corrente
  SupportedLanguage get targetLanguage => _targetLanguage;

  /// Imposta il modello Whisper da usare
  void setWhisperModel(String modelId) {
    AppLogger.info(_tag, 'Modello Whisper: $modelId');
    _selectedWhisperModelId = modelId;
  }

  /// Avvia lo streaming live (ascolto continuo + trascrizione + traduzione)
  Future<void> startStreaming() async {
    if (_streamingActive) {
      AppLogger.warning(_tag, 'Streaming gia\' attivo');
      return;
    }

    AppLogger.info(_tag, 'Avvio streaming live...');

    // Inizializza TTS per la modalita' speech
    if (state.mode == AppMode.speech) {
      await _ttsService.init(
        languageCode: _targetLanguage.nllbCode,
        speed: 1.0,
      );
    }

    _streamingActive = true;
    state = state.copyWith(
      phase: PipelinePhase.listening,
      isStreaming: true,
      segments: [],
      currentTranscription: null,
      currentTranslation: null,
      errorMessage: null,
    );

    try {
      // Avvia la registrazione audio continua
      await _audioService.startRecording(
        onCountdown: (_) {
          // Nello streaming non usiamo countdown
        },
        onAmplitude: (_) {
          // Ampiezza gestita internamente
        },
        onSilenceDetected: () {
          // Nello streaming il silenzio non ferma, fa solo una pausa
          AppLogger.debug(_tag, 'Silenzio rilevato (streaming continua)');
        },
        onMaxDurationReached: () {
          // Nello streaming non c'e' durata massima, ricicliamo
          AppLogger.info(_tag, 'Durata massima chunk, riavvio registrazione');
          _processCurrentChunk();
        },
      );

      // Avvia timer per processare chunk ogni 3-5 secondi
      _chunkTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _processCurrentChunk(),
      );

      AppLogger.info(_tag, 'Streaming avviato con successo');
    } catch (e) {
      AppLogger.error(_tag, 'Errore avvio streaming', e);
      _streamingActive = false;
      state = PipelineState.error('Errore avvio: $e');
    }
  }

  /// Ferma lo streaming e salva nella cronologia
  Future<void> stopStreaming() async {
    if (!_streamingActive) return;

    AppLogger.info(_tag, 'Stop streaming...');
    _streamingActive = false;
    _chunkTimer?.cancel();
    _chunkTimer = null;

    // Processa l'ultimo chunk se disponibile
    await _processCurrentChunk();

    // Ferma la registrazione
    await _audioService.stopRecording();

    // Ferma il TTS se sta parlando
    await _ttsService.stop();

    state = state.copyWith(
      phase: PipelinePhase.idle,
      isStreaming: false,
    );

    // Salva nella cronologia se ci sono segmenti
    if (state.segments.isNotEmpty) {
      await _saveToHistory();
    }

    AppLogger.info(_tag, 'Streaming fermato');
  }

  /// Processa il chunk audio corrente (trascrivi + traduci)
  Future<void> _processCurrentChunk() async {
    if (!_streamingActive) return;

    try {
      // Ferma brevemente la registrazione per ottenere il file
      final audioPath = await _audioService.stopRecording();
      if (audioPath == null) {
        // Nessun audio, riavvia la registrazione
        if (_streamingActive) {
          await _restartRecording();
        }
        return;
      }

      // Converti l'audio in campioni float32
      final samples = await _audioService.wavToFloat32Samples(audioPath);
      if (samples.length < 1600) {
        // Meno di 0.1 secondi, troppo corto
        AppLogger.debug(_tag, 'Chunk troppo corto, skip');
        if (_streamingActive) {
          await _restartRecording();
        }
        return;
      }

      // --- TRASCRIZIONE ---
      if (mounted) {
        state = state.copyWith(phase: PipelinePhase.transcribing);
      }

      final modelsPath = await _downloadService.getModelsBasePath();
      // Usa il modello Whisper selezionato dall'utente
      final whisperModel = findWhisperModelById(_selectedWhisperModelId);
      final whisperFileName = whisperModel?.fileConfig.fileName ?? 'ggml-small.bin';
      final whisperModelPath = '$modelsPath/whisper/$whisperFileName';

      final langCode = _sourceLanguage.nllbCode == 'auto'
          ? null
          : _sourceLanguage.whisperCode;

      final transcription = await WhisperFFI.transcribeInIsolate(
        libraryPath: 'libwhisper.so',
        modelPath: whisperModelPath,
        audioSamples: samples,
        languageCode: langCode,
      );

      if (transcription.text.trim().isEmpty) {
        AppLogger.debug(_tag, 'Trascrizione vuota, skip');
        if (_streamingActive) {
          await _restartRecording();
        }
        return;
      }

      AppLogger.info(_tag, 'Trascritto: "${transcription.text}"');

      if (mounted) {
        state = state.copyWith(
          currentTranscription: transcription.text,
          detectedLanguage: transcription.detectedLanguage,
        );
      }

      // --- TRADUZIONE ---
      if (mounted) {
        state = state.copyWith(phase: PipelinePhase.translating);
      }

      final nllbModelDir = '$modelsPath/nllb';

      // Determina lingua sorgente per NLLB
      String srcLangCode;
      if (_sourceLanguage.nllbCode == 'auto' &&
          transcription.detectedLanguage.isNotEmpty) {
        final detected =
            findLanguageByWhisperCode(transcription.detectedLanguage);
        srcLangCode = detected?.nllbCode ?? 'eng_Latn';
      } else {
        srcLangCode = _sourceLanguage.nllbCode;
      }

      final translated = await OnnxFFI.translateInIsolate(
        libraryPath: 'libonnxruntime.so',
        modelDir: nllbModelDir,
        inputText: transcription.text,
        sourceLanguageCode: srcLangCode,
        targetLanguageCode: _targetLanguage.nllbCode,
      );

      AppLogger.info(_tag, 'Tradotto: "$translated"');

      // Aggiungi il segmento alla lista
      final segment = TranslatedSegment(
        transcribedText: transcription.text,
        translatedText: translated,
        timestamp: DateTime.now(),
      );

      final updatedSegments = [...state.segments, segment];

      if (mounted) {
        state = state.copyWith(
          segments: updatedSegments,
          currentTranscription: transcription.text,
          currentTranslation: translated,
          phase: PipelinePhase.listening,
        );
      }

      // --- TTS (solo modalita' speech) ---
      if (state.mode == AppMode.speech && translated.isNotEmpty) {
        if (mounted) {
          state = state.copyWith(phase: PipelinePhase.speaking);
        }
        await _ttsService.speak(translated);
        if (mounted) {
          state = state.copyWith(phase: PipelinePhase.listening);
        }
      }

      // Riavvia la registrazione per il prossimo chunk
      if (_streamingActive) {
        await _restartRecording();
      }
    } catch (e) {
      AppLogger.error(_tag, 'Errore processamento chunk', e);
      // Non interrompere lo streaming per un singolo errore di chunk
      if (_streamingActive && mounted) {
        state = state.copyWith(phase: PipelinePhase.listening);
        await _restartRecording();
      }
    }
  }

  /// Riavvia la registrazione dopo aver processato un chunk
  Future<void> _restartRecording() async {
    if (!_streamingActive) return;

    try {
      await _audioService.startRecording(
        onCountdown: (_) {},
        onAmplitude: (_) {},
        onSilenceDetected: () {},
        onMaxDurationReached: () {
          _processCurrentChunk();
        },
      );
    } catch (e) {
      AppLogger.error(_tag, 'Errore riavvio registrazione', e);
    }
  }

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

  /// Resetta la pipeline allo stato iniziale
  void reset() {
    AppLogger.info(_tag, 'Reset pipeline');
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _streamingActive = false;
    state = PipelineState.initial(mode: state.mode);
  }
}
