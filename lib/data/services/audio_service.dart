/// Servizio per la registrazione audio dal microfono.
/// Gestisce la registrazione WAV 16kHz mono 16-bit con rilevamento silenzio.
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

/// Callback per aggiornamento countdown
typedef CountdownCallback = void Function(int remainingSeconds);

/// Callback per livello ampiezza audio (per visualizzazione)
typedef AmplitudeCallback = void Function(double amplitude);

/// Servizio per la registrazione audio con rilevamento automatico del silenzio
class AudioService {
  /// Recorder instance
  final AudioRecorder _recorder = AudioRecorder();

  /// Timer per il countdown
  Timer? _countdownTimer;

  /// Timer per il controllo ampiezza (rilevamento silenzio)
  Timer? _amplitudeTimer;

  /// Durata del silenzio continuo rilevato (in intervalli di 200ms)
  int _silenceCount = 0;

  /// Se la registrazione e' in corso
  bool _isRecording = false;

  /// Percorso del file audio corrente
  String? _currentFilePath;

  /// Sensibilita' del rilevamento silenzio
  double _silenceSensitivity = kDefaultSilenceSensitivity;

  AudioService() {
    AppLogger.info(_tag, 'AudioService inizializzato');
  }

  /// Verifica se il microfono e' disponibile
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

  /// Avvia la registrazione audio
  /// Registra in formato WAV 16kHz mono 16-bit
  Future<void> startRecording({
    required CountdownCallback onCountdown,
    required AmplitudeCallback onAmplitude,
    required OnVoidAction onSilenceDetected,
    required OnVoidAction onMaxDurationReached,
    double silenceSensitivity = kDefaultSilenceSensitivity,
  }) async {
    if (_isRecording) {
      AppLogger.warning(_tag, 'Registrazione gia\' in corso, ignorata');
      return;
    }

    _silenceSensitivity = silenceSensitivity;
    AppLogger.info(_tag, 'Avvio registrazione audio...');
    AppLogger.debug(_tag, 'Sensibilita\' silenzio: $_silenceSensitivity');

    // Verifica permessi
    if (!await _recorder.hasPermission()) {
      throw const AudioRecordingException(
          'Permesso microfono non concesso');
    }

    // Prepara il percorso del file di output
    final tempDir = await getTemporaryDirectory();
    _currentFilePath = p.join(tempDir.path,
        'recording_${DateTime.now().millisecondsSinceEpoch}.wav');
    AppLogger.debug(_tag, 'File output: $_currentFilePath');

    // Configura e avvia la registrazione
    // WAV 16kHz mono 16-bit come richiesto da Whisper
    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: kAudioSampleRate,
      numChannels: kAudioChannels,
      bitRate: kAudioSampleRate * kAudioBitDepth * kAudioChannels,
    );

    await _recorder.start(config, path: _currentFilePath!);
    _isRecording = true;
    _silenceCount = 0;

    AppLogger.info(_tag, 'Registrazione avviata');

    // Timer countdown (ogni secondo)
    int remainingSeconds = kMaxRecordingDurationSec;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      onCountdown(remainingSeconds);

      if (remainingSeconds <= 0) {
        AppLogger.info(_tag, 'Durata massima raggiunta ($kMaxRecordingDurationSec s)');
        timer.cancel();
        onMaxDurationReached();
      }
    });

    // Timer rilevamento ampiezza e silenzio (ogni 200ms)
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      try {
        final amplitude = await _recorder.getAmplitude();
        // amplitude.current e' in dBFS (negativo, 0 = max volume)
        // Normalizziamo a 0.0 - 1.0
        final normalizedAmp =
            ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
        onAmplitude(normalizedAmp);

        // Rilevamento silenzio: se l'ampiezza e' sotto la soglia
        if (normalizedAmp < _silenceSensitivity) {
          _silenceCount++;
          // 2 secondi di silenzio = 10 intervalli da 200ms
          final silenceThresholdCount =
              (kSilenceThresholdSec * 1000 / 200).round();
          if (_silenceCount >= silenceThresholdCount) {
            AppLogger.info(_tag,
                'Silenzio rilevato dopo ${_silenceCount * 200}ms');
            onSilenceDetected();
          }
        } else {
          _silenceCount = 0;
        }
      } catch (e) {
        AppLogger.error(_tag, 'Errore lettura ampiezza', e);
      }
    });
  }

  /// Ferma la registrazione e restituisce il percorso del file WAV
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      AppLogger.warning(_tag, 'Nessuna registrazione in corso');
      return null;
    }

    AppLogger.info(_tag, 'Arresto registrazione...');

    // Ferma i timer
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _silenceCount = 0;

    // Ferma la registrazione
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

    AppLogger.warning(_tag, 'File di registrazione non trovato');
    return _currentFilePath;
  }

  /// Converte un file WAV in campioni float32 normalizzati per Whisper.
  /// Input: WAV 16kHz mono 16-bit.
  /// Output: `List<double>` con valori in `[-1.0, 1.0]`.
  Future<List<double>> wavToFloat32Samples(String wavPath) async {
    AppLogger.info(_tag, 'Conversione WAV -> float32: $wavPath');

    final file = File(wavPath);
    if (!await file.exists()) {
      throw AudioRecordingException(
          'File WAV non trovato: $wavPath');
    }

    final bytes = await file.readAsBytes();
    AppLogger.debug(_tag, 'File WAV letto: ${bytes.length} bytes');

    // Il formato WAV ha un header di 44 bytes
    // Verifica che sia un file WAV valido
    if (bytes.length < 44) {
      throw const AudioRecordingException(
          'File WAV troppo piccolo (header invalido)');
    }

    // Verifica magic "RIFF"
    if (bytes[0] != 0x52 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x46) {
      throw const AudioRecordingException(
          'File non e\' in formato WAV (magic RIFF mancante)');
    }

    // I campioni audio iniziano dopo l'header (offset 44 per WAV standard)
    // Ogni campione 16-bit e' 2 bytes, little-endian
    final dataOffset = 44;
    final dataLength = bytes.length - dataOffset;
    final numSamples = dataLength ~/ 2;

    AppLogger.debug(_tag, 'Campioni audio: $numSamples');

    final samples = List<double>.filled(numSamples, 0.0);
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

    for (var i = 0; i < numSamples; i++) {
      // Legge il campione 16-bit signed little-endian
      final sample = byteData.getInt16(dataOffset + (i * 2), Endian.little);
      // Normalizza a [-1.0, 1.0]
      samples[i] = sample / 32768.0;
    }

    AppLogger.info(_tag,
        'Conversione completata: $numSamples campioni float32');
    return samples;
  }

  /// Verifica se la registrazione e' in corso
  bool get isRecording => _isRecording;

  /// Rilascia le risorse
  Future<void> dispose() async {
    AppLogger.info(_tag, 'Rilascio risorse AudioService...');
    _countdownTimer?.cancel();
    _amplitudeTimer?.cancel();
    if (_isRecording) {
      await _recorder.stop();
    }
    _recorder.dispose();
    AppLogger.info(_tag, 'AudioService disposed');
  }
}

/// Tipo callback senza parametri (evita import di flutter nel data layer)
typedef OnVoidAction = void Function();
