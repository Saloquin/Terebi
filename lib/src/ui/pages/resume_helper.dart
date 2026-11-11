/// Helper partagé : reprise de lecture en 1 clic depuis n'importe quel point
/// d'entrée (bibliothèque, accueil, fiche). Tout est calculé en local (saison
/// mémorisée + dernier épisode vu par saison), sans appel réseau, puis ouvre le
/// lecteur sur l'épisode à reprendre.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/random_entry_picker.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/season_progress_repository.dart';
import 'player_page.dart';

/// Libellé du bouton de lancement aléatoire selon l'onglet de bibliothèque,
/// ou `null` pour les onglets qui ne le proposent pas.
String? randomLaunchLabel(ListStatus status) => switch (status) {
      ListStatus.current => 'Reprendre au hasard',
      ListStatus.planning => 'Lancer au hasard',
      _ => null,
    };

/// Ouvre le lecteur sur l'épisode à reprendre pour [media].
///
/// - saison = celle mémorisée pour ce média (défaut 1) ;
/// - épisode = dernier vu + 1 ; si la saison a été marquée « entièrement vue »
///   (sentinelle), on repart à 1 (revoir depuis le début) plutôt qu'à un
///   numéro inexistant.
/// Utilise l'entrée de liste existante, ou en crée une minimale (Planifié).
Future<void> resumePlayback(
  BuildContext context,
  WidgetRef ref,
  Media media,
) async {
  final settings = ref.read(settingsRepositoryProvider);
  final seasonProgress = ref.read(seasonProgressRepositoryProvider);

  final storedSeason =
      await settings.get(SettingsKeys.animeSamaSeasonFor(media.mediaId));
  final seasonIndex =
      (storedSeason != null ? int.tryParse(storedSeason) : null) ?? 1;
  final lastWatched =
      await seasonProgress.lastWatched(media.mediaId, seasonIndex);
  final startEpisode =
      lastWatched >= SeasonProgressRepository.fullyWatchedSentinel
          ? 1
          : lastWatched + 1;

  final entry = await ref.read(listRepositoryProvider).getEntry(media.mediaId) ??
      ListEntry(
        mediaId: media.mediaId,
        status: ListStatus.planning,
        updatedAt: DateTime.now(),
      );

  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PlayerPage(
        media: media,
        episode: startEpisode,
        entry: entry,
        animeSamaTitle: media.animeSamaTitle,
      ),
    ),
  );
}

/// Tire un anime au hasard parmi [candidates] (en évitant [excludeMediaId] si
/// possible), efface son éventuel badge « nouvel épisode » et lance/reprend sa
/// lecture via [resumePlayback].
Future<Media?> resumeRandomPlayback(
  BuildContext context,
  WidgetRef ref,
  List<ListEntry> candidates, {
  Map<int, Media>? mediaMap,
  int? excludeMediaId,
  Random? random,
}) async {
  final pool = shuffledEntriesForRandomPick(
    candidates,
    excludeMediaId: excludeMediaId,
    random: random,
  );
  if (pool.isEmpty) return null;

  final mediaRepo = ref.read(mediaRepositoryProvider);
  Media? picked;
  ListEntry? pickedEntry;
  for (final e in pool) {
    final m = mediaMap?[e.mediaId] ?? await mediaRepo.getMedia(e.mediaId);
    if (m != null) {
      picked = m;
      pickedEntry = e;
      break;
    }
  }
  if (picked == null || pickedEntry == null) return null;

  try {
    await ref
        .read(libraryControllerProvider.notifier)
        .clearNewEpisodeFlag(pickedEntry.mediaId);
    ref.invalidate(newEpisodeFlagProvider(pickedEntry.mediaId));
  } catch (_) {}

  if (!context.mounted) return picked;
  await resumePlayback(context, ref, picked);
  return picked;
}
