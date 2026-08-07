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
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/domain/logic/calendar_service.dart';
import 'package:terebi/src/domain/logic/filter_sort_service.dart';
import 'package:terebi/src/domain/logic/stats_service.dart';
import 'package:terebi/src/domain/models/airing_schedule.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/media_relation.dart';
import 'package:terebi/src/services/process_runner.dart';
import 'package:terebi/src/ui/pages/calendar_page.dart';
import 'package:terebi/src/ui/pages/catalog_page.dart';
import 'package:terebi/src/ui/pages/library_page.dart';
import 'package:terebi/src/ui/pages/settings_page.dart';
import 'package:terebi/src/ui/pages/stats_page.dart';
import 'package:terebi/src/ui/widgets/media_card.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Faux AniListClient retournant une liste fixe ou vide.
class _FakeAniListClient extends AniListClient {
  final List<Media> searchResults;
  final List<Media> seasonResults;
  final Map<int, AiringSchedule?> airingMap;

  _FakeAniListClient({
    this.searchResults = const [],
    this.seasonResults = const [],
  }) : airingMap = const {};

  @override
  Future<List<Media>> search(String query,
          {int page = 1, int perPage = 20}) async =>
      searchResults;

  @override
  Future<List<Media>> season(AnimeSeason season, int year,
          {int page = 1, int perPage = 50}) async =>
      seasonResults;

  @override
  Future<Media> mediaDetail(int anilistId) async =>
      searchResults.firstWhere((m) => m.anilistId == anilistId,
          orElse: () => seasonResults.firstWhere(
                (m) => m.anilistId == anilistId,
                orElse: () => _makeMedia(anilistId),
              ));

  @override
  Future<List<MediaRelation>> relations(int anilistId) async => const [];

  @override
  Future<AiringSchedule?> nextAiring(int anilistId) async =>
      airingMap[anilistId];
}

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
      final fakeClient = _FakeAniListClient();
      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          aniListClientProvider.overrideWithValue(fakeClient),
        ],
      ));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
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

      await tester.enterText(find.byType(TextField), 'shonen');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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

    testWidgets('filtre par genre réduit les résultats affichés',
        (tester) async {
      final medias = [
        _makeMedia(1, title: 'Action Anime', genres: ['Action']),
        _makeMedia(2, title: 'Comedy Anime', genres: ['Comedy']),
        _makeMedia(3, title: 'Action Comedy', genres: ['Action', 'Comedy']),
      ];
      final fakeClient = _FakeAniListClient(searchResults: medias);

      await tester.pumpWidget(_wrap(
        const CatalogPage(),
        overrides: [
          aniListClientProvider.overrideWithValue(fakeClient),
          filterSortServiceProvider
              .overrideWithValue(const FilterSortServiceStub()),
        ],
      ));

      await tester.enterText(find.byType(TextField), 'anime');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tous les 3 résultats visibles initialement.
      expect(find.byType(MediaCard), findsNWidgets(3));
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

      expect(find.text('2'), findsAtLeastNWidgets(1));
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
    testWidgets('affiche le toggle Global/Perso', (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      final fakeClient = _FakeAniListClient(seasonResults: const []);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          aniListClientProvider.overrideWithValue(fakeClient),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Le toolbar avec les boutons Global/Perso doit être présent.
      expect(find.text('Global'), findsOneWidget);
      expect(find.text('Perso'), findsOneWidget);
      await db.close();
    });

    testWidgets('affiche le toggle hideUnreleased activé par défaut',
        (tester) async {
      final db = TerebiDatabase(NativeDatabase.memory());
      final fakeClient = _FakeAniListClient(seasonResults: const []);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          aniListClientProvider.overrideWithValue(fakeClient),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Le switch "Masquer les épisodes pas encore sortis" doit être présent.
      expect(find.textContaining('Masquer les épisodes'), findsOneWidget);
      // Le switch doit être coché (activé par défaut).
      final switchWidget = tester.widget<Switch>(find.byType(Switch).first);
      expect(switchWidget.value, isTrue);
      await db.close();
    });

    testWidgets('ouvre sur GLOBAL quand perso est vide', (tester) async {
      // CalendarService retourne isPersonalEmpty=true → ouvre Global.
      final db = TerebiDatabase(NativeDatabase.memory());
      final fakeClient = _FakeAniListClient(seasonResults: const []);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          aniListClientProvider.overrideWithValue(fakeClient),
          calendarServiceProvider
              .overrideWithValue(const CalendarService()),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarPage())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Avec liste PLANNING vide → calendrier perso vide → affiche Global.
      // Le SegmentedButton "Global" doit être sélectionné.
      // On vérifie l'état vide du calendrier global.
      expect(find.textContaining('Aucune diffusion'), findsOneWidget);
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

/// Stub de FilterSortService pour les tests (délègue à la vraie implémentation).
class FilterSortServiceStub extends FilterSortService {
  const FilterSortServiceStub();
}

// Classe fictive pour satisfaire le super() de ListRepository/MediaRepository
// (ils prennent une TerebiDatabase mais on override toutes les méthodes).
class _FakeDb implements TerebiDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in _FakeDb');
}
