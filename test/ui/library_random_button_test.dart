import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/app/providers.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/ui/mobile/library_page_mobile.dart';
import 'package:terebi/src/ui/pages/library_page.dart';
import 'package:terebi/src/ui/tv/library_page_tv.dart';

Media _media(int id, String title) => Media(
      mediaId: id,
      title: MediaTitle(romaji: title, english: title),
      animeSamaTitle: title,
      animeSamaSlug: title.toLowerCase().replaceAll(' ', '-'),
    );

ListEntry _entry(int id, ListStatus status) => ListEntry(
      mediaId: id,
      status: status,
      updatedAt: DateTime(2026),
    );

void main() {
  group('Bouton aléatoire dans Ma Liste (TV / Desktop / Mobile)', () {
    testWidgets('LibraryPageTv affiche Reprendre / Lancer au hasard selon l’onglet',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final m1 = _media(1, 'Anime En Cours');
      final m2 = _media(2, 'Anime Planifie');
      final m3 = _media(3, 'Anime Termine');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            allMediaMapProvider.overrideWith(
              (ref) => Stream.value({1: m1, 2: m2, 3: m3}),
            ),
            countByStatusProvider.overrideWithValue(
              const AsyncValue.data({
                ListStatus.current: 1,
                ListStatus.planning: 1,
                ListStatus.completed: 1,
              }),
            ),
            entriesByStatusProvider.overrideWith((ref, status) {
              return switch (status) {
                ListStatus.current => AsyncValue.data([_entry(1, status)]),
                ListStatus.planning => AsyncValue.data([_entry(2, status)]),
                ListStatus.completed => AsyncValue.data([_entry(3, status)]),
                _ => const AsyncValue.data(<ListEntry>[]),
              };
            }),
          ],
          child: const MaterialApp(home: LibraryPageTv()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Reprendre au hasard'), findsOneWidget);
      expect(find.text('Lancer au hasard'), findsNothing);

      await tester.tap(find.text('Planifié'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Lancer au hasard'), findsOneWidget);
      expect(find.text('Reprendre au hasard'), findsNothing);

      await tester.tap(find.text('Terminé'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Lancer au hasard'), findsNothing);
      expect(find.text('Reprendre au hasard'), findsNothing);
    });

    testWidgets('LibraryPage (Desktop) affiche Reprendre / Lancer au hasard selon l’onglet',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = MediaRepository(db);
      await repo.upsertMedia(_media(1, 'Anime En Cours'));
      await repo.upsertMedia(_media(2, 'Anime Planifie'));
      await repo.upsertMedia(_media(3, 'Anime Termine'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            newEpisodeIdsProvider.overrideWith((ref) => Stream.value(<int>{})),
            newEpisodeFlagProvider.overrideWith((ref, id) async => false),
            countByStatusProvider.overrideWithValue(
              const AsyncValue.data({
                ListStatus.current: 1,
                ListStatus.planning: 1,
                ListStatus.completed: 1,
              }),
            ),
            entriesByStatusProvider.overrideWith((ref, status) {
              return switch (status) {
                ListStatus.current => AsyncValue.data([_entry(1, status)]),
                ListStatus.planning => AsyncValue.data([_entry(2, status)]),
                ListStatus.completed => AsyncValue.data([_entry(3, status)]),
                _ => const AsyncValue.data(<ListEntry>[]),
              };
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: LibraryPage())),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Reprendre au hasard'), findsOneWidget);

      await tester.tap(find.text('Planifié'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Lancer au hasard'), findsOneWidget);

      await tester.tap(find.text('Terminé'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Lancer au hasard'), findsNothing);
      expect(find.text('Reprendre au hasard'), findsNothing);
    });

    testWidgets('LibraryPageMobile affiche Reprendre / Lancer au hasard selon l’onglet',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(420, 840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final m1 = _media(1, 'Anime En Cours');
      final m2 = _media(2, 'Anime Planifie');
      final m3 = _media(3, 'Anime Termine');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            allMediaMapProvider.overrideWith(
              (ref) => Stream.value({1: m1, 2: m2, 3: m3}),
            ),
            newEpisodeIdsProvider.overrideWith((ref) => Stream.value(<int>{})),
            newEpisodeFlagProvider.overrideWith((ref, id) async => false),
            countByStatusProvider.overrideWithValue(
              const AsyncValue.data({
                ListStatus.current: 1,
                ListStatus.planning: 1,
                ListStatus.completed: 1,
              }),
            ),
            entriesByStatusProvider.overrideWith((ref, status) {
              return switch (status) {
                ListStatus.current => AsyncValue.data([_entry(1, status)]),
                ListStatus.planning => AsyncValue.data([_entry(2, status)]),
                ListStatus.completed => AsyncValue.data([_entry(3, status)]),
                _ => const AsyncValue.data(<ListEntry>[]),
              };
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: LibraryPageMobile())),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Reprendre au hasard'), findsOneWidget);

      await tester.tap(find.text('Planifié'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Lancer au hasard'), findsOneWidget);

      await tester.tap(find.text('Terminé'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Lancer au hasard'), findsNothing);
      expect(find.text('Reprendre au hasard'), findsNothing);
    });
  });
}
