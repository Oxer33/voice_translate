# VoiceTranslate

App Flutter per Android che esegue **trascrizione e traduzione vocale completamente offline**, con download automatico dei modelli al primo avvio.

## Funzionalita'

- **Registrazione audio** dal microfono con rilevamento automatico del silenzio e countdown 60s
- **Trascrizione** in locale con Whisper.cpp (FFI)
- **Correzione testo** con Phi-3 Mini Q4 via llama.cpp (FFI)
- **Traduzione** con NLLB-200 distilled via ONNX Runtime
- **50 lingue** supportate con rilevamento automatico
- **Cronologia** delle ultime 10 traduzioni
- **100% offline** dopo il download iniziale dei modelli

## Architettura

Clean Architecture con layer separati:

```
lib/
  core/         -> Costanti, tema, utility, eccezioni
  data/         -> FFI bindings, servizi, repository
  domain/       -> Entita', interfacce
  presentation/ -> Provider Riverpod, schermate, widget, router
```

## Prerequisiti

- **Flutter SDK** >= 3.11
- **Android SDK** con minSdk 26
- **Android NDK** 25.2.9519653
- **CMake** 3.22+
- Circa **6 GB** di spazio libero per i modelli

## Setup e Build

### 1. Clona il repository

```bash
git clone <URL_REPO>
cd voice_translate
```

### 2. Clona le dipendenze native

```bash
cd android/app/src/main/cpp
git clone https://github.com/ggerganov/whisper.cpp whisper_cpp
git clone https://github.com/ggerganov/llama.cpp llama_cpp
cd ../../../../..
```

### 3. Installa le dipendenze Flutter

```bash
flutter pub get
```

### 4. Configura l'NDK Android

Assicurati di avere l'NDK 25.2.9519653 installato. Puoi installarlo tramite Android Studio:
- Apri Android Studio > SDK Manager > SDK Tools
- Seleziona "NDK (Side by side)" versione 25.2.9519653
- Clicca "Apply"

In alternativa da riga di comando:
```bash
sdkmanager "ndk;25.2.9519653"
```

### 5. Build APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

### 6. Installa su dispositivo

```bash
flutter install
```

## Modelli ML

Al primo avvio l'app scarica automaticamente:

| Modello | Dimensione | Uso |
|---------|-----------|-----|
| Whisper Small multilingual | ~466 MB | Trascrizione STT |
| Phi-3 Mini Q4 | ~2.2 GB | Correzione testo |
| NLLB-200 distilled 600M | ~1.2 GB | Traduzione |

## Stack Tecnologico

- **Flutter** 3.41+ con Dart 3.11+
- **Riverpod** per gestione stato
- **go_router** per navigazione
- **Hive** per storage locale
- **Dio** per download HTTP con resume
- **dart:ffi** per binding nativi C/C++
- **whisper.cpp** per STT
- **llama.cpp** per LLM
- **ONNX Runtime** per traduzione

## Licenza

Uso privato. I modelli ML hanno le proprie licenze (vedi Hugging Face).
