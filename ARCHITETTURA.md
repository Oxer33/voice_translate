# Architettura VoiceTranslate v2.2

## Panoramica

VoiceTranslate e' un'app Flutter per Android che esegue trascrizione e traduzione vocale **in streaming live continuo**, completamente offline dopo il download iniziale dei modelli. Funziona anche a **schermo spento** grazie al foreground service.

**Due modalita':**
- **Sottotitoli**: traduzione mostrata come testo a schermo in tempo reale
- **Parlato**: traduzione pronunciata con TTS nativo Android (funziona a schermo spento)

## Stack

| Componente | Modelli | Note |
|-----------|---------|------|
| Trascrizione | Whisper Tiny/Small/Medium/Large V2/Large V3 Turbo | 5 modelli selezionabili |
| Traduzione | NLLB-200 distilled 600M (ONNX quantizzato) | encoder + decoder |
| Sintesi vocale | TTS nativo Android | Integrato, 0 download |
| Foreground service | flutter_foreground_task | Schermo spento |

## Pipeline Streaming (v2.2)

```
[Microfono - AudioRecorder.startStream()]
       |  (stream continuo PCM 16kHz mono)
       v
[Buffer PCM - accumula ~3 secondi]
       |  (nessun gap - microfono sempre acceso)
       v
[Processing Queue FIFO con lock]
       |
       v
[Whisper FFI - Trascrizione]  <- Dart Isolate
       |
       v
[NLLB-200 ONNX - Traduzione]  <- Backend Android via MethodChannel
       |
       v
[TEXT mode] -> Testo a schermo (sottotitoli live)
[SPEECH mode] -> TTS nativo Android (parlato)
```

**Differenza chiave v2.2 vs v2.1**: il microfono resta SEMPRE acceso tramite `startStream()`. Non c'e' piu' stop/start che perdeva audio. I chunk vengono accumulati nel buffer PCM e processati in sequenza.

## Layer Nativo Android

- **Whisper Android**: integrato direttamente da `android/app/src/main/cpp/whisper_cpp`
- **Wrapper stabile Dart <-> C++**: `voice_translate_whisper_wrapper.cpp` espone `voice_translate_whisper_transcribe`
- **Preflight modello Whisper**: il wrapper espone anche `voice_translate_whisper_validate_model` per bloccare subito file mancanti o corrotti
- **APK verificato**: contiene `libwhisper.so` e `libvoice_translate_whisper.so`
- **Build safety**: la build ora fallisce subito se `whisper.cpp` manca, evitando APK apparentemente validi ma rotti a runtime

## Backend ONNX / NLLB Reale

- **Runtime Android reale**: integrato `com.microsoft.onnxruntime:onnxruntime-android:1.24.2`
- **Tokenizer locale reale**: stack Android compatibile DJL `ai.djl:bom:0.33.0` + `ai.djl.android:core` + `ai.djl.huggingface:tokenizers` + `ai.djl.android:tokenizer-native:0.33.0`
- **Bridge Flutter <-> Android**: `MethodChannel` `voice_translate/nllb`
- **Entry point Android**: `MainActivity.kt` registra `NllbMethodChannelHandler`
- **Motore traduzione**: `NllbBackend.kt` carica `encoder_model_quantized.onnx`, `decoder_model_merged_quantized.onnx`, `tokenizer.json` e `config.json`
- **Generazione**: encoder una volta, decoder autoregressivo greedy con forcing del token lingua target al primo passo
- **Packaging verificato**: l'APK contiene `libonnxruntime.so`, `libonnxruntime4j_jni.so` e `libdjl_tokenizer.so`
- **Pulizia packaging**: escluse le risorse desktop inutili del tokenizer DJL dal packaging Android

## Esperienza UI e Cronologia

- **Tema scuro fisso**: l'app ora usa solo il tema dark per coerenza visiva
- **Cronologia home**: la home mostra una preview compatta delle ultime sessioni
- **Cronologia completa**: nuova schermata dedicata `HistoryScreen` con lettura full-screen in stile chat, testo selezionabile, copia rapida e cancellazione sessioni
- **Capienza cronologia**: aumentata a 50 sessioni locali per non perdere conversazioni utili
- **Icona app**: nuova adaptive icon Android multicolor in stile AI con variante monocromatica per launcher moderni
- **Impostazioni reattive**: update ottimistico dello stato UI con persistenza piu' solida e meno lag percepito
- **Slider ottimizzati**: sensibilita' silenzio e velocita' TTS aggiornano l'anteprima locale senza scrivere su disco a ogni tick
- **Permessi meno invasivi**: il microfono viene richiesto quando serve davvero, non all'apertura della home
- **Live results puliti**: la schermata principale mostra in modo separato originale e traduzione senza la card di stato fase
- **Chat cronologia ripulita**: testi non verbali come silenzi, rumori o musica vengono filtrati in visualizzazione e in salvataggio

## Bootstrap Modelli e Avvio Streaming

- La route iniziale dipende da `modelsReadyProvider`, che ora legge il modello Whisper selezionato dalle impostazioni
- `DownloadScreen` inizializza la lista download in base al modello Whisper salvato, non piu' sempre e solo sul default
- `SettingsScreen` espone solo `Whisper Small`, scelto come profilo fisso per mantenere latenza e stabilita' accettabili su device reali
- `SettingsScreen` usa il ri-download per configurazione file, evitando mismatch tra ordine visuale dei modelli NLLB e indici interni della lista download
- `PipelineNotifier.startStreaming()` esegue un preflight completo prima di avviare il microfono:
  - presenza del modello Whisper selezionato
  - caricabilita' reale del file modello Whisper (**validazione asincrona in Isolate** per non bloccare il main thread)
  - presenza dei file NLLB obbligatori
  - disponibilita' del backend Android ONNX/NLLB
- `HomeScreen` verifica i modelli richiesti prima dello start e, se mancano, riporta direttamente alla `DownloadScreen`
- **GoRouter caching**: il router viene creato una sola volta al primo avvio e riusato su ogni rebuild, evitando perdita di stato navigazione e splash flash
- **Nessuna invalidazione inutile**: la navigazione tra download e home avviene con `context.go()` senza `ref.invalidate(modelsReadyProvider)`, eliminando rebuild totali dell'app
- `PipelineNotifier` applica davvero la sensibilita' silenzio salvata e salta i chunk sotto soglia per evitare lavoro inutile su audio vuoto
- `PipelineNotifier` aggiorna in modo piu' robusto lingua e velocita' del TTS durante l'uso
- `PipelineNotifier` traduce anche in modalita' testo quando lingua sorgente e target sono diverse; la modalita' parlato controlla solo il TTS
- La pipeline live usa chunk piu' corti e scarta backlog vecchi se il device resta indietro, privilegiando la freschezza del risultato live
- Il wrapper nativo `voice_translate_whisper_wrapper.cpp` riusa il contesto Whisper tra chunk successivi invece di ricaricare il modello a ogni trascrizione

## Blocchi Residui Reali

- Manca ancora un test end-to-end su device fisico ARM64 della traduzione live completa
- La generazione NLLB usa un percorso greedy compatibile con il decoder merged esportato, ma va validata sul campo con i modelli reali scaricati sul dispositivo
- L'APK release e' cresciuto sensibilmente per via dell'integrazione del runtime ONNX e del tokenizer locale Android

## Download Robusto

- **Resume byte-level**: `IOSink` in append + `Range: bytes=X-`
- **URL corretti**: NLLB-200 dal repo `Xenova/nllb-200-distilled-600M` (ONNX quantizzato)
- **Timeout 30 minuti** per file grandi
- **5 retry** con backoff esponenziale
- **Ri-download sicuro**: i file possono essere ri-scaricati dalle impostazioni senza colpire il modello sbagliato

## Persistenza Locale

- `SettingsRepository` ha inizializzazione idempotente per evitare overhead e stati incoerenti
- `HistoryRepository` ha apertura box Hive piu' robusta e salvataggio sicuro anche in avvii/stop rapidi

## Stato Implementazione

- [x] Streaming audio continuo senza gap (startStream)
- [x] Processing queue FIFO con lock anti-sovrapposizione
- [x] Error handling FFI con messaggi user-facing
- [x] 5 modelli Whisper selezionabili
- [x] Foreground service per schermo spento
- [x] Due modalita' (sottotitoli + parlato TTS)
- [x] Download robusto byte-level
- [x] Compilazione whisper.cpp con NDK e packaging nell'APK
- [x] Wrapper nativo stabile per Whisper (`libvoice_translate_whisper.so`)
- [x] Integrazione ONNX Runtime Android nell'APK
- [x] Backend Android reale per NLLB con `MethodChannel`
- [x] Caricamento reale dei file `encoder_model_quantized.onnx` + `decoder_model_merged_quantized.onnx` + `tokenizer.json` + `config.json`
- [x] Runtime nativo Android del tokenizer DJL incluso nell'APK (`libdjl_tokenizer.so`)
- [x] Cronologia full-screen in stile chat con preview compatta nella home
- [x] Tema scuro fisso coerente su tutta l'app
- [x] Icona adaptive multicolor personalizzata
- [x] Impostazioni piu' fluide e affidabili con slider ottimizzati
- [x] Filtro silenzio realmente applicato alla pipeline live
- [x] Ri-download modelli NLLB corretto dalle impostazioni
- [x] Profilo Whisper semplificato a `Whisper Small` per favorire prestazioni reali
- [x] Traduzione corretta anche in modalita' testo
- [x] Home semplificata senza card fase e con vista separata originale/traduzione
- [x] Testi non verbali filtrati da live e cronologia
- [x] Riduzione latenza live con riuso del contesto Whisper e backlog limitato
- [x] Redirect automatico al download quando i modelli richiesti non sono presenti
- [x] Cronologia chat resa piu' stabile senza swipe dismiss e con caricamento autonomo
- [x] GoRouter caching: niente piu' ricostruzione router a ogni rebuild
- [x] Validazione modello Whisper asincrona in Isolate (no ANR da caricamento sincrono 466MB)
- [x] Rimossa invalidazione `modelsReadyProvider` dalla navigazione home/download
- [ ] Test end-to-end su device ARM64
