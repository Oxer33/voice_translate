# TODO List - VoiceTranslate v2.1

## Completati

- [x] Architettura streaming live con chunk audio 3-4s
- [x] Due modalita': sottotitoli (testo) e parlato (TTS)
- [x] 3 modelli Whisper selezionabili: Tiny (75MB), Small (466MB), Medium (1.5GB)
- [x] Selezione modello Whisper nelle impostazioni con rating velocita'/accuratezza
- [x] URL NLLB-200 corretti: Xenova repo con encoder+decoder ONNX quantizzati
- [x] Download robusto: resume byte-level, timeout 30min, 5 retry con backoff
- [x] Rimosso Phi-3/llama.cpp (non necessario con Whisper Medium)
- [x] TTS nativo Android con velocita' configurabile
- [x] Pipeline streaming: ascolto -> trascrizione -> traduzione -> TTS
- [x] Toggle modalita' TEXT/SPEECH nella home screen
- [x] Selettori lingua con 50 lingue NLLB e auto-detect
- [x] Cronologia 20 voci con Hive (swipe-to-delete, copia)
- [x] Analisi statica 0 errori
- [x] APK release 56.4MB

## Da Fare (richiedono dispositivo Android)

- [ ] Clonare whisper.cpp come submodule git
- [ ] Compilare whisper.cpp con NDK 27 per ARM64
- [ ] Integrare ONNX Runtime .so per Android
- [ ] Test end-to-end pipeline streaming su device fisico
- [ ] Icona app personalizzata
- [ ] Ottimizzazione latenza streaming (overlap chunk)
- [ ] Download automatico modello Whisper selezionato se non presente

## Miglioramenti Futuri

- [ ] VAD (Voice Activity Detection) per processare solo quando si parla
- [ ] Cache traduzioni ripetute
- [ ] Esportazione sessione (testo completo + traduzione)
- [ ] Widget Android per traduzione rapida
- [ ] Supporto landscape e tablet
- [ ] Whisper Large (3GB) come opzione aggiuntiva
