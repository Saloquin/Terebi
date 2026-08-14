/// Providers Riverpod — câblage des couches data/domain à l'UI.
///
/// Ce fichier PEUT importer Flutter/Riverpod (couche UI). La logique testée
/// reste dans domain/ (Dart pur) ; ici on ne fait qu'assembler.
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../data/repositories/watch_history_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/logic/anime_id.dart';
import '../domain/logic/franchise_service.dart';
import '../domain/season_progress_repository.dart';
import '../domain/logic/progress_service.dart';
import '../domain/logic/stats_service.dart';
import '../domain/logic/filter_sort_service.dart';
import '../domain/logic/calendar_service.dart';
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

final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>(
  (ref) => WatchHistoryRepository(ref.watch(databaseProvider)),
);

/// `true` si l'anime [mediaId] a une progression locale (progress global > 0 ou
/// au moins une saison anime-sama entamée). Sert à dériver « En cours » à
/// l'affichage (fiche/biblio) de façon instantanée, sans réseau.
final hasProgressProvider =
    FutureProvider.family<bool, int>((ref, mediaId) async {
  final entry = await ref.watch(listRepositoryProvider).getEntry(mediaId);
  if ((entry?.progress ?? 0) > 0) return true;
  return ref.watch(seasonProgressRepositoryProvider).hasAnyProgress(mediaId);
});

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

/// Repository paramètres applicatifs (chemins python/mpv, langue…).
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Progression PAR saison anime-sama (dernier épisode vu par saison).
final seasonProgressRepositoryProvider = Provider<SeasonProgressRepository>(
  (ref) => SeasonProgressRepository(ref.watch(settingsRepositoryProvider)),
);

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

  // Scripts Python extraits des assets vers le disque (aucune install requise).
  final wrapper = await ensureWrapperScript();
  final animeSamaScript = await ensureAnimeSamaScript();

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

/// Résout le VRAI titre anime-sama d'un anime AniList en essayant ses titres
/// candidats (anglais, romaji, natif) contre le catalogue anime-sama. Nécessaire
/// car anime-sama utilise souvent un titre DIFFÉRENT d'AniList (langue : « Attack
/// on Titan » AniList vs « Shingeki no Kyojin »/français sur anime-sama) — une
/// recherche sur le seul titre anglais échoue alors. Retourne le titre du 1er
/// candidat qui donne un résultat catalogue, sinon le 1er candidat non vide
/// (repli, pour ne pas bloquer). Keyé sur les candidats (cache Riverpod).
final animeSamaResolvedTitleProvider = FutureProvider.family<String,
    ({String? english, String? romaji, String? native})>((ref, t) async {
  final candidates = <String>[
    if (t.romaji != null && t.romaji!.trim().isNotEmpty) t.romaji!.trim(),
    if (t.english != null && t.english!.trim().isNotEmpty) t.english!.trim(),
    if (t.native != null && t.native!.trim().isNotEmpty) t.native!.trim(),
  ];
  if (candidates.isEmpty) return '';
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  var bestTitle = '';
  var bestScore = -1;
  for (final c in candidates) {
    try {
      final items = await resolver.search(query: c);
      // anime-sama renvoie souvent PLUSIEURS résultats dans un ordre arbitraire
      // (ex. « naruto » ⟶ [boruto, naruto, naruto shippuden…]). Prendre
      // items.first choisirait « boruto ». On score chaque titre catalogue
      // contre le candidat et on garde le meilleur (match exact/racine > dérivé).
      for (final it in items) {
        final s = titleMatchScore(c, it.title);
        if (s > bestScore) {
          bestScore = s;
          bestTitle = it.title;
        }
      }
      // Match exact trouvé pour ce candidat : inutile d'essayer les suivants.
      if (bestScore >= 1000) break;
    } catch (_) {/* candidat suivant */}
  }
  if (bestScore > 0) return bestTitle;
  return candidates.first; // repli : rien trouvé, on garde le 1er candidat.
});

/// Numéros d'épisodes d'une (saison) anime-sama. Keyé sur (titre, index) pour
/// que fiche + lecteur + recheck réutilisent le même résultat.
final animeSamaEpisodesProvider = FutureProvider.family<List<int>,
    ({String title, int seasonIndex})>((ref, arg) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  return resolver.listEpisodes(title: arg.title, seasonIndex: arg.seasonIndex);
});

/// Nombre TOTAL d'épisodes d'un anime-sama = somme des épisodes de toutes ses
/// saisons. Sert de source de vérité pour le temps de visionnage d'un anime
/// « Terminé » : `media.episodes` (Jikan) est souvent null ou figé pour les
/// longues séries (ex. One Piece), alors qu'anime-sama connaît le compte réel
/// par saison. Réutilise les providers globaux (cache partagé, pas de
/// re-scraping). Retourne 0 si anime-sama ne connaît pas le titre.
final animeSamaTotalEpisodesProvider =
    FutureProvider.family<int, String>((ref, title) async {
  final seasons = await ref.watch(animeSamaSeasonsProvider(title).future);
  var total = 0;
  for (final s in seasons) {
    final eps = await ref.watch(
      animeSamaEpisodesProvider((title: title, seasonIndex: s.index)).future,
    );
    total += eps.length;
  }
  return total;
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

/// Timestamps de skip intro/outro (AniSkip) d'un (titre, saison, épisode).
/// Best-effort : renvoie un [SkipTimes] vide si rien trouvé (jamais d'erreur).
/// Mis en cache Riverpod par clé → une seule requête AniSkip par épisode.
/// [malId] (via AniList/Jikan) fiabilise la résolution AniSkip s'il est connu.
final animeSamaSkipTimesProvider = FutureProvider.family<SkipTimes,
    ({String title, int seasonIndex, int episode, int? malId})>((ref, arg) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  return resolver.skipTimes(
    title: arg.title,
    episode: arg.episode,
    seasonIndex: arg.seasonIndex,
    malId: arg.malId,
  );
});

/// Rematch titre anime-sama → Media AniList (avec cache titre→anilistId).
final titleMatcherProvider = Provider<TitleMatcher>(
  (ref) => TitleMatcher(
    anilist: ref.watch(aniListClientProvider),
    settings: ref.watch(settingsRepositoryProvider),
    mediaRepo: ref.watch(mediaRepositoryProvider),
  ),
);

/// Résolveur de flux actif : anime-sama (unique source, VOSTFR/VF).
final activeResolverProvider = FutureProvider<StreamResolver>((ref) async {
  return ref.watch(animeSamaResolverProvider.future);
});

/// Service health-check câblé sur toutes les sondes réelles.
///
/// Le chemin mpv est une valeur par défaut synchrone ; la [SettingsPage] recrée
/// le service à chaque health-check avec les chemins lus depuis
/// [settingsRepositoryProvider].
final healthServiceProvider = Provider<HealthService>((ref) {
  final db = ref.watch(databaseProvider);
  final httpClient = ref.watch(httpClientProvider);

  return HealthService(
    runner: ref.watch(processRunnerProvider),
    pythonPath: 'python',
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

// --- Apparence -------------------------------------------------------------

/// Convertit la valeur stockée ('dark'|'light'|'system') en [ThemeMode].
ThemeMode themeModeFromString(String? value) => switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark, // défaut
    };

String themeModeToString(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };

/// Mode de thème actif. Initialisé au démarrage via override (valeur lue en
/// base dans `main`), puis mis à jour par la page Paramètres.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

