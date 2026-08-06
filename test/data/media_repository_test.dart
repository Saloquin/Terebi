/// Tests du MediaRepository (upsert, getMedia, watchAllMedia).
library;

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';
import 'package:terebi/src/domain/models/media.dart';

Media _sampleMedia({
  int anilistId = 1,
  String romaji = 'Kimetsu no Yaiba',
  String english = 'Demon Slayer',
  List<String> genres = const ['Action', 'Supernatural'],
  int? episodes = 26,
}) =>
    Media(
      anilistId: anilistId,
      malId: anilistId * 10,
      title: MediaTitle(romaji: romaji, english: english, native: '鬼滅の刃'),
      format: AnimeFormat.tv,
      status: ReleaseStatus.finished,
      episodes: episodes,
      durationMinutes: 24,
      season: AnimeSeason.spring,
      seasonYear: 2019,
      coverUrl: 'https://img/cover.jpg',
      bannerUrl: 'https://img/banner.jpg',
      description: 'A boy becomes a demon slayer.',
      genres: genres,
      averageScore: 85,
    );

void main() {
  late TerebiDatabase db;
  late MediaRepository repo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MediaRepository', () {
    test('getMedia retourne null si absent', () async {
      expect(await repo.getMedia(999), isNull);
    });

    test('upsertMedia + getMedia round-trip complet', () async {
      final media = _sampleMedia();
      await repo.upsertMedia(media);

      final result = await repo.getMedia(1);
      expect(result, isNotNull);
      expect(result!.anilistId, 1);
      expect(result.malId, 10);
      expect(result.title.romaji, 'Kimetsu no Yaiba');
      expect(result.title.english, 'Demon Slayer');
      expect(result.title.native, '鬼滅の刃');
      expect(result.format, AnimeFormat.tv);
      expect(result.status, ReleaseStatus.finished);
      expect(result.episodes, 26);
      expect(result.durationMinutes, 24);
      expect(result.season, AnimeSeason.spring);
      expect(result.seasonYear, 2019);
      expect(result.coverUrl, 'https://img/cover.jpg');
      expect(result.bannerUrl, 'https://img/banner.jpg');
      expect(result.description, 'A boy becomes a demon slayer.');
      expect(result.genres, ['Action', 'Supernatural']);
      expect(result.averageScore, 85);
    });

    test('upsertMedia remplace un média existant', () async {
      await repo.upsertMedia(_sampleMedia(episodes: 26));
      await repo.upsertMedia(_sampleMedia(episodes: 44));

      final result = await repo.getMedia(1);
      expect(result!.episodes, 44);
    });

    test('genres vides sérialisés correctement', () async {
      await repo.upsertMedia(_sampleMedia(genres: []));
      final result = await repo.getMedia(1);
      expect(result!.genres, isEmpty);
    });

    test('plusieurs médias insérés', () async {
      await repo.upsertMedia(_sampleMedia(anilistId: 1));
      await repo.upsertMedia(_sampleMedia(anilistId: 2));
      await repo.upsertMedia(_sampleMedia(anilistId: 3));

      expect(await repo.getMedia(1), isNotNull);
      expect(await repo.getMedia(2), isNotNull);
      expect(await repo.getMedia(3), isNotNull);
      expect(await repo.getMedia(4), isNull);
    });
  });
}
