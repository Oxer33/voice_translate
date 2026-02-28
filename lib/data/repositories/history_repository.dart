/// Repository per la gestione della cronologia delle traduzioni.
/// Usa Hive per la persistenza locale delle ultime 10 voci.
library;

import 'package:hive/hive.dart';
import 'package:voice_translate/core/constants/app_constants.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/domain/entities/translation_entry.dart';

/// Tag per i log di questo modulo
const String _tag = 'HistoryRepository';

/// Nome del box Hive per la cronologia
const String _boxName = 'translation_history';

/// Repository per la gestione della cronologia traduzioni
class HistoryRepository {
  /// Box Hive per la persistenza
  Box? _box;

  /// Inizializza il repository aprendo il box Hive
  Future<void> init() async {
    AppLogger.info(_tag, 'Inizializzazione HistoryRepository...');
    _box = await Hive.openBox(_boxName);
    AppLogger.info(_tag,
        'HistoryRepository inizializzato. Voci presenti: ${_box!.length}');
  }

  /// Ottiene tutte le voci della cronologia ordinate per data (piu' recente prima)
  List<TranslationEntry> getAll() {
    _ensureInit();
    AppLogger.debug(_tag, 'Lettura cronologia: ${_box!.length} voci');

    final entries = <TranslationEntry>[];
    for (var i = 0; i < _box!.length; i++) {
      try {
        final map = _box!.getAt(i);
        if (map != null) {
          entries.add(TranslationEntry.fromMap(
              Map<dynamic, dynamic>.from(map as Map)));
        }
      } catch (e) {
        AppLogger.error(_tag, 'Errore deserializzazione voce $i', e);
      }
    }

    // Ordina per data decrescente
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Aggiunge una nuova voce alla cronologia
  /// Se ci sono piu' di kMaxHistoryEntries voci, rimuove la piu' vecchia
  Future<void> add(TranslationEntry entry) async {
    _ensureInit();
    AppLogger.info(_tag, 'Aggiunta voce cronologia: ${entry.id}');

    // Aggiungi la nuova voce
    await _box!.add(entry.toMap());

    // Rimuovi le voci in eccesso (mantieni solo le ultime kMaxHistoryEntries)
    while (_box!.length > kMaxHistoryEntries) {
      // Trova la voce piu' vecchia e rimuovila
      final entries = getAll();
      if (entries.length > kMaxHistoryEntries) {
        final oldest = entries.last;
        await deleteById(oldest.id);
      } else {
        break;
      }
    }

    AppLogger.info(_tag,
        'Voce aggiunta. Totale voci: ${_box!.length}');
  }

  /// Elimina una voce dalla cronologia per ID
  Future<void> deleteById(String id) async {
    _ensureInit();
    AppLogger.info(_tag, 'Eliminazione voce: $id');

    for (var i = 0; i < _box!.length; i++) {
      try {
        final map = _box!.getAt(i);
        if (map != null) {
          final entryMap = Map<dynamic, dynamic>.from(map as Map);
          if (entryMap['id'] == id) {
            await _box!.deleteAt(i);
            AppLogger.info(_tag, 'Voce $id eliminata');
            return;
          }
        }
      } catch (e) {
        AppLogger.error(_tag, 'Errore durante eliminazione voce $i', e);
      }
    }
    AppLogger.warning(_tag, 'Voce $id non trovata per eliminazione');
  }

  /// Elimina tutta la cronologia
  Future<void> deleteAll() async {
    _ensureInit();
    AppLogger.info(_tag, 'Eliminazione di tutta la cronologia');
    await _box!.clear();
    AppLogger.info(_tag, 'Cronologia eliminata');
  }

  /// Verifica che il box sia inizializzato
  void _ensureInit() {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
          'HistoryRepository non inizializzato. Chiama init() prima.');
    }
  }

  /// Rilascia le risorse
  Future<void> dispose() async {
    AppLogger.info(_tag, 'Chiusura HistoryRepository...');
    await _box?.close();
    AppLogger.info(_tag, 'HistoryRepository chiuso');
  }
}
