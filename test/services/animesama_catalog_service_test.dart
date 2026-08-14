import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/domain/logic/anime_id.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/services/animesama_catalog_service.dart';
import 'package:terebi/src/services/stream_resolver.dart';

void main() {
  late TerebiDatabase db;
  late MediaRepository mediaRepo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    mediaRepo = MediaRepository(db);
  });
  tearDown(() => db.close());

  test('revalidate ecrit le detail scrappe en DB', () async {
    final service = AnimeSamaCatalogService(
      mediaRepo: mediaRepo,
      fetchDetail: (slug) async => const AnimeSamaDetail(
        slug: 'one-piece', title: 'One Piece',
        synopsis: 'Un pirate', genres: ['Action'],
        cover: 'https://cdn/c.jpg'),
    );
    await service.revalidate('one-piece');
    final id = animeSamaIdForSlug('one-piece');
    final m = await mediaRepo.getMedia(id);
    expect(m, isNotNull);
    expect(m!.description, 'Un pirate');
    expect(m.genres, ['Action']);
    expect(m.animeSamaSlug, 'one-piece');
  });

  test('watchDetail emet l etat DB puis la revalidation', () async {
    final id = animeSamaIdForSlug('bleach');
    await mediaRepo.upsertMedia(
        Media.fromAnimeSama(slug: 'bleach', title: 'Bleach (cache)'));
    var fetchCount = 0;
    final service = AnimeSamaCatalogService(
      mediaRepo: mediaRepo,
      fetchDetail: (slug) async {
        fetchCount++;
        return const AnimeSamaDetail(
            slug: 'bleach', title: 'Bleach', synopsis: 'frais');
      },
      ttl: Duration.zero,
    );
    final emissions = <Media?>[];
    final sub = service.watchDetail('bleach').listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await sub.cancel();
    expect(fetchCount, greaterThanOrEqualTo(1));
    expect(emissions.last?.description, 'frais');
    expect(emissions.first?.anilistId, id);
  });
}
