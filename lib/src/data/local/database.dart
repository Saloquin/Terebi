/// Couche persistance drift — AUCUN import de package:flutter.
///
/// Utilise QueryExecutor injecté pour permettre NativeDatabase.memory() en test.
library;

import 'package:drift/drift.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// Métadonnées d'un média anime (source AniList/Jikan).
class MediaTable extends Table {
  /// ID AniList — clé primaire.
  IntColumn get anilistId => integer()();

  /// ID MyAnimeList (optionnel).
  IntColumn get malId => integer().nullable()();

  TextColumn get titleRomaji => text().nullable()();
  TextColumn get titleEnglish => text().nullable()();
  TextColumn get titleNative => text().nullable()();

  /// Format stocké en TEXT (.name).
  TextColumn get format => text().withDefault(const Constant('unknown'))();

  /// Statut de diffusion stocké en TEXT (.name).
  TextColumn get status => text().withDefault(const Constant('unknown'))();

  IntColumn get episodes => integer().nullable()();
  IntColumn get durationMinutes => integer().nullable()();

  /// Saison stockée en TEXT (.name), ou NULL.
  TextColumn get season => text().nullable()();

  IntColumn get seasonYear => integer().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();

  /// Genres sérialisés en JSON string (List<String>).
  TextColumn get genresJson => text().withDefault(const Constant('[]'))();

  IntColumn get averageScore => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

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
  RealColumn get score => real().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  BoolColumn get hiddenFromPlanning =>
      boolean().withDefault(const Constant(false))();

  /// ID entrée AniList (optionnel).
  IntColumn get anilistEntryId => integer().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

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

/// Relations entre deux médias (suite, préquelle…).
@DataClassName('MediaRelationRow')
class MediaRelations extends Table {
  IntColumn get mediaId => integer()();
  IntColumn get relatedMediaId => integer()();

  /// Type de relation stocké en TEXT (.name).
  TextColumn get relationType => text()();

  @override
  Set<Column> get primaryKey => {mediaId, relatedMediaId};
}

/// Planification de diffusion d'un épisode.
@DataClassName('AiringScheduleRow')
class AiringSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer()();
  IntColumn get episode => integer()();
  DateTimeColumn get airsAt => dateTime()();
  BoolColumn get notified => boolean().withDefault(const Constant(false))();
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
  MediaRelations,
  AiringSchedules,
  AppSettings,
  MetaCache,
])
class TerebiDatabase extends _$TerebiDatabase {
  TerebiDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );
}
