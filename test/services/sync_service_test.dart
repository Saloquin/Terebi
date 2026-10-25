import 'dart:convert';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/auth_repository.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/data/repositories/progress_repository.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/data/repositories/watch_history_repository.dart';
import 'package:terebi/src/domain/models/episode_progress.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/watch_history_entry.dart';
import 'package:terebi/src/services/sync_service.dart';

void main() {
  late TerebiDatabase db;
  late SettingsRepository settings;
  late AuthRepository authRepo;
  late ListRepository listRepo;
  late ProgressRepository progressRepo;
  late WatchHistoryRepository historyRepo;
  late SyncService syncService;

  setUp(() async {
    db = TerebiDatabase(NativeDatabase.memory());
    settings = SettingsRepository(db);
    authRepo = AuthRepository(settings);
    final mediaRepo = MediaRepository(db);
    listRepo = ListRepository(db);
    progressRepo = ProgressRepository(db);
    historyRepo = WatchHistoryRepository(db);

    syncService = SyncService(
      db: db,
      authRepo: authRepo,
      mediaRepo: mediaRepo,
      listRepo: listRepo,
      progressRepo: progressRepo,
      historyRepo: historyRepo,
      settingsRepo: settings,
    );

    // Initialisation locale
    await syncService.getPendingQueueCount();
  });

  tearDown(() async {
    syncService.dispose();
    await db.close();
  });

  test('Table sync_queue est bien créée et initialement vide', () async {
    final count = await syncService.getPendingQueueCount();
    expect(count, equals(0));
  });

  test('Enqueue et coalescing sur EpisodeProgress évite d\'empiler les doublons', () async {
    // Simule une session utilisateur connectée
    await settings.set('auth_session_token', 'test_token');
    await settings.set('auth_user_id', 'user_123');
    await settings.set('auth_cached_user', jsonEncode({
      'id': 'user_123',
      'username': 'Thomas',
      'email': null,
      'avatarStyle': 'lorelei',
      'avatarSeed': 'Thomas',
      'avatarUrl': null,
      'bio': '',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }));

    final now = DateTime.now();

    // 1ère position : 100.0 secondes
    await syncService.enqueueEpisodeProgress(EpisodeProgress(
      mediaId: 42,
      episodeNumber: 1.0,
      positionSeconds: 100.0,
      updatedAt: now,
    ));

    var count = await syncService.getPendingQueueCount();
    expect(count, equals(1));

    // 2ème position pour le MÊME épisode (ex: 200.0s) -> doit remplacer l'ancien
    await syncService.enqueueEpisodeProgress(EpisodeProgress(
      mediaId: 42,
      episodeNumber: 1.0,
      positionSeconds: 200.0,
      updatedAt: now.add(const Duration(seconds: 10)),
    ));

    count = await syncService.getPendingQueueCount();
    expect(count, equals(1)); // Coalescing : toujours 1 seule entrée dans la file d'attente !

    // Vérifie le contenu dans SQLite
    final rows = await db.customSelect('SELECT payload FROM sync_queue').get();
    expect(rows.length, equals(1));
    final payload = jsonDecode(rows.first.data['payload'] as String);
    expect(payload['positionSeconds'], equals(200.0));
  });

  test('Enqueue et coalescing sur ListEntry', () async {
    await settings.set('auth_session_token', 'test_token');
    await settings.set('auth_user_id', 'user_123');
    await settings.set('auth_cached_user', jsonEncode({
      'id': 'user_123',
      'username': 'Thomas',
      'email': null,
      'avatarStyle': 'lorelei',
      'avatarSeed': 'Thomas',
      'avatarUrl': null,
      'bio': '',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }));

    final now = DateTime.now();

    // Ajout planning
    await syncService.enqueueListEntry(ListEntry(
      mediaId: 101,
      status: ListStatus.planning,
      updatedAt: now,
    ));

    expect(await syncService.getPendingQueueCount(), equals(1));

    // Passage en cours avec progrès 3
    await syncService.enqueueListEntry(ListEntry(
      mediaId: 101,
      status: ListStatus.current,
      progress: 3,
      updatedAt: now.add(const Duration(seconds: 5)),
    ));

    expect(await syncService.getPendingQueueCount(), equals(1));

    final rows = await db.customSelect('SELECT payload FROM sync_queue').get();
    final payload = jsonDecode(rows.first.data['payload'] as String);
    expect(payload['status'], equals('current'));
    expect(payload['progress'], equals(3));
  });

  test('Enqueue WatchHistoryEntry accumule les sessions sans collision', () async {
    await settings.set('auth_session_token', 'test_token');
    await settings.set('auth_user_id', 'user_123');
    await settings.set('auth_cached_user', jsonEncode({
      'id': 'user_123',
      'username': 'Thomas',
      'email': null,
      'avatarStyle': 'lorelei',
      'avatarSeed': 'Thomas',
      'avatarUrl': null,
      'bio': '',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }));

    final t1 = DateTime(2026, 10, 24, 20, 0);
    final t2 = DateTime(2026, 10, 24, 21, 0);

    await syncService.enqueueWatchHistory(WatchHistoryEntry(
      mediaId: 99,
      episodeNumber: 1.0,
      startedAt: t1,
    ));

    await syncService.enqueueWatchHistory(WatchHistoryEntry(
      mediaId: 99,
      episodeNumber: 2.0,
      startedAt: t2,
    ));

    expect(await syncService.getPendingQueueCount(), equals(2));
  });

  test('MediaRepository persiste et restitue correctement un Media Anime-Sama complet', () async {
    final mediaRepo = MediaRepository(db);
    final media = Media.fromAnimeSama(
      slug: 'death-note',
      title: 'Death Note',
      synopsis: 'Cahier de la mort',
      genres: ['Thriller', 'Surnaturel'],
    );
    await mediaRepo.upsertMedia(media);

    final retrieved = await mediaRepo.getMedia(media.mediaId);
    expect(retrieved, isNotNull);
    expect(retrieved!.title.preferred, equals('Death Note'));
    expect(retrieved.animeSamaSlug, equals('death-note'));
    expect(retrieved.description, equals('Cahier de la mort'));
    expect(retrieved.genres, contains('Thriller'));
  });
}
