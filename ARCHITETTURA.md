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
[NLLB-200 ONNX - Traduzione]  <- Dart Isolate
       |
       v
[TEXT mode] -> Testo a schermo (sottotitoli live)
[SPEECH mode] -> TTS nativo Android (parlato)
```

**Differenza chiave v2.2 vs v2.1**: il microfono resta SEMPRE acceso tramite `startStream()`. Non c'e' piu' stop/start che perdeva audio. I chunk vengono accumulati nel buffer PCM e processati in sequenza.

## Download Robusto

- **Resume byte-level**: `IOSink` in append + `Range: bytes=X-`
- **URL corretti**: NLLB-200 dal repo `Xenova/nllb-200-distilled-600M` (ONNX quantizzato)
- **Timeout 30 minuti** per file grandi
- **5 retry** con backoff esponenziale

## Stato Implementazione

- [x] Streaming audio continuo senza gap (startStream)
- [x] Processing queue FIFO con lock anti-sovrapposizione
- [x] Error handling FFI con messaggi user-facing
- [x] 5 modelli Whisper selezionabili
- [x] Foreground service per schermo spento
- [x] Due modalita' (sottotitoli + parlato TTS)
- [x] Download robusto byte-level
- [ ] Compilazione whisper.cpp con NDK (submodule)
- [ ] Integrazione ONNX Runtime .so
- [ ] Test end-to-end su device ARM64
