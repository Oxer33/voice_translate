# TODO List - VoiceTranslate

## Completati

- [x] Creazione progetto Flutter con struttura Clean Architecture
- [x] pubspec.yaml con tutte le dipendenze (Riverpod, go_router, Hive, Dio, FFI, etc.)
- [x] Core layer: costanti, tema scuro/chiaro, logger, eccezioni tipizzate
- [x] 50 lingue NLLB con codici e nomi in italiano
- [x] Domain entities: PipelineState, DownloadState, TranslationEntry, AppSettings
- [x] FFI bindings: WhisperFFI, LlamaFFI, OnnxFFI con Isolate separati
- [x] Download service con resume HTTP Range, retry con backoff, verifica checksum
- [x] Audio service con registrazione WAV 16kHz, rilevamento silenzio, countdown
- [x] History repository con Hive (max 10 voci)
- [x] Settings repository con SharedPreferences
- [x] Provider Riverpod: app, download, pipeline, history
- [x] Router go_router con transizioni animate
- [x] Schermata download con progress bar individuali e globale
- [x] Schermata principale con selettori lingua, registrazione, risultati, cronologia
- [x] Schermata impostazioni con toggle, slider, gestione modelli
- [x] Schermata errore con messaggi chiari e azioni suggerite
- [x] Widget riutilizzabili: DownloadProgressCard, RecordingButton, TextResultCard, etc.
- [x] Configurazione Android: NDK 25+, CMake 3.22+, minSdk 26, arm64-v8a
- [x] CMakeLists.txt per compilazione whisper.cpp e llama.cpp
- [x] Wrapper C per llama.cpp (llama_simple_chat)
- [x] AndroidManifest.xml con tutti i permessi necessari
- [x] README.md con istruzioni build complete
- [x] ARCHITETTURA.md con documentazione struttura

## Da Fare (richiedono dispositivo Android)

- [ ] Clonare whisper.cpp e llama.cpp come submodule git
- [ ] Compilare e testare su dispositivo ARM64 fisico
- [ ] Integrare ONNX Runtime per Android (libonnxruntime.so)
- [ ] Creare icona app personalizzata (microfono + onde sonore, blu/bianco)
- [ ] Test end-to-end della pipeline completa
- [ ] Ottimizzazione performance inferenza su device
- [ ] Gestione OutOfMemoryError con fallback
- [ ] WorkManager per download in background
- [ ] Verifica RAM disponibile e avviso per Phi-3

## Miglioramenti Futuri

- [ ] Supporto landscape e tablet
- [ ] Esportazione cronologia (CSV/JSON)
- [ ] Widget Android per traduzione rapida
- [ ] Modalita' conversazione bidirezionale
- [ ] Supporto per piu' modelli Whisper (tiny, base, medium, large)
- [ ] Cache tokenizzazione per traduzioni ripetute
- [ ] Compressione modelli per ridurre spazio su disco
