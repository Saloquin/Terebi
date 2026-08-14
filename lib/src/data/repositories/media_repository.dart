/// Repository média — AUCUN import de package:flutter.
///
/// Convertit entre [MediaTableData] (rows drift) et [Media] (domaine).
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/anime_format.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/media.dart';
import '../local/database.dart';

class MediaRepository {
  final TerebiDatabase _db;

  const MediaRepository(this._db);

  // ---------------------------------------------------------------------------
  // Conversions privées
  // ---------------------------------------------------------------------------

  MediaTableCompanion _toCompanion(Media m) => MediaTableCompanion.insert(
        anilistId: Value(m.anilistId),
        malId: Value(m.malId),
        titleRomaji: Value(m.title.romaji),
        titleEnglish: Value(m.title.english),
        titleNative: Value(m.title.native),
        format: Value(m.format.name),
        status: Value(m.status.name),
        episodes: Value(m.episodes),
        durationMinutes: Value(m.durationMinutes),
        season: Value(m.season?.name),
        seasonYear: Value(m.seasonYear),
        coverUrl: Value(m.coverUrl),
        bannerUrl: Value(m.bannerUrl),
        description: Value(m.description),
        genresJson: Value(jsonEncode(m.genres)),
        averageScore: Value(m.averageScore),
        animeSamaTitle: Value(m.animeSamaTitle),
        animeSamaSlug: Value(m.animeSamaSlug),
        updatedAt: Value(DateTime.now().toUtc()),
      );

  Media _fromRow(MediaTableData row) => Media(
        anilistId: row.anilistId,
        malId: row.malId,
        title: MediaTitle(
          romaji: row.titleRomaji,
          english: row.titleEnglish,
          native: row.titleNative,
        ),
        format: AnimeFormat.values.byName(row.format),
        status: ReleaseStatus.values.byName(row.status),
        episodes: row.episodes,
        durationMinutes: row.durationMinutes,
        season: row.season == null
            ? null
            : AnimeSeason.values.byName(row.season!),
        seasonYear: row.seasonYear,
        coverUrl: row.coverUrl,
        bannerUrl: row.bannerUrl,
        description: row.description,
        genres: (jsonDecode(row.genresJson) as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        averageScore: row.averageScore,
        animeSamaTitle: row.animeSamaTitle,
        animeSamaSlug: row.animeSamaSlug,
      );

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Insère ou remplace un [Media] dans la base.
  Future<void> upsertMedia(Media media) async {
    await _db.into(_db.mediaTable).insertOnConflictUpdate(_toCompanion(media));
  }

  /// Retourne un [Media] par son [anilistId], ou `null` s'il n'existe pas.
  Future<Media?> getMedia(int anilistId) async {
    final row = await (_db.select(_db.mediaTable)
          ..where((t) => t.anilistId.equals(anilistId)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Stream de tous les médias en base.
  Stream<List<Media>> watchAllMedia() {
    return _db.select(_db.mediaTable).watch().map(
          (rows) => rows.map(_fromRow).toList(),
        );
  }

  /// Stream du media [anilistId] (emet a chaque ecriture le concernant).
  Stream<Media?> watchMedia(int anilistId) {
    return (_db.select(_db.mediaTable)
          ..where((t) => t.anilistId.equals(anilistId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }

  /// Liste (one-shot) de tous les médias en base. Sert à réconcilier l'identité
  /// d'un anime dont le titre varie entre sources (planning/catalogue).
  Future<List<Media>> getAllMedia() async {
    final rows = await _db.select(_db.mediaTable).get();
    return rows.map(_fromRow).toList();
  }

  /// Supprime le média [anilistId] de la base (n'affecte ni l'entrée de liste ni
  /// la progression : à nettoyer séparément par l'appelant). Sert au nettoyage
  /// manuel d'une entrée mal résolue.
  Future<void> deleteMedia(int anilistId) async {
    await (_db.delete(_db.mediaTable)
          ..where((t) => t.anilistId.equals(anilistId)))
        .go();
  }
}
