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
- [x] Integrazione reale di whisper.cpp in `android/app/src/main/cpp/whisper_cpp`
- [x] Packaging APK verificato: `libwhisper.so` presente
- [x] Wrapper nativo stabile `libvoice_translate_whisper.so` + binding Dart semplificato
- [x] Backend Android reale ONNX/NLLB via `MethodChannel`
- [x] Integrazione `onnxruntime-android` nell'APK (`libonnxruntime.so` + `libonnxruntime4j_jni.so`)
- [x] Caricamento reale dei file NLLB scaricati (`encoder_model_quantized.onnx`, `decoder_model_merged_quantized.onnx`, `tokenizer.json`, `config.json`)
- [x] Tokenizer locale reale HuggingFace da `tokenizer.json`
- [x] Runtime nativo Android del tokenizer DJL incluso nell'APK (`libdjl_tokenizer.so`)
- [x] Cronologia completa in stile chat con preview compatta nella home
- [x] Tema scuro fisso su tutta l'app
- [x] Icona adaptive multicolor personalizzata
- [x] Impostazioni rese piu' fluide con update ottimistico e slider senza scritture continue
- [x] Sensibilita' silenzio realmente applicata alla pipeline live per saltare chunk inutili
- [x] Ri-download modelli NLLB corretto dalle impostazioni senza mismatch di indice
- [x] Richiesta permesso microfono spostata all'avvio streaming per una UX meno invasiva
- [x] Repository impostazioni e cronologia resi piu' robusti nell'inizializzazione
- [x] App limitata a Whisper Small per evitare modelli troppo lenti nella pratica
- [x] Traduzione riattivata anche in modalita' testo quando sorgente e target differiscono
- [x] Card di stato fase rimossa dalla home per recuperare spazio utile
- [x] Risultati live separati in originale e traduzione con layout piu' leggibile
- [x] Segmenti non verbali (silenzio/rumore/musica) filtrati da live e cronologia
- [x] Riuso del contesto Whisper nativo tra chunk per abbassare la latenza live
- [x] Chunk streaming ridotti a 2 secondi con backlog limitato per restare piu' vicini al tempo reale
- [x] Redirect automatico alla schermata download quando mancano modelli richiesti
- [x] Card live colorate correttamente: trascrizione blu, traduzione verde
- [x] Cronologia chat resa piu' stabile con caricamento autonomo e rimozione dello swipe dismiss
- [x] Analisi statica 0 errori, APK release 168.3MB
- [x] FIX: GoRouter caching in app.dart (router creato una sola volta, no rebuild/loop navigazione)
- [x] FIX: Validazione modello Whisper spostata in Isolate (no ANR da caricamento sincrono 466MB sul main thread)
- [x] FIX: Rimossa `ref.invalidate(modelsReadyProvider)` da home_screen e download_screen (no splash flash/rebuild totale)
- [x] APK release aggiornato 168.6MB

## Da Fare (richiedono dispositivo Android)

- [ ] Versionare `whisper.cpp` in modo professionale (submodule o workflow riproducibile)
- [ ] Test end-to-end pipeline streaming su device fisico
- [ ] Validare sul dispositivo la qualità reale della generazione greedy NLLB con i modelli Xenova quantizzati
- [ ] Verificare consumi RAM/CPU e latenza del backend NLLB durante streaming continuo
- [ ] Inizializzare foreground service nel pipeline_provider.startStreaming()

## Miglioramenti Futuri

- [ ] VAD (Voice Activity Detection) per processare solo quando si parla
- [ ] Cache traduzioni ripetute per frasi comuni
- [ ] Esportazione sessione (testo completo + traduzione)
- [ ] Widget Android per traduzione rapida
- [ ] Supporto landscape e tablet
