/// Repository média — AUCUN import de package:flutter.
///
/// Convertit entre [MediaTableData] (rows drift) et [Media] (domaine). La
/// colonne DB reste nommée `anilistId` (héritage) ; le modèle utilise `mediaId`.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/media.dart';
import '../local/database.dart';

class MediaRepository {
  final TerebiDatabase _db;

  const MediaRepository(this._db);

  // ---------------------------------------------------------------------------
  // Conversions privées
  // ---------------------------------------------------------------------------

  MediaTableCompanion _toCompanion(Media m) => MediaTableCompanion.insert(
        anilistId: Value(m.mediaId),
        titleRomaji: Value(m.title.romaji),
        titleEnglish: Value(m.title.english),
        titleNative: Value(m.title.native),
        episodes: Value(m.episodes),
        coverUrl: Value(m.coverUrl),
        bannerUrl: Value(m.bannerUrl),
        description: Value(m.description),
        genresJson: Value(jsonEncode(m.genres)),
        animeSamaTitle: Value(m.animeSamaTitle),
        animeSamaSlug: Value(m.animeSamaSlug),
        updatedAt: Value(DateTime.now().toUtc()),
      );

  Media _fromRow(MediaTableData row) => Media(
        mediaId: row.anilistId,
        title: MediaTitle(
          romaji: row.titleRomaji,
          english: row.titleEnglish,
          native: row.titleNative,
        ),
        episodes: row.episodes,
        coverUrl: row.coverUrl,
        bannerUrl: row.bannerUrl,
        description: row.description,
        genres: (jsonDecode(row.genresJson) as List<dynamic>)
            .map((e) => e as String)
            .toList(),
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

  /// Retourne un [Media] par son [mediaId], ou `null` s'il n'existe pas.
  Future<Media?> getMedia(int mediaId) async {
    final row = await (_db.select(_db.mediaTable)
          ..where((t) => t.anilistId.equals(mediaId)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Stream de tous les médias en base.
  Stream<List<Media>> watchAllMedia() {
    return _db.select(_db.mediaTable).watch().map(
          (rows) => rows.map(_fromRow).toList(),
        );
  }

  /// Stream du media [mediaId] (emet a chaque ecriture le concernant).
  Stream<Media?> watchMedia(int mediaId) {
    return (_db.select(_db.mediaTable)
          ..where((t) => t.anilistId.equals(mediaId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }

  /// Liste (one-shot) de tous les médias en base. Sert à réconcilier l'identité
  /// d'un anime dont le titre varie entre sources (planning/catalogue).
  Future<List<Media>> getAllMedia() async {
    final rows = await _db.select(_db.mediaTable).get();
    return rows.map(_fromRow).toList();
  }

  /// Date de derniere ecriture du media [mediaId] (epoch 0 si absent). Sert au
  /// calcul de fraicheur du cache (revalidation).
  Future<DateTime> updatedAtOf(int mediaId) async {
    final row = await (_db.select(_db.mediaTable)
          ..where((t) => t.anilistId.equals(mediaId)))
        .getSingleOrNull();
    return row?.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Supprime le média [mediaId] de la base (n'affecte ni l'entrée de liste ni
  /// la progression : à nettoyer séparément par l'appelant). Sert au nettoyage
  /// manuel d'une entrée mal résolue.
  Future<void> deleteMedia(int mediaId) async {
    await (_db.delete(_db.mediaTable)
          ..where((t) => t.anilistId.equals(mediaId)))
        .go();
  }
}
