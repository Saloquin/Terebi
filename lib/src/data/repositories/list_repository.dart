/// Repository entrées de liste — AUCUN import de package:flutter.
///
/// Convertit entre [ListEntryRow] (rows drift) et [ListEntry] (domaine).
library;

import 'package:drift/drift.dart';

import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../local/database.dart';

class ListRepository {
  final TerebiDatabase _db;

  const ListRepository(this._db);

  // ---------------------------------------------------------------------------
  // Conversions privées
  // ---------------------------------------------------------------------------

  ListEntriesCompanion _toCompanion(ListEntry e) =>
      ListEntriesCompanion.insert(
        mediaId: Value(e.mediaId),
        status: Value(e.status.name),
        progress: Value(e.progress),
        score: Value(e.score),
        favorite: Value(e.favorite),
        notes: Value(e.notes),
        hiddenFromPlanning: Value(e.hiddenFromPlanning),
        anilistEntryId: Value(e.anilistEntryId),
        updatedAt: e.updatedAt,
        syncedAt: Value(e.syncedAt),
      );

  ListEntry _fromRow(ListEntryRow row) => ListEntry(
        mediaId: row.mediaId,
        status: ListStatus.values.byName(row.status),
        progress: row.progress,
        score: row.score,
        favorite: row.favorite,
        notes: row.notes,
        hiddenFromPlanning: row.hiddenFromPlanning,
        anilistEntryId: row.anilistEntryId,
        updatedAt: row.updatedAt,
        syncedAt: row.syncedAt,
      );

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Insère ou remplace une [ListEntry].
  Future<void> upsertEntry(ListEntry entry) async {
    await _db
        .into(_db.listEntries)
        .insertOnConflictUpdate(_toCompanion(entry));
  }

  /// Retourne l'entrée pour [mediaId], ou `null`.
  Future<ListEntry?> getEntry(int mediaId) async {
    final row = await (_db.select(_db.listEntries)
          ..where((t) => t.mediaId.equals(mediaId)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Retire l'entrée de liste pour [mediaId] (retrait de la bibliothèque).
  /// N'efface PAS la progression d'épisodes (table séparée).
  Future<void> deleteEntry(int mediaId) async {
    await (_db.delete(_db.listEntries)
          ..where((t) => t.mediaId.equals(mediaId)))
        .go();
  }

  /// Toutes les entrées pour un [status] donné.
  Future<List<ListEntry>> entriesByStatus(ListStatus status) async {
    final rows = await (_db.select(_db.listEntries)
          ..where((t) => t.status.equals(status.name)))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Nombre d'entrées par statut.
  Future<Map<ListStatus, int>> countByStatus() async {
    final all = await _db.select(_db.listEntries).get();
    final result = <ListStatus, int>{};
    for (final row in all) {
      final s = ListStatus.values.byName(row.status);
      result[s] = (result[s] ?? 0) + 1;
    }
    return result;
  }

  /// Cache ou retire [mediaId] de la liste masquée (Planning).
  Future<void> setHidden(int mediaId, {required bool hidden}) async {
    await (_db.update(_db.listEntries)
          ..where((t) => t.mediaId.equals(mediaId)))
        .write(ListEntriesCompanion(hiddenFromPlanning: Value(hidden)));
  }

  /// Ensemble des mediaId masqués du planning.
  Future<Set<int>> allHidden() async {
    final rows = await (_db.select(_db.listEntries)
          ..where((t) => t.hiddenFromPlanning.equals(true)))
        .get();
    return rows.map((r) => r.mediaId).toSet();
  }
}
