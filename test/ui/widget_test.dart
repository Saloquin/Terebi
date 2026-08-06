/// Widget tests pour les pages UI de Terebi.
///
/// Stratégie : ProviderScope(overrides: [...]) pour injecter des faux clients/repos.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terebi/src/app/providers.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/remote/anilist_client.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/media_relation.dart';
import 'package:terebi/src/services/process_runner.dart';
import 'package:terebi/src/ui/pages/catalog_page.dart';
import 'package:terebi/src/ui/pages/library_page.dart';
import 'package:terebi/src/ui/pages/settings_page.dart';
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

  // ---------------------------------------------------------------------------
  // Tests : SettingsPage (health-check avec HealthService mocké)
  // ---------------------------------------------------------------------------

  group('SettingsPage', () {
    /// Construit un ProcessRunner qui retourne toujours le résultat fourni.
    ProcessRunner makeRunner(ProcessResult result) =>
        (_, __) async => result;

    /// Overrides minimaux pour SettingsPage (pas de DB réelle, storage vide).
    List<Override> settingsOverrides({
      required ProcessRunner runner,
      FlutterSecureStorage? storage,
    }) {
      return [
        databaseProvider.overrideWithValue(
          TerebiDatabase(NativeDatabase.memory()),
        ),
        processRunnerProvider.overrideWithValue(runner),
        secureStorageProvider.overrideWithValue(
          storage ?? const FlutterSecureStorage(),
        ),
      ];
    }

    testWidgets('affiche le titre Paramètres et le bouton Vérifier',
        (tester) async {
      final runner = makeRunner(
        const ProcessResult(exitCode: 0, stdout: 'ani-cli 9.0'),
      );

      await tester.pumpWidget(ProviderScope(
        overrides: settingsOverrides(runner: runner),
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Paramètres'), findsAtLeastNWidgets(1));
      expect(find.text('Vérifier'), findsOneWidget);
      expect(find.text('Sauvegarder'), findsOneWidget);
    });

    testWidgets(
        'affiche les résultats health-check après tap sur Vérifier (mock ok)',
        (tester) async {
      final runner =
          makeRunner(const ProcessResult(exitCode: 0, stdout: 'v1.0'));

      await tester.pumpWidget(ProviderScope(
        overrides: settingsOverrides(runner: runner),
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll jusqu'au bouton Vérifier (page plus longue que l'écran de test).
      await tester.scrollUntilVisible(
        find.text('Vérifier'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Vérifier'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Le rapport doit être affiché — les tuiles composants ani-cli et mpv.
      // findAtLeastNWidgets car le champ TextField contient aussi 'ani-cli'.
      expect(find.text('ani-cli'), findsAtLeastNWidgets(1));
      expect(find.text('mpv'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'affiche état missing quand le runner lève une exception (binaire absent)',
        (tester) async {
      Future<ProcessResult> failRunner(String exe, List<String> args) =>
          Future.error(Exception('executable not found'));

      await tester.pumpWidget(ProviderScope(
        overrides: settingsOverrides(runner: failRunner),
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(
        find.text('Vérifier'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Vérifier'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ani-cli'), findsAtLeastNWidgets(1));
      expect(find.text('mpv'), findsAtLeastNWidgets(1));
    });

    testWidgets('affiche les champs de chemin ani-cli et mpv', (tester) async {
      final runner =
          makeRunner(const ProcessResult(exitCode: 0, stdout: 'v1'));

      await tester.pumpWidget(ProviderScope(
        overrides: settingsOverrides(runner: runner),
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Chemin ani-cli'), findsOneWidget);
      expect(find.text('Chemin mpv'), findsOneWidget);
      expect(find.text('Redirect URI OAuth'), findsOneWidget);
    });
  });
}
