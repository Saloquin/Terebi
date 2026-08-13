import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/remote/anilist_client.dart';
import 'package:terebi/src/data/remote/cached_anilist_client.dart';
import 'package:terebi/src/data/remote/request_queue.dart';
import 'package:terebi/src/data/repositories/meta_cache_repository.dart';
import 'package:terebi/src/domain/models/airing_schedule.dart';
import 'package:terebi/src/domain/models/enums.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/media_relation.dart';

/// Faux client qui compte les appels réseau et renvoie des données fixes.
class _FakeApi implements AniListApi {
  int searchCalls = 0;
  int seasonCalls = 0;
  int detailCalls = 0;

  final List<Media> results;
  _FakeApi(this.results);

  @override
  Future<List<Media>> search(String query, {int page = 1, int perPage = 20}) async {
    searchCalls++;
    return results;
  }

  @override
  Future<List<Media>> season(AnimeSeason season, int year,
      {int page = 1, int perPage = 50}) async {
    seasonCalls++;
    return results;
  }

  @override
  Future<Media> mediaDetail(int anilistId) async {
    detailCalls++;
    return results.first;
  }

  @override
  Future<List<MediaRelation>> relations(int anilistId) async => const [];

  @override
  Future<AiringSchedule?> nextAiring(int anilistId) async => null;

  @override
  Future<List<Media>> trending({int page = 1, int perPage = 20}) async =>
      results;

  @override
  Future<List<Media>> popular({int page = 1, int perPage = 20}) async =>
      results;

  @override
  Future<List<Media>> byGenre(String genre,
          {int page = 1, int perPage = 20}) async =>
      results;
}

void main() {
  late TerebiDatabase db;
  late MetaCacheRepository cache;
  late _FakeApi fake;

  final media = [
    Media(anilistId: 1, title: const MediaTitle(romaji: 'One Piece')),
    Media(anilistId: 2, title: const MediaTitle(romaji: 'Bleach')),
  ];

  // Queue sans attente réelle pour les tests.
  RequestQueue fastQueue() => RequestQueue(sleep: (_) async {});

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    cache = MetaCacheRepository(db);
    fake = _FakeApi(media);
  });

  tearDown(() async => db.close());

  test('cache miss puis hit : 1 seul appel réseau', () async {
    var t = DateTime.utc(2024, 1, 1, 12);
    final client = CachedAniListClient(
      inner: fake,
      cache: cache,
      queue: fastQueue(),
      now: () => t,
    );

    final r1 = await client.search('one piece');
    expect(r1.map((m) => m.anilistId), [1, 2]);
    expect(fake.searchCalls, 1);

    // 2e appel identique, peu après → doit venir du cache.
    t = DateTime.utc(2024, 1, 1, 12, 5);
    final r2 = await client.search('one piece');
    expect(r2.map((m) => m.anilistId), [1, 2]);
    expect(fake.searchCalls, 1, reason: 'aucun nouvel appel réseau (cache hit)');
  });

  test('TTL expiré : refetch réseau', () async {
    var t = DateTime.utc(2024, 1, 1, 12);
    final client = CachedAniListClient(
      inner: fake, cache: cache, queue: fastQueue(), now: () => t);

    await client.search('naruto');
    expect(fake.searchCalls, 1);

    // Métadonnées : TTL 7 jours → au-delà, refetch.
    t = DateTime.utc(2024, 1, 9, 12);
    await client.search('naruto');
    expect(fake.searchCalls, 2);
  });

  test('season : TTL court (1h) pour rester frais', () async {
    var t = DateTime.utc(2024, 1, 1, 12);
    final client = CachedAniListClient(
      inner: fake, cache: cache, queue: fastQueue(), now: () => t);

    await client.season(AnimeSeason.winter, 2024);
    expect(fake.seasonCalls, 1);

    // +30 min → encore frais (cache).
    t = DateTime.utc(2024, 1, 1, 12, 30);
    await client.season(AnimeSeason.winter, 2024);
    expect(fake.seasonCalls, 1);

    // +2 h → expiré → refetch.
    t = DateTime.utc(2024, 1, 1, 14, 1);
    await client.season(AnimeSeason.winter, 2024);
    expect(fake.seasonCalls, 2);
  });

  test('forceRefresh : ignore le cache en lecture', () async {
    final t = DateTime.utc(2024, 1, 1, 12);
    final cached = CachedAniListClient(
      inner: fake, cache: cache, queue: fastQueue(), now: () => t);
    await cached.search('x');
    expect(fake.searchCalls, 1);

    final forced = CachedAniListClient(
      inner: fake, cache: cache, queue: fastQueue(), now: () => t,
      forceRefresh: true);
    await forced.search('x');
    expect(fake.searchCalls, 2, reason: 'forceRefresh rappelle le réseau');
  });

  test('mediaDetail mis en cache', () async {
    final t = DateTime.utc(2024, 1, 1, 12);
    final client = CachedAniListClient(
      inner: fake, cache: cache, queue: fastQueue(), now: () => t);
    await client.mediaDetail(1);
    await client.mediaDetail(1);
    expect(fake.detailCalls, 1);
  });
}
