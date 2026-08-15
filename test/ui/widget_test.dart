/// Widget tests pour les pages UI de Terebi.
///
/// Stratégie : ProviderScope(overrides: [...]) pour injecter des faux clients/repos.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terebi/src/app/providers.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/domain/logic/anime_id.dart';
import 'package:terebi/src/domain/logic/stats_service.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/services/animesama_resolver.dart';
import 'package:terebi/src/services/process_runner.dart';
import 'package:terebi/src/services/stream_resolver.dart'
    show AnimeSamaHome, AnimeSamaCatalogueItem;
import 'package:terebi/src/ui/pages/calendar_page.dart';
import 'package:terebi/src/ui/pages/catalog_page.dart';
import 'package:terebi/src/ui/pages/home_page.dart';
import 'package:terebi/src/ui/pages/library_page.dart';
import 'package:terebi/src/ui/pages/settings_page.dart';
import 'package:terebi/src/ui/pages/stats_page.dart';
import 'package:terebi/src/ui/widgets/media_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Media _makeMedia(int id, {
  String? title,
  int? episodes,
  AnimeFormat? format,
  List<String> genres = const [],
  int? year,
}) =>
    Media(
      anilistId: id,
      title: MediaTitle(
        english: title ?? 'Anime $id',
        romaji: title ?? 'Anime $id',
      ),
      episodes: episodes ?? 12,
      format: format ?? AnimeFormat.tv,
      genres: genres,
      seasonYear: year,
    );

ListEntry _makeEntry(int mediaId, ListStatus status) => ListEntry(
      mediaId: mediaId,
      status: status,
      updatedAt: DateTime(2024),
    );

/// Construit un [AnimeSamaResolver] dont le runner renvoie [stdout] figé.
/// Sert à tester Catalogue/Planning sans réseau ni Python réel.
AnimeSamaResolver _fakeResolver(String stdout) => AnimeSamaResolver(
      pythonPath: 'python',
      wrapperScriptPath: 'w.py',
      animeSamaScriptPath: 'a.py',
      runner: (exe, args, {Map<String, String>? environment}) async =>
          ProcessResult(exitCode: 0, stdout: stdout),
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
      final db = TerebiDatabase(NativeDatabase.memory());
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider
              .overrideWith((ref) async => _fakeResolver('CATALOGUE_JSON: []')),
        ],
      ));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('Recherchez par titre'), findsOneWidget);
      await db.close();
    });

    testWidgets('affiche les résultats anime-sama après recherche',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      const out =
          'CATALOGUE_JSON: [{"title":"One Piece","url":"/catalogue/one-piece/"},'
          '{"title":"Bleach","url":"/catalogue/bleach/"}]';
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider
              .overrideWith((ref) async => _fakeResolver(out)),
        ],
      ));

      await tester.enterText(find.byType(TextField), 'shonen');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('One Piece'), findsOneWidget);
      expect(find.text('Bleach'), findsOneWidget);
      await db.close();
    });

    testWidgets('affiche "Aucun résultat" quand anime-sama renvoie une liste vide',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider
              .overrideWith((ref) async => _fakeResolver('CATALOGUE_JSON: []')),
        ],
      ));

      await tester.enterText(find.byType(TextField), 'inconnu');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Aucun résultat'), findsOneWidget);
      await db.close();
    });

    testWidgets('panneau filtres masqué par défaut, affiché au tap',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider
              .overrideWith((ref) async => _fakeResolver('CATALOGUE_JSON: []')),
        ],
      ));
      await tester.pump();

      // Masqué : pas de dropdown "Genre".
      expect(find.text('Genre'), findsNothing);
      // Tap sur le bouton filtres.
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pump();
      expect(find.text('Genre'), findsOneWidget);
      expect(find.text('Masquer ma bibliothèque'), findsOneWidget);
      await db.close();
    });

    testWidgets('mode parcourir : liste via catalogue-filter si filtre sans titre',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      const out =
          'CATALOGUE_JSON: [{"title":"Thriller One","url":"/catalogue/thriller-one/","slug":"thriller-one"}]';
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider
              .overrideWith((ref) async => _fakeResolver(out)),
        ],
      ));
      await tester.pump();

      // Ouvre les filtres et saisit une année min (filtre actif, sans titre).
      // Un champ année est un simple TextField, plus fiable a piloter en test
      // que l'overlay d'un DropdownButton.
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Année min'), '2015');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Titre vide + filtre actif -> mode BROWSE -> resultats catalogue-filter.
      expect(find.text('Thriller One'), findsOneWidget);
      await db.close();
    });

    testWidgets('badge de statut présent pour un anime en bibliothèque',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      // Insère une entrée de liste "terminé" pour le slug attendu.
      final listRepo = ListRepository(db);
      final id = animeSamaIdForSlug('one-piece');
      await listRepo.upsertEntry(ListEntry(
          mediaId: id,
          status: ListStatus.completed,
          updatedAt: DateTime.utc(2026)));

      const out =
          'CATALOGUE_JSON: [{"title":"One Piece","url":"/catalogue/one-piece/","slug":"one-piece"},'
          '{"title":"Bleach","url":"/catalogue/bleach/","slug":"bleach"}]';
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider
              .overrideWith((ref) async => _fakeResolver(out)),
        ],
      ));

      await tester.enterText(find.byType(TextField), 'one');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      // Laisse le stream libraryStatusMapProvider (asyncMap + hasAnyProgress)
      // et la recherche se resoudre.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // One Piece est en biblio (terminé) -> badge ; Bleach non.
      expect(find.text('Terminé'), findsOneWidget);
      await db.close();
    });

    testWidgets('masquer biblio retire la tuile en bibliothèque',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      final listRepo = ListRepository(db);
      final id = animeSamaIdForSlug('one-piece');
      await listRepo.upsertEntry(ListEntry(
          mediaId: id,
          status: ListStatus.completed,
          updatedAt: DateTime.utc(2026)));

      const out =
          'CATALOGUE_JSON: [{"title":"One Piece","url":"/catalogue/one-piece/","slug":"one-piece"},'
          '{"title":"Bleach","url":"/catalogue/bleach/","slug":"bleach"}]';
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider
              .overrideWith((ref) async => _fakeResolver(out)),
        ],
      ));

      await tester.enterText(find.byType(TextField), 'one');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('One Piece'), findsOneWidget);

      // Active "Masquer ma bibliothèque".
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // One Piece (en biblio) masqué ; Bleach reste.
      expect(find.text('One Piece'), findsNothing);
      expect(find.text('Bleach'), findsOneWidget);
      await db.close();
    });
  });

  // ---------------------------------------------------------------------------
  // Tests : LibraryPage
  // ---------------------------------------------------------------------------

  group('LibraryPage', () {
    testWidgets('affiche les bons compteurs de badges via countByStatus',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          countByStatusProvider.overrideWith(
            (ref) => Stream.value({
              ListStatus.current: 2,
              ListStatus.completed: 1,
            }),
          ),
          entriesByStatusProvider.overrideWith(
            (ref, status) => Stream.value(<ListEntry>[]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2'), findsAtLeastNWidgets(1));
      expect(find.text('1'), findsAtLeastNWidgets(1));
    });

    testWidgets('affiche "Aucun anime" dans un onglet vide', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          countByStatusProvider.overrideWith((ref) => Stream.value({})),
          entriesByStatusProvider.overrideWith(
            (ref, status) => Stream.value(<ListEntry>[]),
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
  // Tests : StatsPage
  // ---------------------------------------------------------------------------

  group('StatsPage', () {
    testWidgets('affiche "Aucune entrée" quand la bibliothèque est vide',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: Scaffold(body: StatsPage())),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Aucune entrée'), findsOneWidget);
      await db.close();
    });

    testWidgets('affiche les stats quand des entrées sont présentes',
        (tester) async {
      // Override direct du provider de données stats.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          statsServiceProvider.overrideWithValue(const StatsService()),
          // On override la DB avec des données mockées via un FutureProvider.
          databaseProvider.overrideWithValue(
            TerebiDatabase(NativeDatabase.memory()),
          ),
          listRepositoryProvider.overrideWith((ref) => _FakeListRepository()),
          mediaRepositoryProvider.overrideWith((ref) => _FakeMediaRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: StatsPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Doit afficher "Temps total regardé" et "Séries terminées".
      expect(find.text('Temps total regardé'), findsOneWidget);
      expect(find.text('Séries terminées'), findsOneWidget);
      expect(find.text('Répartition par statut'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Tests : CalendarPage — bascule global/perso
  // ---------------------------------------------------------------------------

  group('CalendarPage', () {
    testWidgets('affiche les jours et anime du planning anime-sama',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      const out =
          'PLANNING_JSON: [{"day":"Lundi","time":"18h00","title":"Dr Stone","url":"/catalogue/dr-stone/"},'
          '{"day":"Mardi","time":"20h00","title":"One Piece","url":"/catalogue/one-piece/"}]';

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider
              .overrideWith((ref) async => _fakeResolver(out)),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Lundi'), findsOneWidget);
      expect(find.text('Mardi'), findsOneWidget);
      expect(find.text('Dr Stone'), findsOneWidget);
      expect(find.text('One Piece'), findsOneWidget);
      expect(find.text('18h00'), findsOneWidget);
      await db.close();
    });

    testWidgets('affiche l\'état vide quand le planning est vide',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaResolverProvider.overrideWith(
              (ref) async => _fakeResolver('RESOLVE_ERROR: planning vide')),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // planning() lève ResolveException → état d'erreur.
      expect(find.textContaining('Planning indisponible'), findsOneWidget);
      await db.close();
    });
  });

  // ---------------------------------------------------------------------------
  // Tests : SettingsPage (health-check avec HealthService mocké)
  // ---------------------------------------------------------------------------

  group('SettingsPage', () {
    ProcessRunner makeRunner(ProcessResult result) =>
        (_, __, {Map<String, String>? environment}) async => result;

    List<Override> settingsOverrides({
      required ProcessRunner runner,
    }) {
      return [
        databaseProvider.overrideWithValue(
          TerebiDatabase(NativeDatabase.memory()),
        ),
        processRunnerProvider.overrideWithValue(runner),
      ];
    }

    testWidgets('affiche le titre Paramètres et le bouton Vérifier',
        (tester) async {
      final runner = makeRunner(
        const ProcessResult(exitCode: 0, stdout: 'mpv 0.38'),
      );

      await tester.pumpWidget(ProviderScope(
        overrides: settingsOverrides(runner: runner),
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Paramètres'), findsAtLeastNWidgets(1));
      expect(find.text('Vérifier'), findsOneWidget);
      // Pas de modif au chargement → la barre « Sauvegarder » n'apparaît pas.
      expect(find.text('Sauvegarder'), findsNothing);
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

      await tester.scrollUntilVisible(
        find.text('Vérifier'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Vérifier'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('python'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'affiche état missing quand le runner lève une exception (binaire absent)',
        (tester) async {
      Future<ProcessResult> failRunner(String exe, List<String> args,
              {Map<String, String>? environment}) =>
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

      expect(find.text('python'), findsAtLeastNWidgets(1));
    });

    testWidgets('affiche le champ de chemin Python', (tester) async {
      final runner =
          makeRunner(const ProcessResult(exitCode: 0, stdout: 'v1'));

      await tester.pumpWidget(ProviderScope(
        overrides: settingsOverrides(runner: runner),
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Chemin Python (optionnel)'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Tests : HomePage — rangees anime-sama
  // ---------------------------------------------------------------------------

  group('HomePage', () {
    testWidgets('HomePage affiche les rangees anime-sama', (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          animeSamaHomeProvider.overrideWith((ref) async => const AnimeSamaHome(
                classics: [
                  AnimeSamaCatalogueItem(
                      title: 'Naruto', url: '/catalogue/naruto/', slug: 'naruto'),
                ],
                latestEpisodes: [
                  AnimeSamaCatalogueItem(
                      title: 'One Piece',
                      url: '/catalogue/one-piece/',
                      slug: 'one-piece'),
                ],
              )),
          animeSamaPlanningProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Les classiques'), findsOneWidget);
      // « Derniers contenus » a ete retiree ; seule « Les classiques » utilise
      // la section home ici.
      expect(find.text('Derniers contenus ajoutes'), findsNothing);
      await db.close();
    });
  });
}

// ---------------------------------------------------------------------------
// Faux repositories pour StatsPage
// ---------------------------------------------------------------------------

class _FakeListRepository extends ListRepository {
  _FakeListRepository() : super(_FakeDb());

  @override
  Future<List<ListEntry>> entriesByStatus(ListStatus status) async {
    if (status == ListStatus.completed) {
      return [_makeEntry(1, ListStatus.completed)];
    }
    if (status == ListStatus.current) {
      return [_makeEntry(2, ListStatus.current)];
    }
    return [];
  }

  @override
  Future<Map<ListStatus, int>> countByStatus() async => {
        ListStatus.completed: 1,
        ListStatus.current: 1,
      };

  @override
  Future<ListEntry?> getEntry(int mediaId) async => null;

  @override
  Future<void> upsertEntry(ListEntry entry) async {}

  @override
  Future<void> setHidden(int mediaId, {required bool hidden}) async {}

  @override
  Future<Set<int>> allHidden() async => {};
}

class _FakeMediaRepository extends MediaRepository {
  _FakeMediaRepository() : super(_FakeDb());

  @override
  Future<Media?> getMedia(int anilistId) async {
    return _makeMedia(
      anilistId,
      title: 'Anime $anilistId',
      episodes: 12,
      genres: ['Action'],
    );
  }

  @override
  Future<void> upsertMedia(Media media) async {}

  @override
  Stream<List<Media>> watchAllMedia() => const Stream.empty();
}

// Classe fictive pour satisfaire le super() de ListRepository/MediaRepository
// (ils prennent une TerebiDatabase mais on override toutes les méthodes).
class _FakeDb implements TerebiDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in _FakeDb');
}
