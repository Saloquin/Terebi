/// Helper partagé : reprise de lecture en 1 clic depuis n'importe quel point
/// d'entrée (bibliothèque, accueil, fiche). Tout est calculé en local (saison
/// mémorisée + dernier épisode vu par saison), sans appel réseau, puis ouvre le
/// lecteur sur l'épisode à reprendre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/season_progress_repository.dart';
import 'player_page.dart';

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
      await settings.get(SettingsKeys.animeSamaSeasonFor(media.anilistId));
  final seasonIndex =
      (storedSeason != null ? int.tryParse(storedSeason) : null) ?? 1;
  final lastWatched =
      await seasonProgress.lastWatched(media.anilistId, seasonIndex);
  final startEpisode =
      lastWatched >= SeasonProgressRepository.fullyWatchedSentinel
          ? 1
          : lastWatched + 1;

  final entry = await ref.read(listRepositoryProvider).getEntry(media.anilistId) ??
      ListEntry(
        mediaId: media.anilistId,
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
