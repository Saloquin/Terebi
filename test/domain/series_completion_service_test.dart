/// Tests du SeriesCompletionService (détection série entièrement vue).
library;

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/domain/logic/series_completion_service.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/season_progress_repository.dart';
import 'package:terebi/src/services/stream_resolver.dart' show AnimeSamaSeason;

void main() {
  late TerebiDatabase db;
  late ListRepository listRepo;
  late SeasonProgressRepository seasonProgress;
  late SeriesCompletionService service;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    listRepo = ListRepository(db);
    seasonProgress = SeasonProgressRepository(SettingsRepository(db));
    service = SeriesCompletionService(listRepo, seasonProgress);
  });

  tearDown(() async => db.close());

  // Deux saisons : S1 = épisodes 1..12, S2 = épisodes 13..24 (numérotation
  // cumulée, cas qui cassait l'ancienne comparaison count vs numéro).
  const seasons = [
    AnimeSamaSeason(index: 1, name: 'Saison 1'),
    AnimeSamaSeason(index: 2, name: 'Saison 2'),
  ];
  Future<List<int>> episodes(int seasonIndex) async =>
      seasonIndex == 1 ? const [1, 2, 3, 12] : const [13, 14, 24];

  group('SeriesCompletionService', () {
    test('une saison non finie → false, pas de statut completed', () async {
      // S1 vue (dernier ép 12), S2 pas vue.
      await seasonProgress.setLastWatched(1, 1, 12);
      final result = await service.maybeMarkCompleted(
        mediaId: 1,
        seasons: seasons,
        getEpisodes: episodes,
      );
      expect(result, isFalse);
      expect(await listRepo.getEntry(1), isNull);
    });

    test('épisodes introuvables (liste vide) → false', () async {
      final result = await service.maybeMarkCompleted(
        mediaId: 1,
        seasons: seasons,
        getEpisodes: (_) async => const [],
      );
      expect(result, isFalse);
      expect(await listRepo.getEntry(1), isNull);
    });

    test('toutes saisons vues → true, completed, sentinelle normalisée',
        () async {
      // Marquées via l'ancienne sentinelle : le service doit les normaliser.
      await seasonProgress.markSeasonFullyWatched(1, 1); // sentinelle
      await seasonProgress.markSeasonFullyWatched(1, 2); // sentinelle
      final result = await service.maybeMarkCompleted(
        mediaId: 1,
        seasons: seasons,
        getEpisodes: episodes,
      );
      expect(result, isTrue);
      final entry = await listRepo.getEntry(1);
      expect(entry, isNotNull);
      expect(entry!.status, ListStatus.completed);
      // progress = total épisodes des deux saisons (4 + 3 = 7).
      expect(entry.progress, 7);
      // Plus de sentinelle : chaque saison vaut son dernier numéro d'épisode.
      expect(await seasonProgress.lastWatched(1, 1), 12);
      expect(await seasonProgress.lastWatched(1, 2), 24);
    });

    test('déjà completed → false, no-op', () async {
      await listRepo.upsertEntry(ListEntry(
        mediaId: 1,
        status: ListStatus.completed,
        updatedAt: DateTime.now(),
      ));
      final result = await service.maybeMarkCompleted(
        mediaId: 1,
        seasons: seasons,
        getEpisodes: episodes,
      );
      expect(result, isFalse);
    });

    test('liste de saisons vide → false', () async {
      final result = await service.maybeMarkCompleted(
        mediaId: 1,
        seasons: const [],
        getEpisodes: episodes,
      );
      expect(result, isFalse);
    });

    test('détecte « vu » via le dernier numéro d\'épisode (pas le count)',
        () async {
      // S1 : lastWatched = 12 = eps.last (mais count = 4). S2 : 24 = eps.last.
      await seasonProgress.setLastWatched(1, 1, 12);
      await seasonProgress.setLastWatched(1, 2, 24);
      final result = await service.maybeMarkCompleted(
        mediaId: 1,
        seasons: seasons,
        getEpisodes: episodes,
      );
      expect(result, isTrue);
      expect((await listRepo.getEntry(1))!.status, ListStatus.completed);
    });
  });
}
