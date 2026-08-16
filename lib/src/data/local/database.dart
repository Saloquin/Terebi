/// Couche persistance drift — AUCUN import de package:flutter.
///
/// Utilise QueryExecutor injecté pour permettre NativeDatabase.memory() en test.
library;

import 'package:drift/drift.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// Métadonnées d'un média anime (source anime-sama).
class MediaTable extends Table {
  /// Identifiant technique principal — clé primaire. Dérivé du slug anime-sama
  /// via animeSamaIdForSlug. (Colonne nommée `anilistId` par héritage ; le
  /// modèle Dart l'expose sous `mediaId`.)
  IntColumn get anilistId => integer()();

  TextColumn get titleRomaji => text().nullable()();
  TextColumn get titleEnglish => text().nullable()();
  TextColumn get titleNative => text().nullable()();

  IntColumn get episodes => integer().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();

  /// Genres sérialisés en JSON string (`List&lt;String&gt;`).
  TextColumn get genresJson => text().withDefault(const Constant('[]'))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Titre anime-sama de référence (source de vérité pour saisons/épisodes).
  /// Ajouté en v2.
  TextColumn get animeSamaTitle => text().nullable()();

  /// Slug d'URL anime-sama (identite logique). NULL pour un media legacy non
  /// encore migre. Ajoute en v3.
  TextColumn get animeSamaSlug => text().nullable()();

  @override
  Set<Column> get primaryKey => {anilistId};
}

/// Entrée de liste de l'utilisateur pour un média donné.
@DataClassName('ListEntryRow')
class ListEntries extends Table {
  /// FK → MediaTable.anilistId (aussi PK).
  IntColumn get mediaId => integer()();

  /// Statut de suivi stocké en TEXT (.name).
  TextColumn get status => text().withDefault(const Constant('planning'))();

  IntColumn get progress => integer().withDefault(const Constant(0))();
  BoolColumn get hiddenFromPlanning =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {mediaId};
}

/// Progression de lecture d'un épisode précis.
class EpisodeProgresses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer()();

  /// Numéro d'épisode (double pour les demi-épisodes).
  RealColumn get episodeNumber => real()();

  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  RealColumn get positionSeconds => real().withDefault(const Constant(0.0))();
  RealColumn get durationSeconds => real().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {mediaId, episodeNumber},
      ];
}

/// Historique de visionnage (sessions).
@DataClassName('WatchHistoryRow')
class WatchHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer()();
  RealColumn get episodeNumber => real()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get watchedSeconds => real().withDefault(const Constant(0.0))();
}

/// Paramètres applicatifs clé/valeur.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Cache générique clé/payload/expiration.
class MetaCache extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  MediaTable,
  ListEntries,
  EpisodeProgresses,
  WatchHistories,
  AppSettings,
  MetaCache,
])
class TerebiDatabase extends _$TerebiDatabase {
  TerebiDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 → v2 : ajout de la colonne animeSamaTitle sur media_table.
          if (from < 2) {
            await m.addColumn(mediaTable, mediaTable.animeSamaTitle);
          }
          // v2 -> v3 : ajout de la colonne animeSamaSlug (la re-indexation
          // titre->slug est faite hors migration par SlugMigrationService au
          // 1er boot, cf. tache ulterieure).
          if (from < 3) {
            await m.addColumn(mediaTable, mediaTable.animeSamaSlug);
          }
          // v3 -> v4 : purge des vestiges AniList. On recree media_table et
          // list_entries SANS les colonnes mortes (mal_id, average_score,
          // format, status, season, season_year, duration_minutes / score,
          // favorite, notes, anilist_entry_id, synced_at) via TableMigration
          // (Drift recopie les colonnes conservees), et on supprime les tables
          // orphelines jamais alimentees.
          if (from < 4) {
            await m.alterTable(TableMigration(mediaTable));
            await m.alterTable(TableMigration(listEntries));
            await m.database.customStatement(
                'DROP TABLE IF EXISTS airing_schedules;');
            await m.database.customStatement(
                'DROP TABLE IF EXISTS media_relations;');
          }
        },
      );
}
