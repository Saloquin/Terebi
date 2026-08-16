/// Providers Riverpod — câblage des couches data/domain à l'UI.
///
/// Ce fichier PEUT importer Flutter/Riverpod (couche UI). La logique testée
/// reste dans domain/ (Dart pur) ; ici on ne fait qu'assembler.
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/local/database.dart';
import '../data/local/connection.dart' show databaseFilePath;
import '../data/repositories/list_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/meta_cache_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/watch_history_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/logic/anime_id.dart';
import '../domain/logic/effective_status_service.dart';
import '../domain/logic/franchise_service.dart';
import '../domain/season_progress_repository.dart';
import '../domain/logic/progress_service.dart';
import '../domain/logic/stats_service.dart';
import '../domain/logic/filter_sort_service.dart';
import '../domain/logic/calendar_service.dart';
import 'package:rxdart/rxdart.dart';

import '../domain/models/list_entry.dart';
import '../domain/models/list_status.dart';
import '../domain/models/media.dart';
import '../services/animesama_catalog_service.dart';
import '../services/animesama_resolver.dart';
import '../services/health_service.dart';
import '../services/process_runner.dart';
import '../services/resolver_assets.dart';
import '../services/slug_migration_service.dart';
import '../services/stream_resolver.dart';
import '../services/system_process_runner.dart';

/// Base de données. **Doit être surchargé** au démarrage via
/// `ProviderScope(overrides: [databaseProvider.overrideWithValue(db)])`
/// après ouverture asynchrone (voir `bootstrap`).
final databaseProvider = Provider<TerebiDatabase>((ref) {
  throw UnimplementedError('databaseProvider doit être surchargé au démarrage');
});

/// Chemin absolu du fichier de base de données (affiché dans les Paramètres).
final databasePathProvider =
    FutureProvider<String>((ref) => databaseFilePath());

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

/// `true` si l'anime [mediaId] a une progression locale. Reactif : re-emet des
/// qu'une entree de liste ou une cle `anime_sama_watched:<id>:*` change.
final hasProgressProvider = StreamProvider.family<bool, int>((ref, mediaId) {
  final listRepo = ref.watch(listRepositoryProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  return Rx.combineLatest2(
    listRepo.watchEntry(mediaId),
    settings.watchWithPrefix('anime_sama_watched:$mediaId:'),
    (ListEntry? entry, Map<String, String> watched) {
      if ((entry?.progress ?? 0) > 0) return true;
      return watched.values.any((v) => (int.tryParse(v) ?? 0) > 0);
    },
  );
});

/// Entree de liste (statut/progression) d'un media, en flux temps reel.
/// Declaree ici (et non dans une page) pour etre observable depuis toute page
/// ET par [libraryStatusMapProvider] sans import circulaire.
final listEntryProvider =
    StreamProvider.family<ListEntry?, int>((ref, mediaId) {
  return ref.watch(listRepositoryProvider).watchEntry(mediaId);
});

/// Statut EFFECTIF (affiche) de CHAQUE anime present dans la bibliotheque, en un
/// seul flux : `mediaId -> ListStatus`. Un anime absent de la map n'est ni suivi
/// ni progresse (donc « pas en bibliotheque »).
///
/// Reproduit la semantique de la bibliotheque (watchAllEntries + effectiveStatus
/// + hasAnyProgress) : « en cours » (current) n'est jamais stocke, il est derive
/// de la progression. Un seul watch pour toute la page catalogue (bien plus
/// efficace que N providers par tuile) ; sert aux badges et au masquage.
final libraryStatusMapProvider = StreamProvider<Map<int, ListStatus>>((ref) {
  final seasonProgress = ref.watch(seasonProgressRepositoryProvider);
  return ref
      .watch(listRepositoryProvider)
      .watchAllEntries()
      .asyncMap((all) async {
    final map = <int, ListStatus>{};
    for (final e in all) {
      final hasProgress =
          e.progress > 0 || await seasonProgress.hasAnyProgress(e.mediaId);
      final eff = effectiveStatus(entry: e, hasProgress: hasProgress);
      if (eff != null) map[e.mediaId] = eff;
    }
    return map;
  });
});

final metaCacheRepositoryProvider = Provider<MetaCacheRepository>(
  (ref) => MetaCacheRepository(ref.watch(databaseProvider)),
);

/// Durée (secondes) de rotation du hero « Nouvelles sorties », réactive : le
/// hero se réajuste dès que le réglage change dans les Paramètres. Défaut 10,
/// borné à [5, 60].
final heroRotationSecondsProvider = StreamProvider<int>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return settings
      .watchWithPrefix(SettingsKeys.heroRotationSeconds)
      .map((m) {
    final raw = m[SettingsKeys.heroRotationSeconds];
    final v = int.tryParse(raw ?? '') ?? 10;
    return v.clamp(5, 60);
  });
});

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

/// Service catalogue anime-sama (cache-first + revalidation background).
final animeSamaCatalogServiceProvider =
    FutureProvider<AnimeSamaCatalogService>((ref) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  return AnimeSamaCatalogService(
    mediaRepo: ref.watch(mediaRepositoryProvider),
    fetchDetail: (slug) => resolver.catalogueDetail(slug: slug),
  );
});

/// Stream cache-first du media enrichi pour un slug anime-sama.
final animeSamaDetailProvider =
    StreamProvider.family<Media?, String>((ref, slug) async* {
  final service = await ref.watch(animeSamaCatalogServiceProvider.future);
  yield* service.watchDetail(slug);
});

/// Sections de l'accueil anime-sama (classiques + derniers episodes).
final animeSamaHomeProvider = FutureProvider<AnimeSamaHome>((ref) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  try {
    return await resolver.home();
  } catch (_) {
    return const AnimeSamaHome();
  }
});

/// Catalogue filtre par genre.
final animeSamaByGenreProvider =
    FutureProvider.family<List<AnimeSamaCatalogueItem>, String>(
        (ref, genre) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  try {
    return await resolver.catalogueByGenre(genre: genre);
  } catch (_) {
    return const [];
  }
});

/// Criteres de filtrage du catalogue « parcourir ». Record Dart = egalite par
/// valeur, donc utilisable directement comme cle de family (deux criteres
/// identiques -> meme resultat en cache).
typedef CatalogFilterCriteria = ({
  String genre,
  String anneeMin,
  String anneeMax,
  String episodesMin,
  String episodesMax,
});

/// Catalogue anime-sama filtre par criteres optionnels (genre/annee/episodes).
/// Vide en cas d'erreur (best-effort). Mode « parcourir » = criteres vides.
final animeSamaCatalogFilterProvider = FutureProvider.family<
    List<AnimeSamaCatalogueItem>, CatalogFilterCriteria>((ref, c) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  try {
    return await resolver.catalogueFilter(
      genre: c.genre,
      anneeMin: c.anneeMin,
      anneeMax: c.anneeMax,
      episodesMin: c.episodesMin,
      episodesMax: c.episodesMax,
    );
  } catch (_) {
    return const [];
  }
});

/// Declenche la re-indexation legacy titre->slug une seule fois (idempotente,
/// non bloquante). Watche au demarrage du shell.
final slugMigrationProvider = FutureProvider<void>((ref) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  final service = SlugMigrationService(
    mediaRepo: ref.watch(mediaRepositoryProvider),
    listRepo: ref.watch(listRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    historyRepo: ref.watch(watchHistoryRepositoryProvider),
    resolveSlug: (title) async {
      try {
        final items = await resolver.search(query: title);
        if (items.isEmpty) return '';
        var best = items.first;
        var bestScore = -1;
        for (final it in items) {
          final s = titleMatchScore(title, it.title);
          if (s > bestScore) {
            bestScore = s;
            best = it;
          }
        }
        return best.slug;
      } catch (_) {
        return '';
      }
    },
  );
  await service.runOnce();
});

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
        final resp = await httpClient
            .get(Uri.parse('https://anime-sama.to/'))
            .timeout(const Duration(seconds: 8));
        return resp.statusCode < 500;
      } catch (_) {
        return false;
      }
    },
    aniSkipOk: () async {
      try {
        final resp = await httpClient
            .get(Uri.parse('https://api.aniskip.com/'))
            .timeout(const Duration(seconds: 8));
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

