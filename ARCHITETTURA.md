# Architettura VoiceTranslate v2.1

## Panoramica

VoiceTranslate e' un'app Flutter per Android che esegue trascrizione e traduzione vocale **in streaming live**, completamente offline dopo il download iniziale dei modelli.

**Due modalita':**
- **Sottotitoli**: traduzione mostrata come testo a schermo in tempo reale
- **Parlato**: traduzione pronunciata con TTS nativo Android

## Stack Ottimizzato

| Componente | Modello | Dimensione | Note |
|-----------|---------|-----------|------|
| Trascrizione STT | Whisper Tiny | ~75 MB | Velocissimo |
| Trascrizione STT | Whisper Small | ~466 MB | Buon compromesso (default) |
| Trascrizione STT | Whisper Medium | ~1.5 GB | Migliore accuratezza |
| Traduzione Encoder | NLLB-200 quantized | ~419 MB | ONNX quantizzato |
| Traduzione Decoder | NLLB-200 quantized | ~475 MB | ONNX quantizzato |
| Sintesi vocale | TTS nativo Android | 0 | Integrato nel sistema |

**Rimosso nella v2.0:** Phi-3 Mini / llama.cpp (correzione testo non piu' necessaria con Whisper Medium)

## Pipeline Streaming

```
[Microfono - chunk audio 3-4s]
       |
       v  (ogni 4 secondi)
[Whisper (tiny/small/medium) - STT]  <- Dart Isolate
       |
       v
[NLLB-200 ONNX quantized - Traduzione]  <- Dart Isolate
       |
       v
[Modalita' TEXT] -> Testo a schermo (sottotitoli live)
[Modalita' SPEECH] -> TTS nativo Android (parlato)
```

## Struttura del Progetto

```
voice_translate/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart     # Parametri streaming, download, audio
│   │   │   ├── model_config.dart      # 3 Whisper + NLLB-200 ONNX (URL Xenova)
│   │   │   └── languages.dart         # 50 lingue NLLB
│   │   ├── theme/app_theme.dart
│   │   ├── utils/
│   │   │   ├── logger.dart
│   │   │   └── permissions_helper.dart
│   │   └── errors/app_exceptions.dart
│   ├── domain/entities/
│   │   ├── pipeline_state.dart        # AppMode, PipelinePhase, TranslatedSegment
│   │   ├── download_state.dart
│   │   ├── translation_entry.dart
│   │   └── app_settings.dart          # + selectedWhisperModelId, ttsSpeed
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── whisper_ffi.dart       # FFI whisper.cpp (Isolate)
│   │   │   └── onnx_ffi.dart          # FFI ONNX Runtime (Isolate)
│   │   ├── services/
│   │   │   ├── download_service.dart  # Resume byte-level con IOSink streaming
│   │   │   ├── audio_service.dart
│   │   │   └── tts_service.dart       # TTS nativo Android
│   │   └── repositories/
│   │       ├── history_repository.dart
│   │       └── settings_repository.dart
│   └── presentation/
│       ├── providers/
│       │   ├── app_providers.dart      # + TTS provider
│       │   ├── download_provider.dart
│       │   ├── pipeline_provider.dart  # Streaming + Whisper model selection
│       │   └── history_provider.dart
│       ├── router/app_router.dart
│       ├── screens/
│       │   ├── download_screen.dart
│       │   ├── home_screen.dart        # Toggle TEXT/SPEECH
│       │   ├── settings_screen.dart    # Whisper model cards + TTS speed
│       │   └── error_screen.dart
│       └── widgets/
│           ├── download_progress_card.dart
│           ├── recording_button.dart
│           ├── text_result_card.dart
│           ├── language_selector.dart
│           ├── phase_indicator.dart
│           └── history_list.dart
├── android/app/src/main/
│   ├── AndroidManifest.xml
│   └── cpp/
│       ├── CMakeLists.txt             # Solo whisper.cpp
│       └── whisper_cpp/               # [SUBMODULE]
└── DA CANCELLARE/                     # Codice morto (llama_ffi, llama_wrapper)
```

## Download Robusto (v2.1)

- **URL corretti**: NLLB-200 ONNX dal repo `Xenova/nllb-200-distilled-600M`
- **Resume byte-level**: `IOSink` in append + header `Range: bytes=X-`
- **Timeout 30 minuti** per file grandi (era 60s, causava blocchi)
- **maxRedirects 10** per HuggingFace CDN
- **Retry backoff esponenziale**: 2, 4, 8, 16, 32 secondi (max 5 tentativi)
- **Streaming manuale**: non usa `dio.download()` che si bloccava

## Selezione Modello Whisper (v2.1)

L'utente puo' scegliere tra 3 modelli Whisper nelle impostazioni:
- **Tiny** (~75 MB): velocissimo, per test rapidi
- **Small** (~466 MB): buon compromesso velocita'/accuratezza (default)
- **Medium** (~1.5 GB): migliore accuratezza, consigliato

Ogni modello mostra rating di velocita' (bolt) e accuratezza (star).
La selezione e' persistente e sincronizzata col pipeline.

## Stato Implementazione

- [x] Streaming live con chunk audio 3-4s
- [x] Due modalita' (sottotitoli + parlato TTS)
- [x] 3 modelli Whisper selezionabili dall'utente
- [x] Download robusto byte-level con URL corretti
- [x] 50 lingue NLLB con auto-detect
- [x] Cronologia 20 voci con Hive
- [x] TTS nativo Android con velocita' configurabile
- [ ] Clonare whisper.cpp come submodule + compilare NDK
- [ ] Integrare ONNX Runtime .so
- [ ] Test end-to-end su device ARM64
