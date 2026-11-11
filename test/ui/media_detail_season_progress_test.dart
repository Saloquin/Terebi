import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/app/providers.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/domain/logic/anime_id.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/season_progress_repository.dart';
import 'package:terebi/src/services/animesama_dart_resolver.dart';
import 'package:terebi/src/services/animesama_http_client.dart';
import 'package:terebi/src/services/stream_resolver.dart';
import 'package:terebi/src/ui/pages/media_detail_page.dart';
import 'package:terebi/src/ui/tv/media_detail_page_tv.dart';
import 'package:terebi/src/ui/tv/widgets/tv_seasons_list.dart';

class _FakeResolver extends DartAnimeSamaResolver {
  _FakeResolver()
      : super(
          fetch: (
            _, {
            method = HttpMethod.get,
            headers,
            query,
            followRedirects = true,
          }) async =>
              const HttpResponse(statusCode: 200),
        );

  @override
  Future<List<AnimeSamaCatalogueItem>> search({
    required String query,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async =>
      const [];

  @override
  Future<AnimeSamaDetail?> catalogueDetail({required String slug}) async => null;

  @override
  Future<List<AnimeSamaPlanningItem>> planning({
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async =>
      const [];
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> cleanupWidgetAndDb(WidgetTester tester, TerebiDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(db.close);
  }

  group('Progression épisodes vus sur la fiche détail (anti-bug 0 à l arrivée)',
      () {
    testWidgets(
        'MediaDetailPage affiche immédiatement 7/12 dès l arrivée (pas 0/12)',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());

      // ID canonique basé sur slug avec tiret ('dr-stone'), alors que
      // normalizeAnimeTitle('Dr. Stone') vaut 'dr stone' (avec espace) → sans
      // .withId(mediaId) sur _fallbackMedia, la frame 1 utilisait le mauvais ID !
      final realId = animeSamaIdForSlug('dr-stone');
      await MediaRepository(db).upsertMedia(
        Media(
          mediaId: realId,
          title: const MediaTitle(romaji: 'Dr. Stone'),
          animeSamaTitle: 'Dr. Stone',
          animeSamaSlug: 'dr-stone',
        ),
      );
      final progressRepo = SeasonProgressRepository(SettingsRepository(db));
      await progressRepo.setLastWatched(realId, 1, 7);

      final episodesController = StreamController<List<int>>.broadcast();
      addTearDown(episodesController.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            animeSamaResolverProvider.overrideWith((_) async => _FakeResolver()),
            animeSamaPlanningProvider.overrideWith((_) async => const []),
            animeSamaSeasonsProvider.overrideWith(
              (ref, title) => Stream.value(
                const [AnimeSamaSeason(index: 1, name: 'Saison 1')],
              ),
            ),
            animeSamaEpisodesProvider.overrideWith((ref, arg) async* {
              yield [for (var i = 1; i <= 12; i++) i];
              yield* episodesController.stream;
            }),
          ],
          child: MaterialApp(
            home: MediaDetailPage(
              mediaId: realId,
              displayTitle: 'Dr. Stone',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('7/12'), findsOneWidget);
      expect(find.text('0/12'), findsNothing);

      // Quand la DB / revalidation publie l'épisode 13, la tuile passe à 7/13.
      episodesController.add([for (var i = 1; i <= 13; i++) i]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('7/13'), findsOneWidget);

      await cleanupWidgetAndDb(tester, db);
    });

    testWidgets(
        'MediaDetailPageTv affiche immédiatement 7/12 dès l arrivée (pas 0/12)',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final realId = animeSamaIdForSlug('dr-stone');
      await MediaRepository(db).upsertMedia(
        Media(
          mediaId: realId,
          title: const MediaTitle(romaji: 'Dr. Stone'),
          animeSamaTitle: 'Dr. Stone',
          animeSamaSlug: 'dr-stone',
        ),
      );
      final progressRepo = SeasonProgressRepository(SettingsRepository(db));
      await progressRepo.setLastWatched(realId, 1, 7);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            animeSamaResolverProvider.overrideWith((_) async => _FakeResolver()),
            animeSamaPlanningProvider.overrideWith((_) async => const []),
            animeSamaSeasonsProvider.overrideWith(
              (ref, title) => Stream.value(
                const [AnimeSamaSeason(index: 1, name: 'Saison 1')],
              ),
            ),
            animeSamaEpisodesProvider.overrideWith(
              (ref, arg) => Stream.value([for (var i = 1; i <= 12; i++) i]),
            ),
          ],
          child: MaterialApp(
            home: MediaDetailPageTv(
              mediaId: realId,
              displayTitle: 'Dr. Stone',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('7/12'), findsOneWidget);
      expect(find.text('0/12'), findsNothing);

      await cleanupWidgetAndDb(tester, db);
    });

    testWidgets(
        'TvSeasonsList se recharge si mediaId change après montage ET supporte une nouvelle saison ajoutée en direct',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const wrongId = 111;
      const realId = 222;
      final progressRepo = SeasonProgressRepository(SettingsRepository(db));
      await progressRepo.setLastWatched(realId, 1, 5);
      await progressRepo.setLastWatched(realId, 2, 2);

      final seasonsController =
          StreamController<List<AnimeSamaSeason>>.broadcast();
      addTearDown(seasonsController.close);

      final mediaNotifier = ValueNotifier<Media>(
        const Media(
          mediaId: wrongId,
          title: MediaTitle(romaji: 'Frieren'),
          animeSamaTitle: 'Frieren',
        ),
      );
      addTearDown(mediaNotifier.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            animeSamaPlanningProvider.overrideWith((_) async => const []),
            animeSamaSeasonsProvider.overrideWith((ref, title) async* {
              yield const [AnimeSamaSeason(index: 1, name: 'Saison 1')];
              yield* seasonsController.stream;
            }),
            animeSamaEpisodesProvider.overrideWith(
              (ref, arg) => Stream.value([for (var i = 1; i <= 10; i++) i]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: ValueListenableBuilder<Media>(
                valueListenable: mediaNotifier,
                builder: (_, media, __) => TvSeasonsList(
                  media: media,
                  searchTitle: 'Frieren',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('0/10'), findsOneWidget);

      // Le mediaId réel arrive après la 1re frame : didUpdateWidget doit mettre
      // à jour le compteur à 5/10 sans attendre un aller-retour.
      mediaNotifier.value = const Media(
        mediaId: realId,
        title: MediaTitle(romaji: 'Frieren'),
        animeSamaTitle: 'Frieren',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('5/10'), findsOneWidget);

      // Une 2e saison arrive en direct via Drift sans crasher.
      seasonsController.add(const [
        AnimeSamaSeason(index: 1, name: 'Saison 1'),
        AnimeSamaSeason(index: 2, name: 'Saison 2'),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('5/10'), findsOneWidget);
      expect(find.text('2/10'), findsOneWidget);

      await cleanupWidgetAndDb(tester, db);
    });
  });
}
