/// Page de détail d'un média : cover, synopsis, genres, relations, actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/models/media_relation.dart';

// ---------------------------------------------------------------------------
// Providers locaux
// ---------------------------------------------------------------------------

final _mediaDetailProvider =
    FutureProvider.family<Media, int>((ref, id) async {
  return ref.watch(aniListClientProvider).mediaDetail(id);
});

final _relationsProvider =
    FutureProvider.family<List<MediaRelation>, int>((ref, id) async {
  return ref.watch(aniListClientProvider).relations(id);
});

final _listEntryProvider =
    FutureProvider.family<ListEntry?, int>((ref, mediaId) async {
  return ref.watch(listRepositoryProvider).getEntry(mediaId);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

/// Page de détail d'un anime identifié par son [anilistId] AniList.
class MediaDetailPage extends ConsumerWidget {
  final int anilistId;

  const MediaDetailPage({super.key, required this.anilistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(_mediaDetailProvider(anilistId));

    return Scaffold(
      appBar: AppBar(
        title: mediaAsync.maybeWhen(
          data: (m) => Text(m.title.preferred, overflow: TextOverflow.ellipsis),
          orElse: () => const Text('Détail'),
        ),
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Impossible de charger le média',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(err.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        data: (media) => _DetailBody(media: media),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Corps de la page (média chargé)
// ---------------------------------------------------------------------------

class _DetailBody extends ConsumerWidget {
  final Media media;

  const _DetailBody({required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(_listEntryProvider(media.anilistId));
    final relationsAsync = ref.watch(_relationsProvider(media.anilistId));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Banner / cover header ---
          _Header(media: media),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Métadonnées rapides ---
                _MetaChips(media: media),
                const SizedBox(height: 16),

                // --- Actions : reprise + statut ---
                entryAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (entry) => _ActionBar(media: media, entry: entry),
                ),
                const SizedBox(height: 16),

                // --- Synopsis ---
                if (media.description != null &&
                    media.description!.isNotEmpty) ...[
                  Text('Synopsis',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SynopsisText(raw: media.description!),
                  const SizedBox(height: 16),
                ],

                // --- Genres ---
                if (media.genres.isNotEmpty) ...[
                  Text('Genres',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final g in media.genres)
                        Chip(label: Text(g), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // --- Franchise (relations) ---
                relationsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (relations) {
                    final relevant = relations
                        .where((r) =>
                            r.type == RelationType.sequel ||
                            r.type == RelationType.prequel)
                        .toList();
                    if (relevant.isEmpty) return const SizedBox.shrink();
                    return _FranchiseSection(
                        relations: relevant, currentId: media.anilistId);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header (banner + cover flottante)
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final Media media;
  const _Header({required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          // Banner
          Positioned.fill(
            child: media.bannerUrl != null
                ? Image.network(media.bannerUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ))
                : Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          // Cover + titre
          Positioned(
            left: 16,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: media.coverUrl != null
                      ? Image.network(media.coverUrl!,
                          width: 80,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 80, height: 110))
                      : const SizedBox(width: 80, height: 110),
                ),
                const SizedBox(width: 12),
                // Titre + score
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.title.preferred,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (media.averageScore != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${media.averageScore}%',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chips de métadonnées
// ---------------------------------------------------------------------------

class _MetaChips extends StatelessWidget {
  final Media media;
  const _MetaChips({required this.media});

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      _formatLabel(media),
      if (media.episodes != null) '${media.episodes} épisodes',
      if (media.durationMinutes != null) '${media.durationMinutes} min/ep',
      if (media.seasonYear != null)
        '${_seasonLabel(media.season?.name)} ${media.seasonYear}',
      _statusLabel(media.status.name),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final item in items)
          Chip(
            label: Text(item),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  static String _formatLabel(Media m) => switch (m.format.name) {
        'tv' => 'TV',
        'tvShort' => 'TV Court',
        'movie' => 'Film',
        'special' => 'Spécial',
        'ova' => 'OVA',
        'ona' => 'ONA',
        'music' => 'Musique',
        _ => '?',
      };

  static String _seasonLabel(String? s) => switch (s) {
        'winter' => 'Hiver',
        'spring' => 'Printemps',
        'summer' => 'Été',
        'fall' => 'Automne',
        _ => '',
      };

  static String _statusLabel(String s) => switch (s) {
        'finished' => 'Terminé',
        'releasing' => 'En cours',
        'notYetReleased' => 'À venir',
        'cancelled' => 'Annulé',
        'hiatus' => 'En pause',
        _ => 'Inconnu',
      };
}

// ---------------------------------------------------------------------------
// Barre d'actions
// ---------------------------------------------------------------------------

class _ActionBar extends ConsumerWidget {
  final Media media;
  final ListEntry? entry;

  const _ActionBar({required this.media, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressService = ref.read(progressServiceProvider);

    // Épisode à reprendre
    final resumeEp = entry == null
        ? 1
        : progressService.resumeEpisode(entry: entry!, media: media);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        // Bouton Reprendre
        if (resumeEp != null)
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lancer épisode $resumeEp')),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: Text('Épisode $resumeEp'),
          ),

        // Sélecteur de statut
        _StatusDropdown(media: media, entry: entry),
      ],
    );
  }
}

class _StatusDropdown extends ConsumerWidget {
  final Media media;
  final ListEntry? entry;

  const _StatusDropdown({required this.media, required this.entry});

  static const _labels = {
    ListStatus.current: 'En cours',
    ListStatus.planning: 'Planifié',
    ListStatus.completed: 'Terminé',
    ListStatus.paused: 'En pause',
    ListStatus.dropped: 'Abandonné',
    ListStatus.repeating: 'Re-vision',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = entry?.status;

    return DropdownButton<ListStatus>(
      value: current,
      hint: const Text('Ajouter à la liste'),
      items: ListStatus.values
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(_labels[s] ?? s.name),
              ))
          .toList(),
      onChanged: (newStatus) async {
        if (newStatus == null) return;
        final repo = ref.read(listRepositoryProvider);
        final existing = await repo.getEntry(media.anilistId);
        final updated = existing?.copyWith(
              status: newStatus,
              updatedAt: DateTime.now(),
            ) ??
            ListEntry(
              mediaId: media.anilistId,
              status: newStatus,
              updatedAt: DateTime.now(),
            );
        await repo.upsertEntry(updated);
        // Invalide le provider d'entrée pour rafraîchir l'UI.
        ref.invalidate(_listEntryProvider(media.anilistId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Statut mis à jour : ${_labels[newStatus]}')),
          );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Synopsis (retire les balises HTML basiques d'AniList)
// ---------------------------------------------------------------------------

class _SynopsisText extends StatelessWidget {
  final String raw;
  const _SynopsisText({required this.raw});

  String get _clean => raw
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();

  @override
  Widget build(BuildContext context) {
    return Text(_clean, style: Theme.of(context).textTheme.bodyMedium);
  }
}

// ---------------------------------------------------------------------------
// Section franchise
// ---------------------------------------------------------------------------

class _FranchiseSection extends StatelessWidget {
  final List<MediaRelation> relations;
  final int currentId;

  const _FranchiseSection(
      {required this.relations, required this.currentId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Franchise', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final rel in relations)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              rel.type == RelationType.sequel
                  ? Icons.arrow_forward
                  : Icons.arrow_back,
            ),
            title: Text(_typeLabel(rel.type)),
            subtitle: Text('ID AniList : ${rel.relatedMediaId}'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MediaDetailPage(anilistId: rel.relatedMediaId),
              ),
            ),
          ),
      ],
    );
  }

  static String _typeLabel(RelationType t) => switch (t) {
        RelationType.sequel => 'Suite',
        RelationType.prequel => 'Préquelle',
        _ => t.name,
      };
}
