/// Domaine applicatif — re-indexation de la BDD legacy vers l'identite par slug.
///
/// Au 1er boot post-migration v3, chaque media SANS slug est re-resolu vers son
/// slug anime-sama, et son identite (media + entree de liste + progression par
/// saison dans AppSettings) est deplacee de l'ancien id entier vers le nouvel id
/// derive du slug. Best-effort : un media non resolu est LOGUE (jamais
/// supprime). Idempotent via le drapeau `slug_migration_done`.
library;

import '../data/repositories/list_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/watch_history_repository.dart';
import '../domain/logic/anime_id.dart';
import '../domain/models/media.dart';

/// Resout le slug anime-sama d'un titre (injecte : reseau en prod, stub en test).
/// Retourne '' si non resolu.
typedef SlugResolver = Future<String> Function(String title);

class SlugMigrationService {
  static const _doneKey = 'slug_migration_done';
  static const _reportKey = 'slug_migration_report';

  final MediaRepository mediaRepo;
  final ListRepository listRepo;
  final SettingsRepository settings;
  final WatchHistoryRepository historyRepo;
  final SlugResolver resolveSlug;

  const SlugMigrationService({
    required this.mediaRepo,
    required this.listRepo,
    required this.settings,
    required this.historyRepo,
    required this.resolveSlug,
  });

  /// Lance la re-indexation une seule fois (no-op si deja faite).
  Future<void> runOnce() async {
    if (await settings.get(_doneKey) == '1') return;

    final all = await mediaRepo.getAllMedia();
    final failures = <String>[];

    for (final media in all) {
      if (media.animeSamaSlug != null && media.animeSamaSlug!.isNotEmpty) {
        continue; // deja migre
      }
      final title = media.animeSamaTitle ?? media.title.preferred;
      String slug = '';
      try {
        slug = await resolveSlug(title);
      } catch (_) {
        slug = '';
      }
      if (slug.isEmpty) {
        failures.add(title);
        continue; // conserve tel quel, jamais supprime
      }
      await _reindexOne(media, slug);
    }

    if (failures.isNotEmpty) {
      await settings.set(_reportKey, failures.join('\n'));
    }
    await settings.set(_doneKey, '1');
  }

  /// Deplace un media et sa progression de son ancien id vers l'id derive du slug.
  Future<void> _reindexOne(Media media, String slug) async {
    final oldId = media.anilistId;
    final newId = animeSamaIdForSlug(slug);
    if (oldId == newId) {
      await mediaRepo.upsertMedia(media.withSlug(slug));
      return;
    }
    // 1) Media : ecrire la nouvelle identite (slug renseigne), effacer l'ancienne.
    await mediaRepo.upsertMedia(media.withSlug(slug).withId(newId));
    await mediaRepo.deleteMedia(oldId);
    // 2) Entree de liste.
    await listRepo.reindexMediaId(oldId, newId);
    // 3) Historique de visionnage (sinon 'Regarde recemment' devient orphelin).
    await historyRepo.reindexMediaId(oldId, newId);
    // 4) Progression par saison + reglages par media.
    await settings.renameKeyPrefix(
        'anime_sama_watched:$oldId:', 'anime_sama_watched:$newId:');
    await settings.renameKeyPrefix(
        'anime_sama_season:$oldId', 'anime_sama_season:$newId');
    await settings.renameKeyPrefix(
        'anime_sama_lang:$oldId', 'anime_sama_lang:$newId');
    await settings.renameKeyPrefix(
        'new_episode:$oldId', 'new_episode:$newId');
  }
}
