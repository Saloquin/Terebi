/// Providers Riverpod — câblage des couches data/domain à l'UI.
///
/// Ce fichier PEUT importer Flutter/Riverpod (couche UI). La logique testée
/// reste dans domain/ (Dart pur) ; ici on ne fait qu'assembler.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/local/database.dart';
import '../data/remote/anilist_client.dart';
import '../data/remote/jikan_client.dart';
import '../data/repositories/list_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/meta_cache_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../domain/logic/franchise_service.dart';
import '../domain/logic/progress_service.dart';
import '../domain/logic/stats_service.dart';

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
