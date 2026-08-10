/// Providers Riverpod — câblage des couches data/domain à l'UI.
///
/// Ce fichier PEUT importer Flutter/Riverpod (couche UI). La logique testée
/// reste dans domain/ (Dart pur) ; ici on ne fait qu'assembler.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../data/local/database.dart';
import '../data/remote/anilist_client.dart';
import '../data/remote/cached_anilist_client.dart';
import '../data/remote/jikan_client.dart';
import '../data/remote/request_queue.dart';
import '../data/repositories/list_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/meta_cache_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/logic/franchise_service.dart';
import '../domain/season_progress_repository.dart';
import '../domain/logic/progress_service.dart';
import '../domain/logic/stats_service.dart';
import '../domain/logic/filter_sort_service.dart';
import '../domain/logic/calendar_service.dart';
import '../services/ani_cli_resolver.dart';
import '../services/animesama_resolver.dart';
import '../services/health_service.dart';
import '../services/process_runner.dart';
import '../services/resolver_assets.dart';
import '../services/stream_resolver.dart';
import '../services/system_process_runner.dart';
import '../services/title_matcher.dart';

/// Base de données. **Doit être surchargé** au démarrage via
/// `ProviderScope(overrides: [databaseProvider.overrideWithValue(db)])`
/// après ouverture asynchrone (voir `bootstrap`).
final databaseProvider = Provider<TerebiDatabase>((ref) {
  throw UnimplementedError('databaseProvider doit être surchargé au démarrage');
});

/// Client HTTP partagé (fermé avec le conteneur).
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

// --- Repositories ---------------------------------------------------------

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(databaseProvider)),
);

final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(databaseProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(databaseProvider)),
);

final metaCacheRepositoryProvider = Provider<MetaCacheRepository>(
  (ref) => MetaCacheRepository(ref.watch(databaseProvider)),
);

// --- Clients distants -----------------------------------------------------

/// File de requêtes partagée (rate-limit + retry) pour AniList → évite le 429.
final requestQueueProvider = Provider<RequestQueue>((ref) => RequestQueue());
/// Client AniList brut (accès réseau direct).
final rawAniListClientProvider = Provider<AniListClient>(
  (ref) => AniListClient(client: ref.watch(httpClientProvider)),
);

/// Client AniList exposé à l'app : **caché** (cache-aside + TTL + file anti-429).
/// L'UI dépend de [AniListApi], donc le cache est transparent.
final aniListClientProvider = Provider<AniListApi>(
  (ref) => CachedAniListClient(
    inner: ref.watch(rawAniListClientProvider),
    cache: ref.watch(metaCacheRepositoryProvider),
    queue: ref.watch(requestQueueProvider),
  ),
);

final jikanClientProvider = Provider<JikanClient>(
  (ref) => JikanClient(client: ref.watch(httpClientProvider)),
);

// --- Services de logique (purs, sans état) --------------------------------

final progressServiceProvider =
    Provider<ProgressService>((ref) => const ProgressService());

final franchiseServiceProvider =
    Provider<FranchiseService>((ref) => const FranchiseService());

final statsServiceProvider =
    Provider<StatsService>((ref) => const StatsService());

final filterSortServiceProvider =
    Provider<FilterSortService>((ref) => const FilterSortService());

final calendarServiceProvider =
    Provider<CalendarService>((ref) => const CalendarService());

// --- Services système / lecteur -------------------------------------------

/// ProcessRunner réel basé sur dart:io (injecté en prod, mocké en test).
final processRunnerProvider = Provider<ProcessRunner>(
  (ref) => systemProcessRunner,
);

/// Secure storage pour le token AniList.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Repository paramètres applicatifs (chemins ani-cli/mpv, langue…).
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Progression PAR saison anime-sama (dernier épisode vu par saison).
final seasonProgressRepositoryProvider = Provider<SeasonProgressRepository>(
  (ref) => SeasonProgressRepository(ref.watch(settingsRepositoryProvider)),
);

/// Résolveur ani-cli : détection plateforme (sh de Git Bash + VRAI script
/// ani-cli, en évitant le shim Scoop cassé). Un chemin saisi dans les Paramètres
/// n'est retenu que s'il pointe un fichier réel (sinon on garde la détection).
final aniCliResolverProvider = FutureProvider<AniCliResolver>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final defaults = AniCliDefaults.detect();

  // Chemin ani-cli : préférence à la détection ; le réglage manuel ne prime que
  // s'il désigne un fichier existant (évite un « ani-cli » nu → shim WSL cassé).
  final manualPath = await settings.get(SettingsKeys.aniCliPath);
  final path = (manualPath != null &&
          manualPath.isNotEmpty &&
          File(manualPath).existsSync())
      ? manualPath
      : defaults.aniCliPath;

  // Shell : réglage manuel s'il existe, sinon détection.
  final manualShell = await settings.get(SettingsKeys.shellPath);
  final shell = (manualShell != null && manualShell.isNotEmpty)
      ? manualShell
      : defaults.shell;

  return AniCliResolver(
    aniCliPath: path,
    shell: (shell != null && shell.isEmpty) ? null : shell,
    runner: ref.watch(processRunnerProvider),
  );
});

/// Résolveur anime-sama (VOSTFR/VF) via le wrapper Python.
/// Chemins Python/anime_sama.py depuis les Paramètres, sinon détection auto.
final animeSamaResolverProvider =
    FutureProvider<AnimeSamaResolver>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final defaults = AnimeSamaDefaults.detect();

  final manualPython = await settings.get(SettingsKeys.pythonPath);
  final python = (manualPython != null && manualPython.isNotEmpty)
      ? manualPython
      : defaults.pythonPath;

  final manualScript = await settings.get(SettingsKeys.animeSamaScript);
  final animeSamaScript = (manualScript != null && manualScript.isNotEmpty)
      ? manualScript
      : defaults.animeSamaScriptPath;

  // Wrapper Python extrait des assets vers le disque.
  final wrapper = await ensureWrapperScript();

  return AnimeSamaResolver(
    pythonPath: python,
    wrapperScriptPath: wrapper,
    animeSamaScriptPath: animeSamaScript,
    runner: ref.watch(processRunnerProvider),
  );
});

/// --- Providers anime-sama partagés (dédup + cache Riverpod) ----------------
/// Ces providers évitent de relancer le wrapper Python plusieurs fois pour le
/// même anime : fiche, tuiles de saison, lecteur et recheck partagent le même
/// résultat mis en cache tant qu'ils ne sont pas invalidés.

/// Saisons anime-sama d'un titre (VOSTFR par défaut, cf. wrapper).
final animeSamaSeasonsProvider =
    FutureProvider.family<List<AnimeSamaSeason>, String>((ref, title) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  return resolver.listSeasons(title: title);
});

/// Numéros d'épisodes d'une (saison) anime-sama. Keyé sur (titre, index) pour
/// que fiche + lecteur + recheck réutilisent le même résultat.
final animeSamaEpisodesProvider = FutureProvider.family<List<int>,
    ({String title, int seasonIndex})>((ref, arg) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  return resolver.listEpisodes(title: arg.title, seasonIndex: arg.seasonIndex);
});

/// Planning hebdomadaire anime-sama. Partagé entre le calendrier et la fiche
/// (qui l'utilise pour l'étiquette « À jour » vs « Terminée »). Respecte la
/// langue de lecture choisie (VF/VOSTFR).
final animeSamaPlanningProvider =
    FutureProvider<List<AnimeSamaPlanningItem>>((ref) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  final settings = ref.watch(settingsRepositoryProvider);
  final langStr =
      await settings.get(SettingsKeys.playbackLanguage, defaultValue: 'vostfr');
  final language =
      langStr == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
  return resolver.planning(language: language);
});

/// Langues (VOSTFR/VF) réellement disponibles pour un ÉPISODE précis d'une
/// saison anime-sama. La dispo est par épisode (certains épisodes récents ne
/// sont pas encore doublés). On teste chaque langue en résolvant l'URL du flux :
/// une langue est disponible si la résolution renvoie une URL. Sert au
/// sélecteur du lecteur (grise la langue absente) et au fallback.
final animeSamaLanguagesProvider = FutureProvider.family<Set<PlaybackLanguage>,
    ({String title, int seasonIndex, int episode})>((ref, arg) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  Future<bool> hasLang(PlaybackLanguage lang) async {
    try {
      final url = await resolver.resolveStreamUrl(
        title: arg.title,
        episode: arg.episode,
        season: arg.seasonIndex,
        language: lang,
      );
      return url.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  final results = await Future.wait([
    hasLang(PlaybackLanguage.vostfr),
    hasLang(PlaybackLanguage.vf),
  ]);
  return {
    if (results[0]) PlaybackLanguage.vostfr,
    if (results[1]) PlaybackLanguage.vf,
  };
});

/// Rematch titre anime-sama → Media AniList (avec cache titre→anilistId).
final titleMatcherProvider = Provider<TitleMatcher>(
  (ref) => TitleMatcher(
    anilist: ref.watch(aniListClientProvider),
    settings: ref.watch(settingsRepositoryProvider),
    mediaRepo: ref.watch(mediaRepositoryProvider),
  ),
);

/// Résolveur actif selon le réglage `streamSource` (défaut : anime-sama VOSTFR).
final activeResolverProvider = FutureProvider<StreamResolver>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final source = await settings.get(SettingsKeys.streamSource,
      defaultValue: 'animesama');
  if (source == 'ani_cli') {
    return ref.watch(aniCliResolverProvider.future);
  }
  return ref.watch(animeSamaResolverProvider.future);
});

/// Service health-check câblé sur toutes les sondes réelles.
///
/// Les chemins ani-cli/mpv sont des valeurs par défaut synchrones ; la
/// [SettingsPage] recrée le service à chaque health-check avec les chemins
/// lus depuis [settingsRepositoryProvider].
final healthServiceProvider = Provider<HealthService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final db = ref.watch(databaseProvider);
  final httpClient = ref.watch(httpClientProvider);

  return HealthService(
    runner: ref.watch(processRunnerProvider),
    aniCliPath: 'ani-cli',
    mpvPath: 'mpv',
    hasValidToken: () async {
      final token = await storage.read(key: 'anilist_token');
      return token != null && token.isNotEmpty;
    },
    databaseOk: () async {
      await db.select(db.appSettings).get();
      return true;
    },
    networkOk: () async {
      try {
        final resp = await httpClient.post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {'Content-Type': 'application/json'},
          body: '{"query":"{ Page(page:1,perPage:1){ media{ id } } }"}',
        );
        return resp.statusCode < 500;
      } catch (_) {
        return false;
      }
    },
  );
});

// --- État page Paramètres (modifs non sauvegardées) ------------------------

/// `true` quand la page Paramètres a des modifications non sauvegardées.
/// Lu par l'AppShell pour bloquer le changement d'onglet (façon Discord).
final settingsDirtyProvider = StateProvider<bool>((ref) => false);

/// Compteur incrémenté par l'AppShell quand l'utilisateur tente de quitter la
/// page Paramètres avec des modifs non sauvées : déclenche le clignotement
/// rouge de la barre d'actions en bas de page.
final settingsFlashProvider = StateProvider<int>((ref) => 0);
