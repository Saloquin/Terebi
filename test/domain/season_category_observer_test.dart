/// Tests du SeasonCategoryObserver (patron observateur à la modification des variables).
library;

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/domain/logic/effective_status_service.dart';
import 'package:terebi/src/domain/logic/season_category_observer.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/season_progress_repository.dart';

void main() {
  late TerebiDatabase db;
  late SettingsRepository settings;
  late ListRepository listRepo;
  late SeasonProgressRepository seasonProgress;
  late SeasonCategoryObserver observer;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    settings = SettingsRepository(db);
    listRepo = ListRepository(db);
    seasonProgress = SeasonProgressRepository(settings);
    observer = SeasonCategoryObserver(
      listRepo: listRepo,
      settings: settings,
    );
    seasonProgress.addObserver(observer);
  });

  tearDown(() async => db.close());

  group('SeasonCategoryObserver', () {
    test('anime absent de la bibliothèque : aucune action ni crash', () async {
      await seasonProgress.setTotalEpisodes(42, 1, 12);
      await seasonProgress.setLastWatched(42, 1, 5);
      final entry = await listRepo.getEntry(42);
      expect(entry, isNull);
    });

    test(
        'anime terminé : l\'augmentation du max (15/16) le rétrograde en « En cours » avec tag nouveau',
        () async {
      const mediaId = 529644789;
      // Anime marqué terminé en bibliothèque avec 15 épisodes vus
      await listRepo.upsertEntry(ListEntry(
        mediaId: mediaId,
        status: ListStatus.completed,
        progress: 15,
        updatedAt: DateTime.now(),
      ));
      await seasonProgress.setLastWatched(mediaId, 1, 15);

      // Le recheck ou la fiche découvre qu'il y a 16 épisodes max
      await seasonProgress.setTotalEpisodes(mediaId, 1, 16);

      // Vérification que le setter a déclenché l'observateur
      final updated = await listRepo.getEntry(mediaId);
      expect(updated, isNotNull);
      // Déplacé dans planning (effectif = En cours)
      expect(updated!.status, ListStatus.planning);
      // Tag new_episode activé
      expect(await settings.get(SettingsKeys.newEpisodeFor(mediaId)), '1');

      // Statut effectif vérifié
      final eff = effectiveStatus(
        entry: updated,
        hasProgress: true,
        hasNewEpisode: true,
      );
      expect(eff, ListStatus.current);
    });

    test(
        'anime en cours : regarder le dernier épisode (16/16) le déplace dans « Terminée » et retire le tag',
        () async {
      const mediaId = 529644789;
      await listRepo.upsertEntry(ListEntry(
        mediaId: mediaId,
        status: ListStatus.planning,
        progress: 15,
        updatedAt: DateTime.now(),
      ));
      await settings.set(SettingsKeys.newEpisodeFor(mediaId), '1');
      await seasonProgress.setTotalEpisodes(mediaId, 1, 16);
      await seasonProgress.setLastWatched(mediaId, 1, 15);

      // L'utilisateur regarde l'épisode 16
      await seasonProgress.setLastWatched(mediaId, 1, 16);

      final updated = await listRepo.getEntry(mediaId);
      expect(updated, isNotNull);
      expect(updated!.status, ListStatus.completed);
      expect(updated.progress, 16);
      expect(await settings.get(SettingsKeys.newEpisodeFor(mediaId)), isNull);
    });

    test('multi-saisons : ne passe terminé QUE si toutes les saisons sont vues',
        () async {
      const mediaId = 100;
      await listRepo.upsertEntry(ListEntry(
        mediaId: mediaId,
        status: ListStatus.planning,
        progress: 12,
        updatedAt: DateTime.now(),
      ));

      // Saison 1 : 12/12
      await seasonProgress.setTotalEpisodes(mediaId, 1, 12);
      await seasonProgress.setLastWatched(mediaId, 1, 12);

      // Saison 2 : 15/16 (non terminée)
      await seasonProgress.setTotalEpisodes(mediaId, 2, 16);
      await seasonProgress.setLastWatched(mediaId, 2, 15);

      var entry = await listRepo.getEntry(mediaId);
      expect(entry!.status, ListStatus.planning);
      expect(await settings.get(SettingsKeys.newEpisodeFor(mediaId)), '1');

      // Termine la saison 2
      await seasonProgress.setLastWatched(mediaId, 2, 16);

      entry = await listRepo.getEntry(mediaId);
      expect(entry!.status, ListStatus.completed);
      expect(entry.progress, 28); // 12 + 16
      expect(await settings.get(SettingsKeys.newEpisodeFor(mediaId)), isNull);
    });

    test('statuts gelés (paused/dropped/repeating) non modifiés automatiquement',
        () async {
      const mediaId = 200;
      await listRepo.upsertEntry(ListEntry(
        mediaId: mediaId,
        status: ListStatus.paused,
        progress: 5,
        updatedAt: DateTime.now(),
      ));

      await seasonProgress.setTotalEpisodes(mediaId, 1, 12);
      await seasonProgress.setLastWatched(mediaId, 1, 5);

      final entry = await listRepo.getEntry(mediaId);
      // Reste en pause malgré la progression
      expect(entry!.status, ListStatus.paused);
    });

    test('marquer une saison non vue (compteur à 0) retire le statut terminé',
        () async {
      const mediaId = 300;
      await listRepo.upsertEntry(ListEntry(
        mediaId: mediaId,
        status: ListStatus.completed,
        progress: 12,
        updatedAt: DateTime.now(),
      ));
      await seasonProgress.setTotalEpisodes(mediaId, 1, 12);
      await seasonProgress.setLastWatched(mediaId, 1, 12);

      // Remise à zéro
      await seasonProgress.setLastWatched(mediaId, 1, 0);

      final entry = await listRepo.getEntry(mediaId);
      expect(entry!.status, ListStatus.planning);
    });
  });
}
