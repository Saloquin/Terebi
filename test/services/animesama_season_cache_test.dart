import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/data/repositories/meta_cache_repository.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/domain/logic/season_category_observer.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/season_progress_repository.dart';
import 'package:terebi/src/services/animesama_season_cache.dart';
import 'package:terebi/src/services/stream_resolver.dart';

void main() {
  group('mergeCachedAndFreshSeasons', () {
    const s1 = AnimeSamaSeason(index: 1, name: 'Saison 1');
    const s2 = AnimeSamaSeason(index: 2, name: 'Saison 2');
    const s3 = AnimeSamaSeason(index: 3, name: 'Saison 3');
    const oav = AnimeSamaSeason(index: 2, name: 'OAV');
    const oav3 = AnimeSamaSeason(index: 3, name: 'OAV');

    test('conserve le cache si la réponse fraîche est vide', () {
      expect(mergeCachedAndFreshSeasons([s1, s2], const []), [s1, s2]);
    });

    test('utilise la réponse fraîche si le cache est vide', () {
      expect(mergeCachedAndFreshSeasons(const [], [s1, s2]), [s1, s2]);
    });

    test('ajoute les nouvelles saisons lorsque la liste fraîche grandit', () {
      expect(mergeCachedAndFreshSeasons([s1, s2], [s1, s2, s3]), [s1, s2, s3]);
    });

    test('auto-répare un ancien cache partiel quand le scraping complet revient',
        () {
      // Avant correction v2.3.5 : Saison 2 avait été sautée, OAV était à index 2.
      // Quand le scraping retrouve [Saison 1, Saison 2, OAV], il remplace.
      expect(
        mergeCachedAndFreshSeasons([s1, oav], [s1, s2, oav3]),
        [s1, s2, oav3],
      );
    });

    test(
        'ne supprime JAMAIS une saison si le scraping tronque la liste (ex. saison sautée au milieu)',
        () {
      // Simule un scraping cassé qui saute Saison 2 : Saison 3 se retrouve en index 2.
      const brokenS3AtIndex2 = AnimeSamaSeason(index: 2, name: 'Saison 3');
      expect(
        mergeCachedAndFreshSeasons([s1, s2, s3], [s1, brokenS3AtIndex2]),
        [s1, s2, s3],
      );
    });

    test('ne supprime pas les saisons de fin si seule Saison 1 est renvoyée',
        () {
      expect(mergeCachedAndFreshSeasons([s1, s2, s3], [s1]), [s1, s2, s3]);
    });
  });

  group('mergeCachedAndFreshEpisodes', () {
    test('conserve les épisodes en cache si la réponse fraîche est vide', () {
      expect(mergeCachedAndFreshEpisodes([1, 2, 3], const []), [1, 2, 3]);
    });

    test('fusionne en union triée sans perte lors d une réponse partielle', () {
      expect(
        mergeCachedAndFreshEpisodes([1, 2, 3, 4], [2, 3]),
        [1, 2, 3, 4],
      );
      expect(
        mergeCachedAndFreshEpisodes([1, 2, 3], [1, 2, 3, 4, 5]),
        [1, 2, 3, 4, 5],
      );
    });
  });

  group('AnimeSamaSeasonCacheService & MetaCacheRepository', () {
    late TerebiDatabase db;
    late MetaCacheRepository cacheRepo;

    setUp(() {
      db = TerebiDatabase(NativeDatabase.memory());
      cacheRepo = MetaCacheRepository(db);
    });

    tearDown(() => db.close());

    test('sert immédiatement la base quand le cache est frais (0 appel réseau)',
        () async {
      var now = DateTime.utc(2026, 5, 1, 12, 0);
      var fetchCalls = 0;

      final service = AnimeSamaSeasonCacheService(
        cache: cacheRepo,
        fetchSeasons: (_, __) async {
          fetchCalls++;
          return const [AnimeSamaSeason(index: 1, name: 'Saison 1')];
        },
        fetchEpisodes: (_, __, ___) async => const [1, 2, 3],
        now: () => now,
      );

      // Premier appel : peuple la base.
      final initial = await service.watchSeasons('Dr. Stone').first;
      expect(initial, const [AnimeSamaSeason(index: 1, name: 'Saison 1')]);
      expect(fetchCalls, 1);

      // Deuxième observation 1h plus tard (< TTL 6h) : lit la DB sans réseau.
      now = now.add(const Duration(hours: 1));
      final emissions = <List<AnimeSamaSeason>>[];
      final sub = service.watchSeasons('dr. stone').listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await sub.cancel();

      expect(emissions, [
        const [AnimeSamaSeason(index: 1, name: 'Saison 1')],
      ]);
      expect(fetchCalls, 1);
    });

    test(
        'cache périmé (> 6h) : émet la DB immédiatement puis revalide et pousse les nouveautés',
        () async {
      var now = DateTime.utc(2026, 5, 1, 12, 0);
      var returnTwoSeasons = false;
      var fetchCalls = 0;

      final service = AnimeSamaSeasonCacheService(
        cache: cacheRepo,
        fetchSeasons: (_, __) async {
          fetchCalls++;
          return returnTwoSeasons
              ? const [
                  AnimeSamaSeason(index: 1, name: 'Saison 1'),
                  AnimeSamaSeason(index: 2, name: 'Saison 2'),
                ]
              : const [AnimeSamaSeason(index: 1, name: 'Saison 1')];
        },
        fetchEpisodes: (_, seasonIndex, __) async {
          return seasonIndex == 1 ? const [1, 2] : const [1, 2, 3];
        },
        now: () => now,
      );

      await service.refreshSeasons('Solo Leveling');
      expect(fetchCalls, 1);

      // Avance de 7h (>= TTL 6h) et simule la sortie de la Saison 2.
      now = now.add(const Duration(hours: 7));
      returnTwoSeasons = true;

      final emissions = <List<AnimeSamaSeason>>[];
      final sub = service.watchSeasons('Solo Leveling').listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sub.cancel();

      expect(fetchCalls, 2);
      expect(emissions.length, 2);
      expect(emissions.first, const [AnimeSamaSeason(index: 1, name: 'Saison 1')]);
      expect(emissions.last, const [
        AnimeSamaSeason(index: 1, name: 'Saison 1'),
        AnimeSamaSeason(index: 2, name: 'Saison 2'),
      ]);
    });

    test(
        'cache périmé + erreur réseau : conserve les saisons en DB sans erreur ni effacement',
        () async {
      var now = DateTime.utc(2026, 5, 1, 12, 0);
      var failNetwork = false;

      final service = AnimeSamaSeasonCacheService(
        cache: cacheRepo,
        fetchSeasons: (_, __) async {
          if (failNetwork) throw const ResolveException('réseau coupé');
          return const [
            AnimeSamaSeason(index: 1, name: 'Saison 1'),
            AnimeSamaSeason(index: 2, name: 'Saison 2'),
          ];
        },
        fetchEpisodes: (_, __, ___) async => const [1, 2, 3],
        now: () => now,
      );

      await service.refreshSeasons('Frieren');

      now = now.add(const Duration(days: 10));
      failNetwork = true;

      final emissions = <List<AnimeSamaSeason>>[];
      final errors = <Object>[];
      final sub = service
          .watchSeasons('Frieren')
          .listen(emissions.add, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(errors, isEmpty);
      expect(emissions, [
        const [
          AnimeSamaSeason(index: 1, name: 'Saison 1'),
          AnimeSamaSeason(index: 2, name: 'Saison 2'),
        ],
      ]);
      expect(await service.getCachedSeasons('Frieren'), hasLength(2));
    });

    test('base vide + erreur réseau : remonte bien l erreur au flux', () async {
      final service = AnimeSamaSeasonCacheService(
        cache: cacheRepo,
        fetchSeasons: (_, __) async =>
            throw const ResolveException('anime introuvable'),
        fetchEpisodes: (_, __, ___) async => const [],
      );

      await expectLater(
        service.watchSeasons('Inconnu'),
        emitsError(isA<ResolveException>()),
      );
    });

    test('watchEpisodes : sert la DB et fusionne un nouvel épisode sans perte',
        () async {
      var now = DateTime.utc(2026, 5, 1, 12, 0);
      var serverEps = [1, 2, 3, 4];

      final service = AnimeSamaSeasonCacheService(
        cache: cacheRepo,
        fetchSeasons: (_, __) async =>
            const [AnimeSamaSeason(index: 1, name: 'Saison 1')],
        fetchEpisodes: (_, __, ___) async => List<int>.from(serverEps),
        now: () => now,
      );

      await service.refreshEpisodes('Dandadan', 1);

      // 8h plus tard : serveur ajoute ep 5, puis un scrape cassé n'en renvoie que [1, 2]
      now = now.add(const Duration(hours: 8));
      serverEps = [1, 2, 3, 4, 5];

      final emissions = <List<int>>[];
      final sub =
          service.watchEpisodes('Dandadan', 1).listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sub.cancel();

      expect(emissions.first, [1, 2, 3, 4]);
      expect(emissions.last, [1, 2, 3, 4, 5]);

      // Scraping cassé (tronqué à [1, 2]) ne fait pas régresser le cache DB.
      serverEps = [1, 2];
      final refreshed = await service.refreshEpisodes('Dandadan', 1);
      expect(refreshed, [1, 2, 3, 4, 5]);
    });

    test('déduplique les refreshSeasons concurrents en une seule requête',
        () async {
      var calls = 0;
      final service = AnimeSamaSeasonCacheService(
        cache: cacheRepo,
        fetchSeasons: (_, __) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const [AnimeSamaSeason(index: 1, name: 'Saison 1')];
        },
        fetchEpisodes: (_, __, ___) async => const [1],
      );

      final results = await Future.wait([
        service.refreshSeasons('Kaiju No. 8'),
        service.refreshSeasons('kaiju no. 8'),
        service.refreshSeasons(' Kaiju No. 8 '),
      ]);

      expect(calls, 1);
      for (final r in results) {
        expect(r, const [AnimeSamaSeason(index: 1, name: 'Saison 1')]);
      }
    });

    test('intégration SeasonCategoryObserver : saison restaurée sort un anime de Terminé',
        () async {
      final settings = SettingsRepository(db);
      final listRepo = ListRepository(db);
      final progressRepo = SeasonProgressRepository(settings);
      progressRepo.addObserver(
        SeasonCategoryObserver(listRepo: listRepo, settings: settings),
      );

      const mediaId = 777;
      await listRepo.upsertEntry(ListEntry(
        mediaId: mediaId,
        status: ListStatus.completed,
        progress: 12,
        updatedAt: DateTime.utc(2026, 5, 1),
      ));
      await progressRepo.setTotalEpisodes(mediaId, 1, 12);
      await progressRepo.setLastWatched(mediaId, 1, 12);

      // Le recheck bibliothèque découvre la Saison 2 avec 12 épisodes (0 vus) :
      await progressRepo.setTotalEpisodes(mediaId, 2, 12);

      final updated = await listRepo.getEntry(mediaId);
      expect(updated?.status, ListStatus.planning);
    });
  });
}
