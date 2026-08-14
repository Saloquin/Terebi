/// Repository historique de visionnage — AUCUN import de package:flutter.
///
/// Enregistre un LANCEMENT de lecture (clic « Regarder ») dans la table
/// [WatchHistories] et expose l'historique récent pour les statistiques.
library;

import 'package:drift/drift.dart';

import '../../domain/models/watch_history_entry.dart';
import '../local/database.dart';

class WatchHistoryRepository {
  final TerebiDatabase _db;

  const WatchHistoryRepository(this._db);

  WatchHistoryEntry _fromRow(WatchHistoryRow row) => WatchHistoryEntry(
        id: row.id,
        mediaId: row.mediaId,
        episodeNumber: row.episodeNumber,
        startedAt: row.startedAt,
      );

  /// Enregistre un lancement de lecture (nouvelle ligne d'historique).
  Future<void> record({
    required int mediaId,
    required double episodeNumber,
    required DateTime startedAt,
  }) async {
    await _db.into(_db.watchHistories).insert(
          WatchHistoriesCompanion.insert(
            mediaId: mediaId,
            episodeNumber: episodeNumber,
            startedAt: startedAt,
          ),
        );
  }

  /// Historique récent (le plus récent d'abord), limité à [limit] entrées.
  Future<List<WatchHistoryEntry>> recent({int limit = 50}) async {
    final rows = await (_db.select(_db.watchHistories)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(limit))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Toutes les entrées d'historique (pour agréger l'activité par jour).
  Future<List<WatchHistoryEntry>> all() async {
    final rows = await (_db.select(_db.watchHistories)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Deplace toutes les lignes d'historique de [oldId] vers [newId] (migration
  /// slug : l'historique a ete enregistre avec l'ancien id entier). Best-effort.
  Future<void> reindexMediaId(int oldId, int newId) async {
    await (_db.update(_db.watchHistories)
          ..where((t) => t.mediaId.equals(oldId)))
        .write(WatchHistoriesCompanion(mediaId: Value(newId)));
  }
}
