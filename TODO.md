# TODO List - VoiceTranslate v2.2

## Completati

- [x] Streaming audio continuo con AudioRecorder.startStream() (nessun gap)
- [x] Buffer PCM con accumulo chunk 3s e processing queue FIFO con lock
- [x] Error handling FFI: messaggi chiari se librerie native mancanti
- [x] 5 modelli Whisper: Tiny (75MB), Small (466MB), Medium (1.5GB), Large V2 (3.1GB), Large V3 Turbo (1.6GB)
- [x] Selezione modello Whisper nelle impostazioni con rating velocita'/accuratezza
- [x] URL NLLB-200 corretti: Xenova repo con encoder+decoder ONNX quantizzati
- [x] Download robusto: resume byte-level, timeout 30min, 5 retry con backoff
- [x] Foreground service (flutter_foreground_task) per schermo spento
- [x] Permessi FOREGROUND_SERVICE_MICROPHONE e MEDIA_PLAYBACK
- [x] TTS nativo Android con velocita' configurabile
- [x] Due modalita': sottotitoli (testo) e parlato (TTS)
- [x] autoGain, echoCancel, noiseSuppress abilitati nell'audio
- [x] Analisi statica 0 errori, APK 56.3MB

## Da Fare (richiedono dispositivo Android)

- [ ] Clonare whisper.cpp come submodule git e compilare con NDK 27
- [ ] Integrare ONNX Runtime .so per Android ARM64
- [ ] Test end-to-end pipeline streaming su device fisico
- [ ] Icona app personalizzata
- [ ] Inizializzare foreground service nel pipeline_provider.startStreaming()

## Miglioramenti Futuri

- [ ] VAD (Voice Activity Detection) per processare solo quando si parla
- [ ] Cache traduzioni ripetute per frasi comuni
- [ ] Esportazione sessione (testo completo + traduzione)
- [ ] Widget Android per traduzione rapida
- [ ] Supporto landscape e tablet
