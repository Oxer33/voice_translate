# TODO List - VoiceTranslate v2.0

## Completati

- [x] Architettura streaming live con chunk audio 3-4s
- [x] Due modalita': sottotitoli (testo) e parlato (TTS)
- [x] Stack ottimizzato: Whisper Medium (1.5GB) + NLLB-200 ONNX (1.2GB)
- [x] Rimosso Phi-3/llama.cpp (non piu' necessario con Whisper Medium)
- [x] Download robusto byte-level con resume esatto da interruzione
- [x] Retry con backoff esponenziale (5 tentativi, 2-32s)
- [x] TTS nativo Android con velocita' configurabile
- [x] Pipeline streaming: ascolto -> trascrizione -> traduzione -> TTS
- [x] Toggle modalita' TEXT/SPEECH nella home screen
- [x] Selettori lingua con 50 lingue NLLB e auto-detect
- [x] Cronologia 20 voci con Hive (swipe-to-delete, copia)
- [x] Impostazioni: trascrizione visibile, sensibilita' silenzio, velocita' TTS
- [x] Analisi statica 0 errori
- [x] Codice morto spostato in DA CANCELLARE

## Da Fare (richiedono dispositivo Android)

- [ ] Clonare whisper.cpp come submodule git
- [ ] Compilare whisper.cpp con NDK 27 per ARM64
- [ ] Integrare ONNX Runtime .so per Android
- [ ] Test end-to-end pipeline streaming su device fisico
- [ ] Icona app personalizzata
- [ ] Ottimizzazione latenza streaming (overlap chunk)
- [ ] Gestione OutOfMemoryError con fallback

## Miglioramenti Futuri

- [ ] VAD (Voice Activity Detection) per processare solo quando si parla
- [ ] Cache traduzioni ripetute
- [ ] Esportazione sessione (testo completo + traduzione)
- [ ] Widget Android per traduzione rapida
- [ ] Supporto landscape e tablet
- [ ] Compressione modelli per ridurre spazio disco
