# Architecture Scalable — Controllers Riverpod

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extraire la logique métier des pages Flutter dans des Controllers Riverpod testables, en commençant par le lecteur (PlayerController) puis la bibliothèque (LibraryController).

**Architecture:** Nouvelle couche `lib/src/controllers/` avec des `Notifier<State>` immutables. Les pages deviennent de pures vues qui lisent l'état et appellent des méthodes. Les providers globaux orphelins (définis dans des fichiers de page) sont rapatriés dans `providers.dart`.

**Tech Stack:** Flutter, Riverpod (`Notifier`, `NotifierProvider`), Dart pur pour les states et la logique de navigation d'épisodes.

---

## Structure des fichiers

### Fichiers créés
| Fichier | Rôle |
|---|---|
| `lib/src/controllers/player/player_state.dart` | `PlayerState` immutable + `copyWith` |
| `lib/src/controllers/player/episode_resolver.dart` | Logique pure : épisode suivant/précédent/initial |
| `lib/src/controllers/player/player_controller.dart` | `PlayerController extends Notifier<PlayerState>` |
| `lib/src/controllers/library/library_state.dart` | `LibraryState` immutable |
| `lib/src/controllers/library/library_controller.dart` | `LibraryController extends Notifier<LibraryState>` |
| `test/controllers/player/episode_resolver_test.dart` | Tests purs pour `episode_resolver.dart` |
| `test/controllers/library/library_controller_test.dart` | Tests logique de filtre/tri |
| `docs/superpowers/specs/2026-09-07-scalable-architecture-design.md` | Spec (déjà créée) |

### Fichiers modifiés
| Fichier | Changement |
|---|---|
| `lib/src/app/providers.dart` | +`playerControllerProvider`, +`libraryControllerProvider`, +`countByStatusProvider`, +`entriesByStatusProvider` déplacés depuis library_page |
| `lib/src/ui/pages/player_page.dart` | `_PlayerPageState` délègue à `PlayerController` ; suppression des 30+ `ref.read(repo)` directs |
| `lib/src/ui/pages/library_page.dart` | Suppression des 4 providers locaux (déplacés dans providers.dart) ; `_LibraryPageState` délègue à `LibraryController` |

---

## Task 1 : Déplacer les providers orphelins de library_page vers providers.dart

**Pourquoi en premier :** `player_page.dart` importe `library_page.dart` (ligne 35) uniquement pour `countByStatusProvider` et `entriesByStatusProvider`. C'est un couplage circulaire qui bloque tout le reste.

**Files:**
- Modify: `lib/src/app/providers.dart`
- Modify: `lib/src/ui/pages/library_page.dart`
- Modify: `lib/src/ui/pages/player_page.dart`
- Modify: `lib/src/ui/pages/media_detail_page.dart` (invalide aussi ces providers)

- [ ] **Étape 1 : Copier les 4 providers dans providers.dart**

Ouvrir `lib/src/app/providers.dart`. À la fin du fichier (après `downloadProgressProvider`), ajouter :

```dart
// ---------------------------------------------------------------------------
// Library — providers déplacés depuis library_page.dart
// ---------------------------------------------------------------------------

/// Compte les entrées par statut effectif.
final countByStatusProvider = Provider<AsyncValue<Map<ListStatus, int>>>((ref) {
  return ref.watch(effectiveEntriesProvider).whenData((entries) {
    final map = <ListStatus, int>{};
    for (final e in entries) {
      map[e.status] = (map[e.status] ?? 0) + 1;
    }
    return map;
  });
});

/// Entrées filtrées par statut effectif.
final entriesByStatusProvider =
    Provider.family<AsyncValue<List<ListEntry>>, ListStatus>((ref, status) {
  return ref.watch(effectiveEntriesProvider).whenData((entries) => [
        for (final e in entries)
          if (e.status == status) e.entry,
      ]);
});

/// Flag « nouvel épisode » pour un mediaId donné.
final newEpisodeFlagProvider =
    FutureProvider.family<bool, int>((ref, mediaId) async {
  final v = await ref
      .watch(settingsRepositoryProvider)
      .get(SettingsKeys.newEpisodeFor(mediaId));
  return v == '1';
});
```

Ajouter aussi les imports manquants en tête de `providers.dart` si pas déjà présents :
```dart
import '../domain/models/list_entry.dart';
import '../domain/models/list_status.dart';
```

- [ ] **Étape 2 : Vérifier que les imports existent déjà**

```bash
grep -n "list_entry\|list_status\|ListEntry\|ListStatus" lib/src/app/providers.dart
```

S'ils sont déjà présents (ils devraient l'être via `effectiveEntriesProvider`), ne pas doubler.

- [ ] **Étape 3 : Supprimer les providers dans library_page.dart**

Dans `lib/src/ui/pages/library_page.dart`, supprimer les lignes 27–64 :
```dart
// SUPPRIMER ces 4 providers locaux (désormais dans providers.dart) :
final countByStatusProvider = ...       // ligne 27–35
final entriesByStatusProvider = ...     // ligne 39–46
final newEpisodeFlagProvider = ...      // ligne 49–55
final _allMediaMapProvider = ...        // ligne 61–64
```

Le `_allMediaMapProvider` (privé, utilisé uniquement dans library_page) peut rester dans library_page si son usage est purement local. Vérifier avec :
```bash
grep -n "_allMediaMapProvider" lib/src/ui/pages/library_page.dart
```
S'il n'est utilisé que dans library_page, garder uniquement ce provider local privé.

- [ ] **Étape 4 : Mettre à jour player_page.dart — supprimer l'import circulaire**

Dans `lib/src/ui/pages/player_page.dart`, ligne 35 :
```dart
// SUPPRIMER :
import 'library_page.dart';
```

Les refs à `countByStatusProvider` et `entriesByStatusProvider` viennent maintenant de `providers.dart` (déjà importé ligne 26). Aucun autre changement.

- [ ] **Étape 5 : Vérifier media_detail_page.dart**

```bash
grep -n "countByStatusProvider\|entriesByStatusProvider\|library_page" lib/src/ui/pages/media_detail_page.dart
```

S'il importe `library_page.dart` pour ces providers, retirer cet import (ils viennent maintenant de `providers.dart`).

- [ ] **Étape 6 : Analyser**

```bash
dart analyze lib/
```

Résultat attendu : `No issues found!`

- [ ] **Étape 7 : Commit**

```bash
git add lib/src/app/providers.dart lib/src/ui/pages/library_page.dart lib/src/ui/pages/player_page.dart lib/src/ui/pages/media_detail_page.dart
git commit -m "refactor: move countByStatus/entriesByStatus providers to providers.dart (break circular import)"
```

---

## Task 2 : Créer PlayerState

**Files:**
- Create: `lib/src/controllers/player/player_state.dart`
- Create: `test/controllers/player/episode_resolver_test.dart`
- Create: `lib/src/controllers/player/episode_resolver.dart`

- [ ] **Étape 1 : Créer `lib/src/controllers/player/player_state.dart`**

```dart
library;

import '../../domain/models/list_entry.dart';
import '../../services/stream_resolver.dart';

/// État immutable du lecteur. Toutes les mutations passent par [PlayerController].
class PlayerState {
  final bool loading;
  final bool ready;
  final String? error;

  // Navigation
  final int currentEpisode;
  final int seasonIndex;
  final String? seasonName;
  final List<int> episodes;
  final bool initialEpisodeResolved;
  final bool navigating;

  // Lecture
  final double positionSeconds;
  final double? durationSeconds;
  final double speed;
  final SkipTimes skipTimes;

  // Langue
  final PlaybackLanguage language;
  final Set<PlaybackLanguage> availableLanguages;
  final bool singleLanguage;

  // Auto-play
  final int? autoPlayCountdown;

  // Entrée de bibliothèque courante
  final ListEntry currentEntry;

  const PlayerState({
    this.loading = false,
    this.ready = false,
    this.error,
    required this.currentEpisode,
    this.seasonIndex = 1,
    this.seasonName,
    this.episodes = const [],
    this.initialEpisodeResolved = false,
    this.navigating = false,
    this.positionSeconds = 0,
    this.durationSeconds,
    this.speed = 1.0,
    this.skipTimes = const SkipTimes(),
    this.language = PlaybackLanguage.vostfr,
    this.availableLanguages = const {},
    this.singleLanguage = false,
    this.autoPlayCountdown,
    required this.currentEntry,
  });

  PlayerState copyWith({
    bool? loading,
    bool? ready,
    String? error,
    int? currentEpisode,
    int? seasonIndex,
    String? seasonName,
    List<int>? episodes,
    bool? initialEpisodeResolved,
    bool? navigating,
    double? positionSeconds,
    double? durationSeconds,
    double? speed,
    SkipTimes? skipTimes,
    PlaybackLanguage? language,
    Set<PlaybackLanguage>? availableLanguages,
    bool? singleLanguage,
    int? autoPlayCountdown,
    ListEntry? currentEntry,
    bool clearError = false,
    bool clearAutoPlay = false,
    bool clearDuration = false,
    bool clearSeasonName = false,
  }) {
    return PlayerState(
      loading: loading ?? this.loading,
      ready: ready ?? this.ready,
      error: clearError ? null : error ?? this.error,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      seasonIndex: seasonIndex ?? this.seasonIndex,
      seasonName: clearSeasonName ? null : seasonName ?? this.seasonName,
      episodes: episodes ?? this.episodes,
      initialEpisodeResolved:
          initialEpisodeResolved ?? this.initialEpisodeResolved,
      navigating: navigating ?? this.navigating,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: clearDuration ? null : durationSeconds ?? this.durationSeconds,
      speed: speed ?? this.speed,
      skipTimes: skipTimes ?? this.skipTimes,
      language: language ?? this.language,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      singleLanguage: singleLanguage ?? this.singleLanguage,
      autoPlayCountdown: clearAutoPlay ? null : autoPlayCountdown ?? this.autoPlayCountdown,
      currentEntry: currentEntry ?? this.currentEntry,
    );
  }

  bool get isLastEpisode =>
      episodes.isNotEmpty && currentEpisode >= episodes.last;

  int? get nextEpisode {
    if (episodes.isEmpty) return null;
    final idx = episodes.indexOf(currentEpisode);
    if (idx < 0 || idx >= episodes.length - 1) return null;
    return episodes[idx + 1];
  }

  int? get prevEpisode {
    if (episodes.isEmpty) return null;
    final idx = episodes.indexOf(currentEpisode);
    if (idx <= 0) return null;
    return episodes[idx - 1];
  }
}
```

- [ ] **Étape 2 : Créer `lib/src/controllers/player/episode_resolver.dart`**

```dart
library;

/// Logique pure de résolution de l'épisode initial depuis la progression.
/// Aucun import Flutter. Testable via `dart test`.
class EpisodeResolver {
  const EpisodeResolver();

  /// Retourne l'épisode initial à jouer.
  ///
  /// - Si [requestedEpisode] est dans [episodes], on le joue directement.
  /// - Sinon on joue le premier épisode non vu (watched < episode).
  /// - [lastWatched] = dernier épisode vu sur cette saison (0 = rien vu).
  /// - [fullyWatchedSentinel] = marqueur "saison entièrement vue".
  int resolveInitialEpisode({
    required int requestedEpisode,
    required List<int> episodes,
    required int lastWatched,
    required int fullyWatchedSentinel,
  }) {
    if (episodes.isEmpty) return requestedEpisode;

    // Épisode demandé explicitement et présent → on respecte le choix.
    if (episodes.contains(requestedEpisode)) return requestedEpisode;

    // Saison entièrement vue → rejouer depuis le début.
    if (lastWatched >= fullyWatchedSentinel) return episodes.first;

    // Trouver le premier épisode non vu.
    if (lastWatched > 0) {
      final next = episodes.firstWhere(
        (e) => e > lastWatched,
        orElse: () => episodes.first,
      );
      return next;
    }

    return episodes.first;
  }

  /// Retourne l'épisode suivant dans [episodes] après [current], ou null.
  int? nextEpisode(List<int> episodes, int current) {
    final idx = episodes.indexOf(current);
    if (idx < 0 || idx >= episodes.length - 1) return null;
    return episodes[idx + 1];
  }

  /// Retourne l'épisode précédent dans [episodes] avant [current], ou null.
  int? prevEpisode(List<int> episodes, int current) {
    final idx = episodes.indexOf(current);
    if (idx <= 0) return null;
    return episodes[idx - 1];
  }
}
```

- [ ] **Étape 3 : Écrire les tests qui échouent**

Créer `test/controllers/player/episode_resolver_test.dart` :

```dart
import 'package:test/test.dart';
import 'package:terebi/src/controllers/player/episode_resolver.dart';

void main() {
  const resolver = EpisodeResolver();
  const sentinel = 1 << 20;
  final eps = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  group('resolveInitialEpisode', () {
    test('épisode demandé présent → retourné tel quel', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 5,
          episodes: eps,
          lastWatched: 3,
          fullyWatchedSentinel: sentinel,
        ),
        equals(5),
      );
    });

    test('épisode demandé absent, rien vu → premier épisode', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 99,
          episodes: eps,
          lastWatched: 0,
          fullyWatchedSentinel: sentinel,
        ),
        equals(1),
      );
    });

    test('épisode demandé absent, 3 vus → épisode 4', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 99,
          episodes: eps,
          lastWatched: 3,
          fullyWatchedSentinel: sentinel,
        ),
        equals(4),
      );
    });

    test('saison entièrement vue → premier épisode', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 99,
          episodes: eps,
          lastWatched: sentinel,
          fullyWatchedSentinel: sentinel,
        ),
        equals(1),
      );
    });

    test('liste vide → requestedEpisode retourné', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 3,
          episodes: [],
          lastWatched: 0,
          fullyWatchedSentinel: sentinel,
        ),
        equals(3),
      );
    });

    test('tous vus sauf le dernier → épisode 12', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 99,
          episodes: eps,
          lastWatched: 11,
          fullyWatchedSentinel: sentinel,
        ),
        equals(12),
      );
    });
  });

  group('nextEpisode', () {
    test('milieu de liste → suivant', () {
      expect(resolver.nextEpisode(eps, 5), equals(6));
    });
    test('dernier → null', () {
      expect(resolver.nextEpisode(eps, 12), isNull);
    });
    test('absent → null', () {
      expect(resolver.nextEpisode(eps, 99), isNull);
    });
  });

  group('prevEpisode', () {
    test('milieu de liste → précédent', () {
      expect(resolver.prevEpisode(eps, 5), equals(4));
    });
    test('premier → null', () {
      expect(resolver.prevEpisode(eps, 1), isNull);
    });
    test('absent → null', () {
      expect(resolver.prevEpisode(eps, 99), isNull);
    });
  });
}
```

- [ ] **Étape 4 : Lancer les tests (doivent échouer)**

```bash
dart test test/controllers/player/episode_resolver_test.dart
```

Résultat attendu : erreur `Cannot find 'EpisodeResolver'` (fichier pas encore importable depuis les tests).

- [ ] **Étape 5 : Vérifier que les fichiers compilent**

```bash
dart analyze lib/src/controllers/player/
```

Résultat attendu : `No issues found!`

- [ ] **Étape 6 : Lancer les tests (doivent passer)**

```bash
dart test test/controllers/player/episode_resolver_test.dart
```

Résultat attendu : `9/9 tests passed`

- [ ] **Étape 7 : Analyser tout lib/**

```bash
dart analyze lib/
```

Résultat attendu : `No issues found!`

- [ ] **Étape 8 : Commit**

```bash
git add lib/src/controllers/ test/controllers/
git commit -m "feat(arch): add PlayerState + EpisodeResolver with tests (9 passing)"
```

---

## Task 3 : Créer PlayerController

**Files:**
- Create: `lib/src/controllers/player/player_controller.dart`
- Modify: `lib/src/app/providers.dart` (ajouter `playerControllerProvider`)

- [ ] **Étape 1 : Créer `lib/src/controllers/player/player_controller.dart`**

```dart
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../app/providers.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/episode_progress.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/season_progress_repository.dart';
import '../../services/stream_resolver.dart';
import 'episode_resolver.dart';
import 'player_state.dart';

/// Gère tout l'état du lecteur : chargement URL, navigation épisodes,
/// progression, skip intro, auto-play. Instancié une fois par session lecteur.
class PlayerController extends Notifier<PlayerState> {
  static const _resolver = EpisodeResolver();

  late final Player player;
  late final VideoController videoController;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _completedSub;

  double _lastPersistedWhole = -1;
  Timer? _seekDebounce;
  Timer? _autoPlayTimer;

  @override
  PlayerState build() {
    // Initialisation des ressources media_kit.
    player = Player();
    videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'no'),
    );
    // Nettoyage automatique quand le provider est détruit.
    ref.onDispose(_dispose);
    return PlayerState(
      currentEpisode: 0,
      currentEntry: const ListEntry(
        mediaId: 0,
        status: ListStatus.planning,
        progress: 0,
        updatedAt: null,
        hiddenFromPlanning: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Appeler depuis [PlayerPage.initState] pour démarrer la session lecteur.
  Future<void> init({
    required domain.Media media,
    required int requestedEpisode,
    required ListEntry entry,
  }) async {
    state = state.copyWith(currentEntry: entry);
    await _loadSeasonMeta(media: media, requestedEpisode: requestedEpisode);
    _subscribeStreams();
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsRepositoryProvider);
    final fwd = int.tryParse(
            await settings.get(SettingsKeys.seekForwardSeconds,
                defaultValue: '10') ??
                '10') ??
        10;
    final bwd = int.tryParse(
            await settings.get(SettingsKeys.seekBackwardSeconds,
                defaultValue: '10') ??
                '10') ??
        10;
    final single = await settings.get(SettingsKeys.singleLanguage,
            defaultValue: '0') ==
        '1';
    state = state.copyWith(singleLanguage: single);
    _seekForwardSec = fwd;
    _seekBackwardSec = bwd;
  }

  int _seekForwardSec = 10;
  int _seekBackwardSec = 10;

  void _subscribeStreams() {
    _positionSub = player.stream.position.listen((pos) {
      state = state.copyWith(positionSeconds: pos.inMilliseconds / 1000.0);
      _maybePersistPosition();
    });
    _durationSub = player.stream.duration.listen((dur) {
      if (dur.inSeconds > 0) {
        state = state.copyWith(durationSeconds: dur.inMilliseconds / 1000.0);
      }
    });
    _completedSub = player.stream.completed.listen((done) {
      if (done) _onEpisodeCompleted();
    });
  }

  // ---------------------------------------------------------------------------
  // Chargement saison + épisode initial
  // ---------------------------------------------------------------------------

  Future<void> _loadSeasonMeta({
    required domain.Media media,
    required int requestedEpisode,
  }) async {
    final title = media.animeSamaTitle ?? media.title.preferred;
    final resolver = await ref.read(animeSamaResolverProvider.future);

    // Saison mémorisée
    final settings = ref.read(settingsRepositoryProvider);
    final storedStr = await settings.get(
        SettingsKeys.animeSamaSeasonFor(media.mediaId));
    final storedSeason = storedStr != null ? int.tryParse(storedStr) : null;

    final seasons = await resolver.listSeasons(title: title);
    if (seasons.isEmpty) return;

    final targetSeason = seasons.firstWhere(
      (s) => s.index == (storedSeason ?? seasons.first.index),
      orElse: () => seasons.first,
    );

    final eps = await resolver.listEpisodes(
      title: title,
      seasonIndex: targetSeason.index,
    );

    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final lastWatched =
        await seasonProgress.lastWatched(media.mediaId, targetSeason.index);

    final initial = _resolver.resolveInitialEpisode(
      requestedEpisode: requestedEpisode,
      episodes: eps,
      lastWatched: lastWatched,
      fullyWatchedSentinel: SeasonProgressRepository.fullyWatchedSentinel,
    );

    state = state.copyWith(
      seasonIndex: targetSeason.index,
      seasonName: targetSeason.name,
      episodes: eps,
      currentEpisode: initial,
      initialEpisodeResolved: true,
    );

    // Résolution de la langue préférée
    final lang = await _preferredLanguage(media: media, title: title);
    state = state.copyWith(language: lang);

    await loadAndPlay(media: media, episode: initial);
  }

  // ---------------------------------------------------------------------------
  // Chargement + lecture
  // ---------------------------------------------------------------------------

  Future<void> loadAndPlay({
    required domain.Media media,
    required int episode,
  }) async {
    if (state.navigating) return;
    state = state.copyWith(loading: true, ready: false, clearError: true);

    final title = media.animeSamaTitle ?? media.title.preferred;
    final resolver = await ref.read(animeSamaResolverProvider.future);

    try {
      final url = await resolver.resolveStreamUrl(
        title: title,
        seasonIndex: state.seasonIndex,
        episode: episode,
        language: state.language,
      );

      if (url == null || url.isEmpty) {
        state = state.copyWith(
            loading: false, error: 'URL introuvable pour cet épisode.');
        return;
      }

      // Applique les propriétés MPV
      await player.open(Media(url), play: false);
      await _applyMpvProperties();

      // Reprise de position
      final resumePos = await _fetchResumePosition(
          mediaId: media.mediaId, episode: episode);
      if (resumePos != null && resumePos > 5) {
        await player.seek(Duration(seconds: resumePos.toInt()));
      }

      await player.play();
      state = state.copyWith(loading: false, ready: true);

      // Historique + statut
      await _ensureWatchingStatus(media: media);
      await _loadSkipTimes(
          title: title, episode: episode, malId: media.mediaId);
      await _refreshAvailableLangs(title: title, episode: episode);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> _applyMpvProperties() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) return;
    await player.setProperty('hls-bitrate', 'max');
    await player.setProperty('hr-seek', 'yes');
    await player.setProperty('stream-lavf-o-append',
        'reconnect_streamed=1,reconnect_delay_max=5');
    await player.setProperty('demuxer-readahead-secs', '30');
  }

  Future<double?> _fetchResumePosition({
    required int mediaId,
    required int episode,
  }) async {
    final repo = ref.read(progressRepositoryProvider);
    final prog = await repo.getProgress(mediaId, episode);
    if (prog == null) return null;
    if (prog.durationSeconds != null && prog.durationSeconds! > 0) {
      final frac = prog.positionSeconds / prog.durationSeconds!;
      if (frac > 0.9) return null; // déjà terminé
    }
    return prog.positionSeconds;
  }

  // ---------------------------------------------------------------------------
  // Navigation épisodes
  // ---------------------------------------------------------------------------

  Future<void> goToEpisode({
    required domain.Media media,
    required int episode,
  }) async {
    if (state.navigating) return;
    state = state.copyWith(navigating: true, clearAutoPlay: true);
    _cancelAutoPlay();

    final goingForward =
        episode > state.currentEpisode;
    if (goingForward) {
      await _markCurrentWatched(media: media);
    } else {
      await _rewindProgressTo(media: media, episode: episode);
    }

    state = state.copyWith(
      currentEpisode: episode,
      positionSeconds: 0,
      clearDuration: true,
      navigating: false,
    );
    await loadAndPlay(media: media, episode: episode);
  }

  Future<void> goToNextEpisode({required domain.Media media}) async {
    final next = state.nextEpisode;
    if (next == null) return;
    await goToEpisode(media: media, episode: next);
  }

  Future<void> goToPrevEpisode({required domain.Media media}) async {
    final prev = state.prevEpisode;
    if (prev == null) return;
    await goToEpisode(media: media, episode: prev);
  }

  // ---------------------------------------------------------------------------
  // Progression
  // ---------------------------------------------------------------------------

  Future<void> _markCurrentWatched({required domain.Media media}) async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    await seasonProgress.markWatched(
        media.mediaId, state.seasonIndex, state.currentEpisode);

    final repo = ref.read(progressRepositoryProvider);
    final dur = state.durationSeconds;
    await repo.upsertProgress(EpisodeProgress(
      mediaId: media.mediaId,
      episodeNumber: state.currentEpisode,
      watched: true,
      positionSeconds: dur ?? 0,
      durationSeconds: dur,
    ));

    await _invalidateStatusProviders();
  }

  Future<void> _rewindProgressTo({
    required domain.Media media,
    required int episode,
  }) async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final currentWatched =
        await seasonProgress.lastWatched(media.mediaId, state.seasonIndex);

    if (currentWatched >= SeasonProgressRepository.fullyWatchedSentinel ||
        currentWatched >= episode) {
      await seasonProgress.setLastWatched(
          media.mediaId, state.seasonIndex, episode - 1);

      // Repasser en "En cours" si on recule
      final listRepo = ref.read(listRepositoryProvider);
      final entry = await listRepo.getEntry(media.mediaId);
      if (entry?.status == ListStatus.completed) {
        await listRepo.upsertEntry(
            entry!.copyWith(status: ListStatus.current));
        await _invalidateStatusProviders();
      }
    }
  }

  void _maybePersistPosition() {
    final whole = state.positionSeconds.toInt();
    if (whole == _lastPersistedWhole) return;
    if (whole % 5 != 0) return;
    _lastPersistedWhole = whole.toDouble();
    _persistPosition();
  }

  Future<void> _persistPosition() async {
    if (state.currentEntry.mediaId == 0) return;
    final repo = ref.read(progressRepositoryProvider);
    await repo.upsertProgress(EpisodeProgress(
      mediaId: state.currentEntry.mediaId,
      episodeNumber: state.currentEpisode,
      watched: false,
      positionSeconds: state.positionSeconds,
      durationSeconds: state.durationSeconds,
    ));
  }

  Future<void> _invalidateStatusProviders() async {
    ref.invalidate(countByStatusProvider);
    ref.invalidate(entriesByStatusProvider);
    ref.invalidate(listEntryProvider);
  }

  // ---------------------------------------------------------------------------
  // Fin d'épisode + auto-play
  // ---------------------------------------------------------------------------

  void _onEpisodeCompleted() {
    _markCurrentWatched(media: _currentMedia!);
    _maybeStartAutoPlay();
  }

  domain.Media? _currentMedia; // injecté par init()

  void _maybeStartAutoPlay() {
    if (state.isLastEpisode) return;
    final next = state.nextEpisode;
    if (next == null) return;
    _startAutoPlayCountdown();
  }

  void _startAutoPlayCountdown() {
    state = state.copyWith(autoPlayCountdown: 5);
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = (state.autoPlayCountdown ?? 0) - 1;
      if (remaining <= 0) {
        t.cancel();
        state = state.copyWith(clearAutoPlay: true);
        if (_currentMedia != null) {
          goToNextEpisode(media: _currentMedia!);
        }
      } else {
        state = state.copyWith(autoPlayCountdown: remaining);
      }
    });
  }

  void cancelAutoPlay() {
    _cancelAutoPlay();
    state = state.copyWith(clearAutoPlay: true);
  }

  void _cancelAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Langue
  // ---------------------------------------------------------------------------

  Future<PlaybackLanguage> _preferredLanguage({
    required domain.Media media,
    required String title,
  }) async {
    final settings = ref.read(settingsRepositoryProvider);
    final perAnime = await settings.get(
        SettingsKeys.animeSamaLangFor(media.mediaId));
    if (perAnime != null) {
      return perAnime == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
    }
    final global = await settings.get(SettingsKeys.playbackLanguage,
        defaultValue: 'vostfr');
    return global == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
  }

  Future<void> persistLanguage({
    required domain.Media media,
    required PlaybackLanguage lang,
  }) async {
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.animeSamaLangFor(media.mediaId),
            lang == PlaybackLanguage.vf ? 'vf' : 'vostfr');
  }

  Future<void> switchLanguage({
    required domain.Media media,
    required PlaybackLanguage lang,
  }) async {
    state = state.copyWith(language: lang);
    await persistLanguage(media: media, lang: lang);
    if (state.ready) {
      await loadAndPlay(media: media, episode: state.currentEpisode);
    }
  }

  Future<void> _refreshAvailableLangs({
    required String title,
    required int episode,
  }) async {
    if (state.singleLanguage) return;
    try {
      final langs = await ref.read(
        animeSamaLanguagesProvider((
          title: title,
          seasonIndex: state.seasonIndex,
          episode: episode,
        )).future,
      );
      state = state.copyWith(availableLanguages: langs);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Skip intro/outro
  // ---------------------------------------------------------------------------

  Future<void> _loadSkipTimes({
    required String title,
    required int episode,
    required int malId,
  }) async {
    try {
      final times = await ref.read(
        animeSamaSkipTimesProvider((
          title: title,
          seasonIndex: state.seasonIndex,
          episode: episode,
          malId: malId,
        )).future,
      );
      state = state.copyWith(skipTimes: times);
    } catch (_) {
      state = state.copyWith(skipTimes: const SkipTimes());
    }
  }

  void seekTo(double seconds) {
    player.seek(Duration(milliseconds: (seconds * 1000).toInt()));
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed);
    player.setRate(speed);
  }

  // ---------------------------------------------------------------------------
  // Statut "En cours"
  // ---------------------------------------------------------------------------

  Future<void> _ensureWatchingStatus({required domain.Media media}) async {
    final listRepo = ref.read(listRepositoryProvider);
    final existing = await listRepo.getEntry(media.mediaId);
    if (existing == null) {
      await listRepo.upsertEntry(ListEntry(
        mediaId: media.mediaId,
        status: ListStatus.current,
        progress: 0,
        updatedAt: DateTime.now(),
        hiddenFromPlanning: false,
      ));
      await _invalidateStatusProviders();
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  Future<void> _dispose() async {
    _seekDebounce?.cancel();
    _cancelAutoPlay();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _completedSub?.cancel();
    // Persiste la position finale best-effort
    await _persistPosition();
    await player.dispose();
  }
}
```

- [ ] **Étape 2 : Ajouter l'import `domain.Media` dans player_controller.dart**

Le controller référence `domain.Media`. Ajouter en tête du fichier :
```dart
import '../../domain/models/media.dart' as domain;
```

- [ ] **Étape 3 : Ajouter `playerControllerProvider` dans providers.dart**

À la fin de `lib/src/app/providers.dart`, après `downloadProgressProvider` :

```dart
// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------
import '../controllers/player/player_controller.dart';
export '../controllers/player/player_state.dart';

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
```

Note : les imports Dart se mettent en haut du fichier — ajouter l'import dans le bloc imports existant, pas inline.

- [ ] **Étape 4 : Analyser**

```bash
dart analyze lib/src/controllers/player/ lib/src/app/providers.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 5 : Commit**

```bash
git add lib/src/controllers/player/player_controller.dart lib/src/app/providers.dart
git commit -m "feat(arch): add PlayerController Notifier + playerControllerProvider"
```

---

## Task 4 : Connecter PlayerPage au PlayerController

**Files:**
- Modify: `lib/src/ui/pages/player_page.dart`

L'objectif est de remplacer les 30+ appels `ref.read(repo)` directs dans `_PlayerPageState` par des délégations au `PlayerController`. La page garde uniquement : le widget `VideoController`, les abonnements UI (clavier, orientation), et les appels `controller.method()`.

- [ ] **Étape 1 : Remplacer `initState` dans player_page.dart**

Localiser `initState` (ligne ~154). Remplacer son contenu :

```dart
@override
void initState() {
  super.initState();
  // Démarre le controller avec les paramètres de cette session.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final controller = ref.read(playerControllerProvider.notifier);
    controller.setCurrentMedia(widget.media);
    await controller.init(
      media: widget.media,
      requestedEpisode: widget.episode,
      entry: widget.entry,
    );
  });
}
```

- [ ] **Étape 2 : Remplacer `dispose` dans player_page.dart**

```dart
@override
void dispose() {
  // Le PlayerController est détruit automatiquement par Riverpod (ref.onDispose).
  super.dispose();
}
```

- [ ] **Étape 3 : Remplacer les champs d'état locaux par des lectures du controller**

Dans `build()` et les méthodes UI, remplacer :
- `_loading` → `ref.watch(playerControllerProvider).loading`
- `_ready` → `ref.watch(playerControllerProvider).ready`
- `_error` → `ref.watch(playerControllerProvider).error`
- `_currentEpisode` → `ref.watch(playerControllerProvider).currentEpisode`
- `_episodes` → `ref.watch(playerControllerProvider).episodes`
- `_seasonName` → `ref.watch(playerControllerProvider).seasonName`
- `_speed` → `ref.watch(playerControllerProvider).speed`
- `_autoPlayCountdown` → `ref.watch(playerControllerProvider).autoPlayCountdown`
- `_skip` → `ref.watch(playerControllerProvider).skipTimes`
- `_availableLangs` → `ref.watch(playerControllerProvider).availableLanguages`

Garder dans le State de la page uniquement :
- `_videoController` (référence au VideoController de media_kit — rendu vidéo Flutter)
- Les `GlobalKey` pour le menu contextuel

```dart
late final VideoController _videoController;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final controller = ref.read(playerControllerProvider.notifier);
    _videoController = controller.videoController;
    controller.setCurrentMedia(widget.media);
    await controller.init(
      media: widget.media,
      requestedEpisode: widget.episode,
      entry: widget.entry,
    );
  });
}
```

- [ ] **Étape 4 : Remplacer les appels de mutation par des délégations**

Dans les méthodes `build`, `_goToEpisode`, `_setSpeed`, etc. :

```dart
// AVANT
await _markCurrentWatched();
// APRÈS
await ref.read(playerControllerProvider.notifier).goToNextEpisode(media: widget.media);

// AVANT
_setSpeed(1.5);
// APRÈS
ref.read(playerControllerProvider.notifier).setSpeed(1.5);

// AVANT
await _switchLanguage(lang);
// APRÈS
await ref.read(playerControllerProvider.notifier).switchLanguage(media: widget.media, lang: lang);
```

- [ ] **Étape 5 : Analyser**

```bash
dart analyze lib/src/ui/pages/player_page.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 6 : Vérifier les tests existants**

```bash
dart test test/controllers/
```

Résultat attendu : `9/9 tests passed`

- [ ] **Étape 7 : Commit**

```bash
git add lib/src/ui/pages/player_page.dart
git commit -m "refactor(player): PlayerPage delegates to PlayerController — remove direct repo access"
```

---

## Task 5 : LibraryState + LibraryController

**Files:**
- Create: `lib/src/controllers/library/library_state.dart`
- Create: `lib/src/controllers/library/library_controller.dart`
- Create: `test/controllers/library/library_controller_test.dart`
- Modify: `lib/src/app/providers.dart`

- [ ] **Étape 1 : Créer `lib/src/controllers/library/library_state.dart`**

```dart
library;

import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/logic/filter_sort_service.dart';

class LibraryState {
  final EntrySortField sortField;
  final bool sortDescending;
  final MediaFilter filter;
  final String searchQuery;
  final bool recheckRunning;

  const LibraryState({
    this.sortField = EntrySortField.updated,
    this.sortDescending = true,
    this.filter = const MediaFilter(),
    this.searchQuery = '',
    this.recheckRunning = false,
  });

  LibraryState copyWith({
    EntrySortField? sortField,
    bool? sortDescending,
    MediaFilter? filter,
    String? searchQuery,
    bool? recheckRunning,
  }) {
    return LibraryState(
      sortField: sortField ?? this.sortField,
      sortDescending: sortDescending ?? this.sortDescending,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      recheckRunning: recheckRunning ?? this.recheckRunning,
    );
  }
}
```

- [ ] **Étape 2 : Créer `lib/src/controllers/library/library_controller.dart`**

```dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/filter_sort_service.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../services/stream_resolver.dart';
import 'library_state.dart';

/// Gère le tri, filtre, recherche et recheck new_episode de la bibliothèque.
class LibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() => const LibraryState();

  void setSortField(EntrySortField field) {
    if (state.sortField == field) {
      state = state.copyWith(sortDescending: !state.sortDescending);
    } else {
      state = state.copyWith(sortField: field, sortDescending: true);
    }
  }

  void setFilter(MediaFilter filter) => state = state.copyWith(filter: filter);

  void setSearch(String query) => state = state.copyWith(searchQuery: query);

  void clearSearch() => state = state.copyWith(searchQuery: '');

  /// Trie et filtre [entries] selon l'état courant.
  List<ListEntry> applyFilterSort(List<ListEntry> entries) {
    final service = ref.read(filterSortServiceProvider);
    var result = entries;
    if (state.searchQuery.isNotEmpty) {
      // Filtrage par recherche textuelle (titre)
      final q = state.searchQuery.toLowerCase();
      result = result
          .where((e) => _titleOf(e).toLowerCase().contains(q))
          .toList();
    }
    if (state.filter.genre != null) {
      result = service.filterByGenre(result, state.filter.genre!);
    }
    return service.sort(result, state.sortField,
        descending: state.sortDescending);
  }

  String _titleOf(ListEntry e) {
    // Fallback : mediaId en string si pas de media en cache
    return e.media?.title.preferred ?? e.mediaId.toString();
  }

  /// Supprime un flag new_episode pour un anime donné.
  Future<void> clearNewEpisodeFlag(int mediaId) async {
    await ref
        .read(settingsRepositoryProvider)
        .delete(SettingsKeys.newEpisodeFor(mediaId));
  }
}
```

- [ ] **Étape 3 : Ajouter `libraryControllerProvider` dans providers.dart**

```dart
import '../controllers/library/library_controller.dart';
export '../controllers/library/library_state.dart';

final libraryControllerProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);
```

- [ ] **Étape 4 : Écrire les tests**

Créer `test/controllers/library/library_controller_test.dart` :

```dart
import 'package:test/test.dart';
import 'package:terebi/src/controllers/library/library_state.dart';
import 'package:terebi/src/domain/logic/filter_sort_service.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';

void main() {
  group('LibraryState.copyWith', () {
    test('sort field change préserve les autres champs', () {
      const s = LibraryState(sortDescending: false, searchQuery: 'naruto');
      final s2 = s.copyWith(sortField: EntrySortField.title);
      expect(s2.sortField, EntrySortField.title);
      expect(s2.sortDescending, isFalse);
      expect(s2.searchQuery, 'naruto');
    });

    test('copyWith sans arguments retourne état identique', () {
      const s = LibraryState(recheckRunning: true);
      final s2 = s.copyWith();
      expect(s2.recheckRunning, isTrue);
    });
  });

  group('FilterSortService (via LibraryController.applyFilterSort)', () {
    // Tests purs sur FilterSortService directement
    final service = const FilterSortService();

    final entries = [
      ListEntry(mediaId: 1, status: ListStatus.current, progress: 5,
          updatedAt: DateTime(2024, 1, 3), hiddenFromPlanning: false),
      ListEntry(mediaId: 2, status: ListStatus.current, progress: 2,
          updatedAt: DateTime(2024, 1, 1), hiddenFromPlanning: false),
      ListEntry(mediaId: 3, status: ListStatus.current, progress: 10,
          updatedAt: DateTime(2024, 1, 2), hiddenFromPlanning: false),
    ];

    test('tri par updated décroissant → mediaId 1, 3, 2', () {
      final sorted =
          service.sort(entries, EntrySortField.updated, descending: true);
      expect(sorted.map((e) => e.mediaId).toList(), [1, 3, 2]);
    });

    test('tri par updated croissant → mediaId 2, 3, 1', () {
      final sorted =
          service.sort(entries, EntrySortField.updated, descending: false);
      expect(sorted.map((e) => e.mediaId).toList(), [2, 3, 1]);
    });
  });
}
```

- [ ] **Étape 5 : Lancer les tests**

```bash
dart test test/controllers/library/library_controller_test.dart
```

Résultat attendu : `4/4 tests passed`

- [ ] **Étape 6 : Analyser**

```bash
dart analyze lib/src/controllers/library/ lib/src/app/providers.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 7 : Commit**

```bash
git add lib/src/controllers/library/ lib/src/app/providers.dart test/controllers/library/
git commit -m "feat(arch): add LibraryController + LibraryState with tests"
```

---

## Task 6 : Connecter LibraryPage au LibraryController

**Files:**
- Modify: `lib/src/ui/pages/library_page.dart`

- [ ] **Étape 1 : Supprimer la logique de tri/filtre inline dans `_SortedEntriesList`**

Dans `library_page.dart`, localiser le widget `_SortedEntriesList` (qui fait `.where`, `.sort` inline). Remplacer la logique de tri/filtre par :

```dart
// AVANT (inline dans le widget) :
final filtered = entries.where((e) => ...).toList()..sort(...);

// APRÈS (délégation au controller) :
final filtered = ref.read(libraryControllerProvider.notifier)
    .applyFilterSort(entries);
```

- [ ] **Étape 2 : Connecter le tri/filtre de `_SortBar` et `_FilterBar`**

Les widgets `_SortBar` et `_FilterBar` appellent des callbacks `onSortChanged` / `onFilterChanged`. Remplacer ces callbacks par des appels directs au controller :

```dart
// Dans _SortBar, remplacer le callback par :
ref.read(libraryControllerProvider.notifier).setSortField(field);

// Dans _FilterBar :
ref.read(libraryControllerProvider.notifier).setFilter(newFilter);

// Pour la recherche :
ref.read(libraryControllerProvider.notifier).setSearch(query);
```

- [ ] **Étape 3 : Remplacer `_clearNewEpisodeFlag` dans `_LibraryPageState`**

```dart
// AVANT :
void _clearNewEpisodeFlag(WidgetRef ref, int mediaId) {
  ref.read(settingsRepositoryProvider).delete(SettingsKeys.newEpisodeFor(mediaId));
  ref.invalidate(newEpisodeIdsProvider);
}

// APRÈS :
void _clearNewEpisodeFlag(WidgetRef ref, int mediaId) {
  ref.read(libraryControllerProvider.notifier).clearNewEpisodeFlag(mediaId);
  ref.invalidate(newEpisodeIdsProvider);
}
```

- [ ] **Étape 4 : Analyser**

```bash
dart analyze lib/src/ui/pages/library_page.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 5 : Lancer tous les tests**

```bash
dart test
```

Résultat attendu : tous les tests passent.

- [ ] **Étape 6 : Commit**

```bash
git add lib/src/ui/pages/library_page.dart
git commit -m "refactor(library): LibraryPage delegates sort/filter/clear to LibraryController"
```

---

## Task 7 : Vérification finale et push

- [ ] **Étape 1 : Analyse complète**

```bash
dart analyze lib/
```

Résultat attendu : `No issues found!`

- [ ] **Étape 2 : Suite complète des tests**

```bash
dart test
```

Résultat attendu : tous les tests passent (au moins 23 : 10 anciens + 9 EpisodeResolver + 4 LibraryController).

- [ ] **Étape 3 : Vérifier qu'aucune page n'importe un autre fichier de page**

```bash
grep -rn "import.*pages/" lib/src/ui/pages/
```

Le seul import inter-pages acceptable est `resume_helper.dart` (use case partagé). `player_page.dart` ne doit plus importer `library_page.dart`.

- [ ] **Étape 4 : Vérifier qu'aucune page n'importe un repository directement**

```bash
grep -rn "import.*repositories/" lib/src/ui/
```

Résultat attendu : aucune ligne.

- [ ] **Étape 5 : Commit final**

```bash
git add -A
git commit -m "chore(arch): scalable architecture v1 — PlayerController + LibraryController"
git push
```

---

## Récapitulatif de l'architecture après ce plan

```
lib/src/
├── controllers/
│   ├── player/
│   │   ├── player_state.dart       ← état immutable du lecteur
│   │   ├── episode_resolver.dart   ← logique pure testable
│   │   └── player_controller.dart  ← Notifier, zéro import Flutter UI
│   └── library/
│       ├── library_state.dart      ← état immutable de la bibliothèque
│       └── library_controller.dart ← Notifier, gère tri/filtre/recheck
├── app/providers.dart              ← tous les providers globaux centralisés
└── ui/pages/
    ├── player_page.dart            ← lit PlayerState, appelle PlayerController
    └── library_page.dart           ← lit LibraryState, appelle LibraryController
```

**Prochaines étapes (hors scope de ce plan) :**
- `CatalogController` pour `catalog_page.dart`
- `MediaDetailController` pour `media_detail_page.dart`
- Découpage de `providers.dart` en fichiers thématiques
- Système d'extensions `(id, source)` pour les futures sources de streaming
