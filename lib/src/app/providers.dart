/// Providers Riverpod — câblage des couches data/domain à l'UI.
///
/// Ce fichier PEUT importer Flutter/Riverpod (couche UI). La logique testée
/// reste dans domain/ (Dart pur) ; ici on ne fait qu'assembler.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../data/local/database.dart';
import '../data/remote/anilist_client.dart';
import '../data/remote/jikan_client.dart';
import '../data/repositories/list_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/meta_cache_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/logic/franchise_service.dart';
import '../domain/logic/progress_service.dart';
import '../domain/logic/stats_service.dart';
import '../domain/logic/filter_sort_service.dart';
import '../domain/logic/calendar_service.dart';
import '../services/ani_cli_resolver.dart';
import '../services/health_service.dart';
import '../services/process_runner.dart';
import '../services/system_process_runner.dart';

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

final aniListClientProvider = Provider<AniListClient>(
  (ref) => AniListClient(client: ref.watch(httpClientProvider)),
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

/// Résolveur ani-cli : lit le chemin depuis les settings ou utilise 'ani-cli'.
final aniCliResolverProvider = FutureProvider<AniCliResolver>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final path =
      await settings.get(SettingsKeys.aniCliPath, defaultValue: 'ani-cli') ??
          'ani-cli';
  return AniCliResolver(
    aniCliPath: path,
    runner: ref.watch(processRunnerProvider),
  );
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
