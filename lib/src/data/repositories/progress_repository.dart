/// Repository progression d'épisode — AUCUN import de package:flutter.
///
/// Convertit entre [EpisodeProgressesData] (rows drift) et [EpisodeProgress] (domaine).
library;

import 'package:drift/drift.dart';

import '../../domain/models/episode_progress.dart';
import '../local/database.dart';

class ProgressRepository {
  final TerebiDatabase _db;

  const ProgressRepository(this._db);

  // ---------------------------------------------------------------------------
  // Conversions privées
  // ---------------------------------------------------------------------------

  EpisodeProgressesCompanion _toCompanion(EpisodeProgress p) =>
      EpisodeProgressesCompanion.insert(
        mediaId: p.mediaId,
        episodeNumber: p.episodeNumber,
        watched: Value(p.watched),
        positionSeconds: Value(p.positionSeconds),
        durationSeconds: Value(p.durationSeconds),
        completedAt: Value(p.completedAt),
        updatedAt: p.updatedAt,
      );

  EpisodeProgress _fromRow(EpisodeProgressesData row) => EpisodeProgress(
        mediaId: row.mediaId,
        episodeNumber: row.episodeNumber,
        watched: row.watched,
        positionSeconds: row.positionSeconds,
        durationSeconds: row.durationSeconds,
        completedAt: row.completedAt,
        updatedAt: row.updatedAt,
      );

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Insère ou met à jour la progression (upsert sur contrainte unique mediaId+episodeNumber).
  Future<void> upsertProgress(EpisodeProgress progress) async {
    final companion = _toCompanion(progress);
    await _db.into(_db.episodeProgresses).insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [
              _db.episodeProgresses.mediaId,
              _db.episodeProgresses.episodeNumber,
            ],
          ),
        );
  }

  /// Retourne la progression pour ([mediaId], [episodeNumber]), ou `null`.
  Future<EpisodeProgress?> getProgress(
      int mediaId, double episodeNumber) async {
    final row = await (_db.select(_db.episodeProgresses)
          ..where((t) =>
              t.mediaId.equals(mediaId) &
              t.episodeNumber.equals(episodeNumber)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Dernier épisode regardé pour [mediaId] (le plus grand episodeNumber watched).
  ///
  /// Retourne `null` si aucun épisode n'est marqué watched.
  Future<EpisodeProgress?> lastWatched(int mediaId) async {
    final rows = await (_db.select(_db.episodeProgresses)
          ..where(
              (t) => t.mediaId.equals(mediaId) & t.watched.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.episodeNumber)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : _fromRow(rows.first);
  }
}
