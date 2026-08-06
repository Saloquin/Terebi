/// Widget tests pour les pages UI de Terebi.
///
/// Stratégie : ProviderScope(overrides: [...]) pour injecter des faux clients/repos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terebi/src/app/providers.dart';
import 'package:terebi/src/data/remote/anilist_client.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/media_relation.dart';
import 'package:terebi/src/ui/pages/catalog_page.dart';
import 'package:terebi/src/ui/pages/library_page.dart';
import 'package:terebi/src/ui/widgets/media_card.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Faux AniListClient retournant une liste fixe ou vide.
class _FakeAniListClient extends AniListClient {
  final List<Media> searchResults;

  _FakeAniListClient({this.searchResults = const []});

  @override
  Future<List<Media>> search(String query,
          {int page = 1, int perPage = 20}) async =>
      searchResults;

  @override
  Future<List<Media>> season(AnimeSeason season, int year,
          {int page = 1, int perPage = 50}) async =>
      const [];

  @override
  Future<Media> mediaDetail(int anilistId) async =>
      searchResults.firstWhere((m) => m.anilistId == anilistId,
          orElse: () => _makeMedia(anilistId));

  @override
  Future<List<MediaRelation>> relations(int anilistId) async => const [];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Media _makeMedia(int id, {String? title, int? episodes, AnimeFormat? format}) =>
    Media(
      anilistId: id,
      title: MediaTitle(
        english: title ?? 'Anime $id',
        romaji: title ?? 'Anime $id',
      ),
      episodes: episodes ?? 12,
      format: format ?? AnimeFormat.tv,
    );

/// Enveloppe un widget dans MaterialApp + ProviderScope avec overrides.
Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

// ---------------------------------------------------------------------------
// Tests : MediaCard
// ---------------------------------------------------------------------------

void main() {
  group('MediaCard', () {
    testWidgets('affiche le titre préféré', (tester) async {
      final media = _makeMedia(1, title: 'Attack on Titan', episodes: 25);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MediaCard(media: media))),
      );
      expect(find.text('Attack on Titan'), findsOneWidget);
    });

    testWidgets('affiche le badge avec le nombre d\'épisodes', (tester) async {
      final media = _makeMedia(1, title: 'Naruto', episodes: 220);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MediaCard(media: media))),
      );
      // Le badge contient "TV · 220 ep"
      expect(find.textContaining('220 ep'), findsOneWidget);
    });

    testWidgets('badge affiche le format sans épisodes quand episodes est null',
        (tester) async {
      final media = Media(
        anilistId: 99,
        title: const MediaTitle(english: 'Film Test'),
        format: AnimeFormat.movie,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MediaCard(media: media))),
      );
      expect(find.text('Film'), findsOneWidget);
    });

    testWidgets('appelle onTap au tap', (tester) async {
      var tapped = false;
      final media = _makeMedia(1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCard(media: media, onTap: () => tapped = true),
          ),
        ),
      );
      await tester.tap(find.byType(MediaCard));
      expect(tapped, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Tests : CatalogPage
  // ---------------------------------------------------------------------------

  group('CatalogPage', () {
    testWidgets('affiche l\'état vide au démarrage (aucune recherche)',
        (tester) async {
      final fakeClient = _FakeAniListClient();
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          aniListClientProvider.overrideWithValue(fakeClient),
        ],
      ));
      await tester.pump();

      // Le champ de recherche est présent.
      expect(find.byType(TextField), findsOneWidget);
      // L'état vide initial est affiché (pas de résultats).
      expect(find.text('Entrez un titre pour rechercher'), findsOneWidget);
    });

    testWidgets('affiche les MediaCard quand le client renvoie des résultats',
        (tester) async {
      final medias = [
        _makeMedia(1, title: 'One Piece', episodes: 1000),
        _makeMedia(2, title: 'Bleach', episodes: 366),
      ];
      final fakeClient = _FakeAniListClient(searchResults: medias);

      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          aniListClientProvider.overrideWithValue(fakeClient),
        ],
      ));

      // Soumet une recherche.
      await tester.enterText(find.byType(TextField), 'shonen');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(); // loading state
      await tester.pump(const Duration(milliseconds: 100)); // future completes

      expect(find.text('One Piece'), findsOneWidget);
      expect(find.text('Bleach'), findsOneWidget);
      expect(find.byType(MediaCard), findsNWidgets(2));
    });

    testWidgets('affiche "Aucun résultat" quand le client renvoie une liste vide',
        (tester) async {
      final fakeClient = _FakeAniListClient(searchResults: []);

      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          aniListClientProvider.overrideWithValue(fakeClient),
        ],
      ));

      await tester.enterText(find.byType(TextField), 'inconnu');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Aucun résultat'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Tests : LibraryPage
  // ---------------------------------------------------------------------------

  group('LibraryPage', () {
    testWidgets('affiche les bons compteurs de badges via countByStatus',
        (tester) async {
      // Override les providers FutureProvider directement.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          countByStatusProvider.overrideWith(
            (ref) async => {
              ListStatus.current: 2,
              ListStatus.completed: 1,
            },
          ),
          entriesByStatusProvider.overrideWith(
            (ref, status) async => [],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Le badge "2" pour En cours doit être visible.
      expect(find.text('2'), findsAtLeastNWidgets(1));
      // Le badge "1" pour Terminé doit être visible.
      expect(find.text('1'), findsAtLeastNWidgets(1));
    });

    testWidgets('affiche "Aucun anime" dans un onglet vide', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          countByStatusProvider.overrideWith((ref) async => {}),
          entriesByStatusProvider.overrideWith(
            (ref, status) async => [],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Aucun anime dans'), findsOneWidget);
    });
  });
}
