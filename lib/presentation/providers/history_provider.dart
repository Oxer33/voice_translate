/// Provider per la gestione della cronologia delle traduzioni.
/// Fornisce accesso reattivo alla lista delle traduzioni salvate.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/data/repositories/history_repository.dart';
import 'package:voice_translate/domain/entities/translation_entry.dart';
import 'package:voice_translate/presentation/providers/app_providers.dart';

/// Tag per i log di questo modulo
const String _tag = 'HistoryProvider';

/// Provider per la lista della cronologia (reattivo)
final historyListProvider =
    StateNotifierProvider<HistoryListNotifier, List<TranslationEntry>>((ref) {
  final repo = ref.watch(historyRepositoryProvider);
  return HistoryListNotifier(repo);
});

/// Notifier per la gestione della lista cronologia
class HistoryListNotifier extends StateNotifier<List<TranslationEntry>> {
  final HistoryRepository _repo;

  HistoryListNotifier(this._repo) : super([]);

  /// Carica la cronologia dal repository
  Future<void> load() async {
    AppLogger.info(_tag, 'Caricamento cronologia...');
    try {
      state = await _repo.getAll();
      AppLogger.info(_tag, 'Cronologia caricata: ${state.length} voci');
    } catch (e) {
      AppLogger.error(_tag, 'Errore caricamento cronologia', e);
    }
  }

  /// Aggiorna la lista dalla fonte dati
  Future<void> refresh() async {
    AppLogger.debug(_tag, 'Refresh cronologia');
    try {
      state = await _repo.getAll();
    } catch (e) {
      AppLogger.error(_tag, 'Errore refresh cronologia', e);
    }
  }

  /// Elimina una voce dalla cronologia
  Future<void> delete(String id) async {
    AppLogger.info(_tag, 'Eliminazione voce: $id');
    try {
      await _repo.deleteById(id);
      state = await _repo.getAll();
      AppLogger.info(_tag, 'Voce eliminata, rimaste: ${state.length}');
    } catch (e) {
      AppLogger.error(_tag, 'Errore eliminazione voce', e);
    }
  }

  /// Elimina tutta la cronologia
  Future<void> deleteAll() async {
    AppLogger.info(_tag, 'Eliminazione tutta la cronologia');
    try {
      await _repo.deleteAll();
      state = [];
      AppLogger.info(_tag, 'Cronologia eliminata');
    } catch (e) {
      AppLogger.error(_tag, 'Errore eliminazione cronologia', e);
    }
  }
}
