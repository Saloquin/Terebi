import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/data/repositories/watch_history_repository.dart';
import 'package:terebi/src/domain/logic/anime_id.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/services/slug_migration_service.dart';

void main() {
  late TerebiDatabase db;
  late MediaRepository mediaRepo;
  late ListRepository listRepo;
  late SettingsRepository settings;
  late WatchHistoryRepository historyRepo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    mediaRepo = MediaRepository(db);
    listRepo = ListRepository(db);
    settings = SettingsRepository(db);
    historyRepo = WatchHistoryRepository(db);
  });
  tearDown(() => db.close());

  test('reindexe media + entree + progression de old vers slug', () async {
    const oldId = -555;
    await mediaRepo.upsertMedia(Media(
      anilistId: oldId,
      title: const MediaTitle(english: 'One Piece'),
      animeSamaTitle: 'One Piece',
    ));
    await listRepo.upsertEntry(ListEntry(
        mediaId: oldId, status: ListStatus.current, progress: 12,
        updatedAt: DateTime.utc(2026)));
    await settings.set('anime_sama_watched:$oldId:1', '12');
    await historyRepo.record(
        mediaId: oldId, episodeNumber: 5, startedAt: DateTime.utc(2026));

    final service = SlugMigrationService(
      mediaRepo: mediaRepo,
      listRepo: listRepo,
      settings: settings,
      historyRepo: historyRepo,
      resolveSlug: (title) async => 'one-piece',
    );
    await service.runOnce();

    final newId = animeSamaIdForSlug('one-piece');
    expect(await mediaRepo.getMedia(oldId), isNull);
    final migrated = await mediaRepo.getMedia(newId);
    expect(migrated, isNotNull);
    expect(migrated!.animeSamaSlug, 'one-piece');
    final entry = await listRepo.getEntry(newId);
    expect(entry?.progress, 12);
    expect(await settings.get('anime_sama_watched:$newId:1'), '12');
    expect(await settings.get('anime_sama_watched:$oldId:1'), isNull);
    // L'historique de visionnage suit aussi le nouvel id (sinon 'Regarde
    // recemment' devient orphelin).
    final hist = await historyRepo.all();
    expect(hist, hasLength(1));
    expect(hist.first.mediaId, newId);
    expect(await settings.get('slug_migration_done'), '1');
  });

  test('runOnce est idempotent (ne rejoue pas si drapeau pose)', () async {
    await settings.set('slug_migration_done', '1');
    var called = 0;
    final service = SlugMigrationService(
      mediaRepo: mediaRepo, listRepo: listRepo, settings: settings,
      historyRepo: historyRepo,
      resolveSlug: (title) async { called++; return 'x'; },
    );
    await service.runOnce();
    expect(called, 0);
  });

  test('media non resolu -> logue dans le rapport, jamais supprime', () async {
    const oldId = -9;
    await mediaRepo.upsertMedia(Media(
      anilistId: oldId, title: const MediaTitle(english: 'Introuvable'),
      animeSamaTitle: 'Introuvable'));
    final service = SlugMigrationService(
      mediaRepo: mediaRepo, listRepo: listRepo, settings: settings,
      historyRepo: historyRepo,
      resolveSlug: (title) async => '',
    );
    await service.runOnce();
    expect(await mediaRepo.getMedia(oldId), isNotNull);
    final report = await settings.get('slug_migration_report');
    expect(report, contains('Introuvable'));
  });
}
