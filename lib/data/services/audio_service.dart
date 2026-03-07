/// Servizio audio con DUE modalita':
/// 1. Streaming continuo: cattura PCM in tempo reale senza gap (per live translate)
/// 2. File recording: registra su file WAV (legacy, per batch processing)
///
/// Lo streaming usa AudioRecorder.startStream() che restituisce un flusso
/// continuo di byte PCM 16kHz mono 16-bit. I byte vengono accumulati in un
/// buffer e quando raggiungono la durata di un chunk (~3-4s), viene emesso
/// un callback con i campioni float32 pronti per Whisper.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:voice_translate/core/constants/app_constants.dart';
import 'package:voice_translate/core/errors/app_exceptions.dart';
import 'package:voice_translate/core/utils/logger.dart';

/// Tag per i log di questo modulo
const String _tag = 'AudioService';

/// Callback che riceve un chunk di campioni float32 pronti per Whisper
typedef AudioChunkCallback = void Function(List<double> samples);

/// Tipo callback senza parametri (evita import di flutter nel data layer)
typedef OnVoidAction = void Function();

/// Servizio audio con streaming continuo e file recording
class AudioService {
  /// Recorder instance
  final AudioRecorder _recorder = AudioRecorder();

  /// Se lo streaming e' attivo
  bool _isStreaming = false;

  /// Se la registrazione file e' in corso
  bool _isRecording = false;

  /// Subscription allo stream audio
  StreamSubscription<List<int>>? _streamSubscription;

  /// Buffer per accumulare byte PCM durante lo streaming
  final BytesBuilder _pcmBuffer = BytesBuilder(copy: false);

  /// Numero di byte PCM per un chunk (3 secondi a 16kHz mono 16-bit = 96000 bytes)
  int _chunkSizeBytes = kStreamingChunkDurationSec * kAudioSampleRate * 2;

  /// Percorso del file audio corrente (per file recording)
  String? _currentFilePath;

  AudioService() {
    AppLogger.info(_tag, 'AudioService inizializzato');
  }

  // ============================================================
  // PERMESSI
  // ============================================================

  /// Verifica se il microfono e' disponibile e ha i permessi
  Future<bool> isMicrophoneAvailable() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      AppLogger.debug(_tag, 'Permesso microfono: $hasPermission');
      return hasPermission;
    } catch (e) {
      AppLogger.error(_tag, 'Errore verifica microfono', e);
      return false;
    }
  }

  // ============================================================
  // MODALITA' 1: STREAMING CONTINUO (per live translate)
  // ============================================================

  /// Avvia lo streaming audio continuo.
  /// Cattura PCM 16kHz mono 16-bit senza interruzioni.
  /// Ogni volta che si accumula un chunk di [chunkDurationSec] secondi,
  /// viene chiamato [onChunkReady] con i campioni float32.
  Future<void> startStreaming({
    required AudioChunkCallback onChunkReady,
    int chunkDurationSec = kStreamingChunkDurationSec,
  }) async {
    if (_isStreaming) {
      AppLogger.warning(_tag, 'Streaming gia\' attivo, ignorato');
      return;
    }

    AppLogger.info(_tag, 'Avvio streaming audio continuo...');

    // Verifica permessi
    if (!await _recorder.hasPermission()) {
      throw const AudioRecordingException(
          'Permesso microfono non concesso');
    }

    // Calcola dimensione chunk in byte
    // PCM 16-bit mono: 2 byte per campione, 16000 campioni/sec
    _chunkSizeBytes = chunkDurationSec * kAudioSampleRate * 2;
    AppLogger.debug(_tag,
        'Chunk size: $_chunkSizeBytes bytes ($chunkDurationSec secondi)');

    // Reset buffer
    _pcmBuffer.clear();

    // Configura la registrazione in streaming
    // PCM 16kHz mono 16-bit - formato nativo per Whisper
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: kAudioSampleRate,
      numChannels: kAudioChannels,
      // Auto encoder per migliore compatibilita'
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );

    // Avvia lo stream audio
    final stream = await _recorder.startStream(config);
    _isStreaming = true;

    AppLogger.info(_tag, 'Stream audio avviato (PCM 16kHz mono 16-bit)');

    // Ascolta lo stream e accumula byte nel buffer
    _streamSubscription = stream.listen(
      (List<int> pcmBytes) {
        if (!_isStreaming) return;

        // Aggiungi i byte al buffer
        _pcmBuffer.add(Uint8List.fromList(pcmBytes));

        // Se il buffer ha raggiunto la dimensione del chunk, emetti
        if (_pcmBuffer.length >= _chunkSizeBytes) {
          final chunkBytes = _pcmBuffer.takeBytes();
          AppLogger.debug(_tag,
              'Chunk audio pronto: ${chunkBytes.length} bytes '
              '(${chunkBytes.length / (kAudioSampleRate * 2)} secondi)');

          // Converti PCM 16-bit in float32 per Whisper
          final samples = _pcm16ToFloat32(chunkBytes);

          // Emetti il chunk al chiamante
          onChunkReady(samples);
        }
      },
      onError: (error) {
        AppLogger.error(_tag, 'Errore stream audio', error);
      },
      onDone: () {
        AppLogger.info(_tag, 'Stream audio terminato');
        _isStreaming = false;
      },
    );
  }

  /// Ferma lo streaming audio continuo
  Future<void> stopStreaming() async {
    if (!_isStreaming) {
      AppLogger.debug(_tag, 'Streaming non attivo');
      return;
    }

    AppLogger.info(_tag, 'Stop streaming audio...');

    _isStreaming = false;

    // Cancella la subscription
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    // Ferma il recorder
    await _recorder.stop();

    // Processa eventuali byte rimasti nel buffer
    final remainingBytes = _pcmBuffer.takeBytes();
    AppLogger.info(_tag,
        'Streaming fermato. Byte rimasti nel buffer: ${remainingBytes.length}');

    // Pulisci il buffer
    _pcmBuffer.clear();
  }

  /// Se lo streaming e' attivo
  bool get isStreaming => _isStreaming;

  // ============================================================
  // MODALITA' 2: FILE RECORDING (legacy, per batch processing)
  // ============================================================

  /// Avvia la registrazione audio su file WAV
  Future<void> startRecording({
    required OnVoidAction onMaxDurationReached,
  }) async {
    if (_isRecording) {
      AppLogger.warning(_tag, 'Registrazione gia\' in corso, ignorata');
      return;
    }

    AppLogger.info(_tag, 'Avvio registrazione su file...');

    if (!await _recorder.hasPermission()) {
      throw const AudioRecordingException(
          'Permesso microfono non concesso');
    }

    final tempDir = await getTemporaryDirectory();
    _currentFilePath = p.join(tempDir.path,
        'recording_${DateTime.now().millisecondsSinceEpoch}.wav');

    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: kAudioSampleRate,
      numChannels: kAudioChannels,
      bitRate: kAudioSampleRate * kAudioBitDepth * kAudioChannels,
    );

    await _recorder.start(config, path: _currentFilePath!);
    _isRecording = true;
    AppLogger.info(_tag, 'Registrazione su file avviata: $_currentFilePath');
  }

  /// Ferma la registrazione file e restituisce il percorso WAV
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    final path = await _recorder.stop();
    _isRecording = false;

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        final fileSize = await file.length();
        AppLogger.info(_tag, 'Registrazione salvata: $path ($fileSize bytes)');
        return path;
      }
    }

    return _currentFilePath;
  }

  /// Se la registrazione file e' in corso
  bool get isRecording => _isRecording;

  // ============================================================
  // CONVERSIONE AUDIO
  // ============================================================

  /// Cerca l'offset del sub-chunk "data" in un file WAV.
  /// Non assume che sia sempre a 44 byte: cerca il marker 'data' nel header.
  int _findWavDataOffset(Uint8List bytes) {
    for (var i = 12; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x64 &&
          bytes[i + 1] == 0x61 &&
          bytes[i + 2] == 0x74 &&
          bytes[i + 3] == 0x61) {
        return i + 8;
      }
    }
    AppLogger.warning(_tag, 'Marker "data" non trovato nel WAV, uso offset 44');
    return 44;
  }

  /// Converte byte PCM 16-bit signed little-endian in campioni float32.
  /// Input: byte grezzi PCM 16kHz mono 16-bit.
  /// Output: `List<double>` con valori in `[-1.0, 1.0]`.
  List<double> _pcm16ToFloat32(Uint8List pcmBytes) {
    final numSamples = pcmBytes.length ~/ 2;
    final samples = List<double>.filled(numSamples, 0.0);
    final byteData = ByteData.sublistView(pcmBytes);

    for (var i = 0; i < numSamples; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      samples[i] = sample / 32768.0;
    }

    return samples;
  }

  /// Converte un file WAV in campioni float32 normalizzati per Whisper.
  /// Input: WAV 16kHz mono 16-bit.
  /// Output: `List<double>` con valori in `[-1.0, 1.0]`.
  Future<List<double>> wavToFloat32Samples(String wavPath) async {
    AppLogger.info(_tag, 'Conversione WAV -> float32: $wavPath');

    final file = File(wavPath);
    if (!await file.exists()) {
      throw AudioRecordingException('File WAV non trovato: $wavPath');
    }

    final bytes = await file.readAsBytes();

    if (bytes.length < 44) {
      throw const AudioRecordingException(
          'File WAV troppo piccolo (header invalido)');
    }

    // Verifica magic "RIFF"
    if (bytes[0] != 0x52 || bytes[1] != 0x49 ||
        bytes[2] != 0x46 || bytes[3] != 0x46) {
      throw const AudioRecordingException(
          'File non e\' in formato WAV (magic RIFF mancante)');
    }

    // Cerca il sub-chunk "data" nel WAV (l'offset non è sempre 44)
    final dataOffset = _findWavDataOffset(bytes);
    final pcmBytes = Uint8List.sublistView(bytes, dataOffset);

    final samples = _pcm16ToFloat32(pcmBytes);
    AppLogger.info(_tag,
        'Conversione completata: ${samples.length} campioni float32');
    return samples;
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  /// Rilascia le risorse
  Future<void> dispose() async {
    AppLogger.info(_tag, 'Rilascio risorse AudioService...');
    if (_isStreaming) {
      await stopStreaming();
    }
    if (_isRecording) {
      await _recorder.stop();
    }
    _recorder.dispose();
    AppLogger.info(_tag, 'AudioService disposed');
  }
}
