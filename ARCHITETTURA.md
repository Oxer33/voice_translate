# Architettura VoiceTranslate

## Panoramica

VoiceTranslate e' un'app Flutter per Android che esegue trascrizione e traduzione vocale completamente offline.
Utilizza Clean Architecture con separazione netta tra data, domain e presentation layer.

## Struttura del Progetto

```
voice_translate/
├── android/
│   └── app/
│       ├── build.gradle.kts          # Config NDK 25+, CMake 3.22+, minSdk 26, arm64-v8a
│       └── src/main/
│           ├── AndroidManifest.xml    # Permessi: microfono, internet, notifiche
│           └── cpp/
│               ├── CMakeLists.txt     # Compilazione whisper.cpp e llama.cpp come .so
│               ├── llama_wrapper.cpp  # Wrapper C per FFI llama.cpp
│               ├── whisper_cpp/       # [SUBMODULE] github.com/ggerganov/whisper.cpp
│               └── llama_cpp/         # [SUBMODULE] github.com/ggerganov/llama.cpp
├── lib/
│   ├── main.dart                      # Entry point, init Hive/Logger
│   ├── app.dart                       # Widget root, tema, router, lifecycle
│   │
│   ├── core/                          # Layer trasversale
│   │   ├── constants/
│   │   │   ├── app_constants.dart     # Limiti, soglie, prompt correzione
│   │   │   ├── model_config.dart      # URL modelli, dimensioni, checksum
│   │   │   └── languages.dart         # 50 lingue NLLB con codici e nomi IT
│   │   ├── theme/
│   │   │   └── app_theme.dart         # Tema scuro/chiaro, colori, stili
│   │   ├── utils/
│   │   │   ├── logger.dart            # Logger centralizzato con livelli
│   │   │   └── permissions_helper.dart # Gestione permessi microfono/storage
│   │   └── errors/
│   │       └── app_exceptions.dart    # Eccezioni tipizzate per ogni modulo
│   │
│   ├── domain/                        # Layer business logic
│   │   └── entities/
│   │       ├── translation_entry.dart # Voce cronologia traduzione
│   │       ├── pipeline_state.dart    # Stato pipeline elaborazione
│   │       ├── download_state.dart    # Stato download modelli
│   │       └── app_settings.dart      # Impostazioni app persistenti
│   │
│   ├── data/                          # Layer dati e infrastruttura
│   │   ├── datasources/
│   │   │   ├── whisper_ffi.dart       # Binding FFI whisper.cpp (Isolate)
│   │   │   ├── llama_ffi.dart         # Binding FFI llama.cpp (Isolate)
│   │   │   └── onnx_ffi.dart          # Binding FFI ONNX Runtime (Isolate)
│   │   ├── services/
│   │   │   ├── download_service.dart  # Download modelli con resume/retry
│   │   │   └── audio_service.dart     # Registrazione audio WAV 16kHz
│   │   └── repositories/
│   │       ├── history_repository.dart    # Cronologia con Hive
│   │       └── settings_repository.dart   # Impostazioni con SharedPreferences
│   │
│   └── presentation/                  # Layer UI
│       ├── providers/
│       │   ├── app_providers.dart      # Provider centrali (servizi, repo)
│       │   ├── download_provider.dart  # Stato download modelli
│       │   ├── pipeline_provider.dart  # Pipeline registra->trascrivi->correggi->traduci
│       │   └── history_provider.dart   # Lista cronologia reattiva
│       ├── router/
│       │   └── app_router.dart         # Navigazione con go_router
│       ├── screens/
│       │   ├── download_screen.dart    # Setup iniziale, download modelli
│       │   ├── home_screen.dart        # Schermata principale
│       │   ├── settings_screen.dart    # Impostazioni app
│       │   └── error_screen.dart       # Errori con azioni suggerite
│       └── widgets/
│           ├── download_progress_card.dart  # Card progresso singolo download
│           ├── recording_button.dart        # Pulsante registrazione animato
│           ├── text_result_card.dart        # Card risultato con copia
│           ├── language_selector.dart       # Selettore lingua con ricerca
│           ├── phase_indicator.dart         # Indicatore fase pipeline
│           └── history_list.dart            # Lista cronologia traduzioni
├── pubspec.yaml                       # Dipendenze Flutter
└── README.md                          # Istruzioni build
```

## Pipeline di Elaborazione

```
[Audio Microfono - WAV 16kHz mono 16-bit]
       |
       v
[Whisper.cpp - Trascrizione STT]  <-- Dart Isolate separato
       |
       v
[Phi-3 Mini via llama.cpp - Correzione]  <-- Dart Isolate separato (opzionale)
       |
       v
[NLLB-200 via ONNX - Traduzione]  <-- Dart Isolate separato
       |
       v
[Risultato mostrato a schermo + salvato in cronologia]
```

## Tecnologie Principali

| Componente | Tecnologia | Note |
|-----------|-----------|------|
| Framework | Flutter 3.41+ | Solo Android |
| Stato | Riverpod | StateNotifierProvider |
| Navigazione | go_router | Transizioni animate |
| Storage | Hive + SharedPreferences | Cronologia + impostazioni |
| HTTP | Dio | Download con resume e retry |
| STT | whisper.cpp via FFI | libwhisper.so ARM64 |
| LLM | llama.cpp via FFI | libllama.so ARM64 |
| Traduzione | ONNX Runtime via FFI | NNAPI dove disponibile |
| Audio | record | WAV 16kHz mono 16-bit |

## Decisioni Architetturali

1. **Clean Architecture**: separazione netta tra domain, data e presentation
2. **FFI su Isolate**: ogni inferenza ML gira su Isolate separato per non bloccare UI
3. **Download con resume**: supporto HTTP Range per riprendere download interrotti
4. **Retry con backoff esponenziale**: 3 tentativi con attesa crescente
5. **Hive per cronologia**: storage locale veloce senza overhead SQL
6. **SharedPreferences per settings**: semplice e affidabile per key-value
7. **Tema automatico**: dark/light in base alle impostazioni di sistema

## Stato Implementazione

- [x] Struttura progetto e architettura
- [x] Core layer (costanti, tema, logger, eccezioni)
- [x] Domain layer (entita')
- [x] Data layer (FFI bindings, servizi, repository)
- [x] Presentation layer (provider, schermate, widget, router)
- [x] Configurazione Android (NDK, CMake, permessi)
- [x] CMakeLists.txt per compilazione nativa
- [x] Wrapper C per llama.cpp
- [ ] Clonare whisper.cpp e llama.cpp come submodule
- [ ] Compilazione e test su dispositivo ARM64
- [ ] Integrazione ONNX Runtime per NLLB-200
- [ ] Icona app personalizzata
- [ ] Test end-to-end completo

## Note per Chi Lavorera' al Progetto

- I modelli ML pesano circa 4 GB totali, vengono scaricati al primo avvio
- whisper.cpp e llama.cpp devono essere clonati in `android/app/src/main/cpp/`
- L'app richiede un dispositivo ARM64 con almeno 4 GB di RAM
- La correzione Phi-3 puo' essere disabilitata dalle impostazioni se la RAM e' insufficiente
- Tutti i log usano AppLogger con tag per modulo per facile debug
