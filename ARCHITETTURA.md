# Architettura VoiceTranslate v2.0

## Panoramica

VoiceTranslate e' un'app Flutter per Android che esegue trascrizione e traduzione vocale **in streaming live**, completamente offline dopo il download iniziale dei modelli.

**Due modalita':**
- **Sottotitoli**: traduzione mostrata come testo a schermo in tempo reale
- **Parlato**: traduzione pronunciata con TTS nativo Android

## Stack Ottimizzato

| Componente | Modello | Dimensione |
|-----------|---------|-----------|
| Trascrizione STT | Whisper Medium (ggml) | ~1.5 GB |
| Traduzione | NLLB-200 distilled 600M (ONNX) | ~1.2 GB |
| Sintesi vocale | TTS nativo Android | 0 (integrato) |

**Rimosso nella v2.0:** Phi-3 Mini / llama.cpp (correzione testo non piu' necessaria con Whisper Medium)

## Pipeline Streaming

```
[Microfono - chunk audio 3-4s]
       |
       v  (ogni 4 secondi)
[Whisper Medium - Trascrizione STT]  <- Dart Isolate
       |
       v
[NLLB-200 ONNX - Traduzione]  <- Dart Isolate
       |
       v
[Modalita' TEXT] -> Testo a schermo (sottotitoli live)
[Modalita' SPEECH] -> TTS nativo Android (parlato)
```

## Struttura del Progetto

```
voice_translate/
├── lib/
│   ├── main.dart                      # Entry point
│   ├── app.dart                       # Widget root, tema, router
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart     # Parametri streaming, download, audio
│   │   │   ├── model_config.dart      # URL modelli (Whisper Medium + NLLB)
│   │   │   └── languages.dart         # 50 lingue NLLB
│   │   ├── theme/app_theme.dart       # Tema scuro/chiaro
│   │   ├── utils/
│   │   │   ├── logger.dart            # Logger centralizzato
│   │   │   └── permissions_helper.dart
│   │   └── errors/app_exceptions.dart
│   │
│   ├── domain/entities/
│   │   ├── pipeline_state.dart        # AppMode (TEXT/SPEECH), PipelinePhase, TranslatedSegment
│   │   ├── download_state.dart        # Stato download modelli
│   │   ├── translation_entry.dart     # Voce cronologia
│   │   └── app_settings.dart          # Impostazioni (showTranscription, ttsSpeed, lastMode)
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── whisper_ffi.dart       # FFI whisper.cpp (Isolate)
│   │   │   └── onnx_ffi.dart          # FFI ONNX Runtime (Isolate)
│   │   ├── services/
│   │   │   ├── download_service.dart  # Download robusto byte-level con resume
│   │   │   ├── audio_service.dart     # Registrazione WAV 16kHz
│   │   │   └── tts_service.dart       # Text-to-Speech nativo Android
│   │   └── repositories/
│   │       ├── history_repository.dart
│   │       └── settings_repository.dart
│   │
│   └── presentation/
│       ├── providers/
│       │   ├── app_providers.dart      # Provider centrali (servizi, TTS, repo)
│       │   ├── download_provider.dart  # Stato download
│       │   ├── pipeline_provider.dart  # Pipeline streaming live
│       │   └── history_provider.dart
│       ├── router/app_router.dart
│       ├── screens/
│       │   ├── download_screen.dart    # Setup iniziale
│       │   ├── home_screen.dart        # Due modalita' con toggle
│       │   ├── settings_screen.dart    # Impostazioni + TTS speed
│       │   └── error_screen.dart
│       └── widgets/
│           ├── download_progress_card.dart
│           ├── recording_button.dart   # Pulsante streaming
│           ├── text_result_card.dart
│           ├── language_selector.dart
│           ├── phase_indicator.dart
│           └── history_list.dart
│
├── android/app/src/main/
│   ├── AndroidManifest.xml            # Permessi
│   └── cpp/
│       ├── CMakeLists.txt             # Solo whisper.cpp (llama rimosso)
│       └── whisper_cpp/               # [SUBMODULE]
│
└── DA CANCELLARE/                     # Codice morto (llama_ffi, llama_wrapper)
```

## Download Robusto

- **Resume byte-level**: usa `IOSink` in append + header `Range: bytes=X-`
- **Il file .tmp contiene esattamente i byte scaricati**: se l'app crasha, riprende da li'
- **Retry con backoff esponenziale**: 2, 4, 8, 16, 32 secondi (max 5 tentativi)
- **Streaming manuale**: non usa `dio.download()` che puo' bloccarsi

## Stato Implementazione

- [x] Architettura streaming con chunk audio 3-4s
- [x] Due modalita' (sottotitoli + parlato con TTS)
- [x] Download robusto con resume byte-level
- [x] 50 lingue NLLB con auto-detect
- [x] Cronologia 20 voci con Hive
- [x] TTS nativo Android con velocita' configurabile
- [x] UI con toggle modalita', selettori lingua, risultati live
- [ ] Clonare whisper.cpp come submodule
- [ ] Compilare e testare su ARM64
- [ ] Integrare ONNX Runtime .so
