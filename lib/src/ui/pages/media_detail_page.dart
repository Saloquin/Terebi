/// Page de détail d'un média : cover, synopsis, genres, relations, actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/franchise_service.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/models/media_relation.dart';
import 'player_page.dart';

// ---------------------------------------------------------------------------
// Providers locaux
// ---------------------------------------------------------------------------

final _mediaDetailProvider =
    FutureProvider.family<Media, int>((ref, id) async {
  return ref.watch(aniListClientProvider).mediaDetail(id);
});


final _listEntryProvider =
    FutureProvider.family<ListEntry?, int>((ref, mediaId) async {
  return ref.watch(listRepositoryProvider).getEntry(mediaId);
});

/// Provider "Saisons" : charge toutes les saisons liées (sequel/prequel/parent)
/// pour un média, inclut le média courant, et les trie chronologiquement.
///
/// Types retenus : [RelationType.sequel], [RelationType.prequel],
/// [RelationType.parent]. Spin-off, side-story, alternative et other exclus.
final _seasonsProvider =
    FutureProvider.family<List<_SeasonItem>, int>((ref, anilistId) async {
  final anilist = ref.watch(aniListClientProvider);
  final listRepo = ref.watch(listRepositoryProvider);

  final relations = await anilist.relations(anilistId);
  final seasonRelations = relations
      .where((r) =>
          r.type == RelationType.sequel ||
          r.type == RelationType.prequel ||
          r.type == RelationType.parent)
      .toList();

  // Charge le média courant + les médias liés.
  final items = <_SeasonItem>[];

  // Média courant.
  try {
    final current = await anilist.mediaDetail(anilistId);
    final entry = await listRepo.getEntry(anilistId);
    items.add(_SeasonItem(media: current, entry: entry, isCurrent: true));
  } catch (_) {}

  // Médias liés (seasons).
  for (final rel in seasonRelations) {
    // Évite les doublons si le média lié est déjà dans la liste.
    if (items.any((i) => i.media.anilistId == rel.relatedMediaId)) continue;
    try {
      final m = await anilist.mediaDetail(rel.relatedMediaId);
      final entry = await listRepo.getEntry(rel.relatedMediaId);
      items.add(_SeasonItem(media: m, entry: entry, isCurrent: false));
    } catch (_) {}
  }

  // Tri chronologique : d'abord par seasonYear, puis par titre.
  items.sort((a, b) {
    final ya = a.media.seasonYear;
    final yb = b.media.seasonYear;
    if (ya != null && yb != null) {
      final cmp = ya.compareTo(yb);
      if (cmp != 0) return cmp;
    } else if (ya != null) {
      return -1;
    } else if (yb != null) {
      return 1;
    }
    return a.media.title.preferred.compareTo(b.media.title.preferred);
  });

  return items;
});

class _SeasonItem {
  final Media media;
  final ListEntry? entry;
  final bool isCurrent;
  const _SeasonItem(
      {required this.media, required this.entry, required this.isCurrent});
}

/// Provider auto-replanif : calcule les suites à proposer pour [anilistId].
///
/// Retourne les [Media] des suites non suivies d'un média COMPLETED.
final _sequelsToReplanProvider =
    FutureProvider.family<List<Media>, int>((ref, anilistId) async {
  final anilist = ref.watch(aniListClientProvider);
  final listRepo = ref.watch(listRepositoryProvider);
  final franchiseService = ref.watch(franchiseServiceProvider);

  // Charge les relations du média courant.
  final relations = await anilist.relations(anilistId);
  final sequelRelations =
      relations.where((r) => r.type == RelationType.sequel).toList();
  if (sequelRelations.isEmpty) return const [];

  // Charge les médias des suites.
  final sequelMediaList = <Media>[];
  for (final rel in sequelRelations) {
    try {
      final m = await anilist.mediaDetail(rel.relatedMediaId);
      sequelMediaList.add(m);
    } catch (_) {
      // Ignore erreurs individuelles.
    }
  }
  if (sequelMediaList.isEmpty) return const [];

  // Construit les FranchiseItems.
  final allMediaIds = [anilistId, ...sequelMediaList.map((m) => m.anilistId)];
  final items = <FranchiseItem>[];
  for (final id in allMediaIds) {
    Media? media;
    if (id == anilistId) {
      // On a déjà les données du média courant via le parent, mais on refetch.
      try {
        media = await anilist.mediaDetail(id);
      } catch (_) {
        continue;
      }
    } else {
      media = sequelMediaList.firstWhere((m) => m.anilistId == id);
    }
    final entry = await listRepo.getEntry(id);
    items.add(FranchiseItem(media: media, entry: entry));
  }

  final toReplan = franchiseService.sequelsToReplan(
    items: items,
    relations: relations,
  );

  return sequelMediaList
      .where((m) => toReplan.contains(m.anilistId))
      .toList();
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

                // --- Auto-replanif (suites disponibles non suivies) ---
                _ReplanSection(anilistId: media.anilistId),
                const SizedBox(height: 8),

                // --- Saisons ---
                _SeasonsSection(anilistId: media.anilistId),
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
              final currentEntry = entry ??
                  ListEntry(
                    mediaId: media.anilistId,
                    status: ListStatus.current,
                    updatedAt: DateTime.now(),
                  );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerPage(
                    media: media,
                    episode: resumeEp,
                    entry: currentEntry,
                  ),
                ),
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
        // Sauvegarde les métadonnées du média (titre/cover) pour la bibliothèque.
        await ref.read(mediaRepositoryProvider).upsertMedia(media);
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
// Section Saisons
// ---------------------------------------------------------------------------

/// Liste toutes les saisons d'une franchise (sequel/prequel/parent + média
/// courant), triées chronologiquement, avec badge de statut de suivi.
class _SeasonsSection extends ConsumerWidget {
  final int anilistId;
  const _SeasonsSection({required this.anilistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonsAsync = ref.watch(_seasonsProvider(anilistId));

    return seasonsAsync.maybeWhen(
      data: (items) {
        // N'affiche la section que s'il y a au moins 2 entrées (la saison
        // courante + au moins une autre), sinon rien d'intéressant à montrer.
        if (items.length < 2) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saisons', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final item in items)
              _SeasonTile(item: item),
            const SizedBox(height: 8),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SeasonTile extends StatelessWidget {
  final _SeasonItem item;
  const _SeasonTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final media = item.media;
    final entry = item.entry;
    final yearLabel = media.seasonYear != null ? '${media.seasonYear}' : '';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: media.coverUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                media.coverUrl!,
                width: 36,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 36, height: 50),
              ),
            )
          : const SizedBox(width: 36, height: 50),
      title: Text(
        media.title.preferred,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: item.isCurrent
            ? TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
      subtitle: yearLabel.isNotEmpty ? Text(yearLabel) : null,
      trailing: entry != null ? _StatusBadge(status: entry.status.name) : null,
      onTap: item.isCurrent
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaDetailPage(anilistId: media.anilistId),
                ),
              ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  static const _labels = {
    'current': 'En cours',
    'planning': 'Planifié',
    'completed': 'Terminé',
    'paused': 'En pause',
    'dropped': 'Abandonné',
    'repeating': 'Re-vision',
  };

  static const _colors = {
    'current': Colors.blue,
    'planning': Colors.orange,
    'completed': Colors.green,
    'paused': Colors.grey,
    'dropped': Colors.red,
    'repeating': Colors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[status] ?? status;
    final color = _colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section auto-replanif (US-46)
// ---------------------------------------------------------------------------

/// Encart "Nouvelle saison disponible" affiché si des suites sont disponibles
/// et non encore suivies, après avoir complété le média [anilistId].
class _ReplanSection extends ConsumerWidget {
  final int anilistId;
  const _ReplanSection({required this.anilistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sequelsAsync = ref.watch(_sequelsToReplanProvider(anilistId));

    return sequelsAsync.maybeWhen(
      data: (sequels) {
        if (sequels.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouvelle saison disponible',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final media in sequels)
              _ReplanCard(media: media),
            const SizedBox(height: 8),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ReplanCard extends ConsumerStatefulWidget {
  final Media media;
  const _ReplanCard({required this.media});

  @override
  ConsumerState<_ReplanCard> createState() => _ReplanCardState();
}

class _ReplanCardState extends ConsumerState<_ReplanCard> {
  bool _added = false;

  Future<void> _addToPlanning() async {
    final repo = ref.read(listRepositoryProvider);
    final existing = await repo.getEntry(widget.media.anilistId);
    final entry = existing?.copyWith(
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        ) ??
        ListEntry(
          mediaId: widget.media.anilistId,
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        );
    await repo.upsertEntry(entry);
    if (mounted) {
      setState(() => _added = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '« ${widget.media.title.preferred} » ajouté en Planifié'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: widget.media.coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  widget.media.coverUrl!,
                  width: 40,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(width: 40, height: 56),
                ),
              )
            : const Icon(Icons.new_releases_outlined),
        title: Text(widget.media.title.preferred,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          _added ? 'Ajouté en Planifié' : 'Suite disponible — Ajouter à voir ?',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: _added
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton.tonal(
                onPressed: _addToPlanning,
                child: const Text('À voir'),
              ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MediaDetailPage(anilistId: widget.media.anilistId),
          ),
        ),
      ),
    );
  }
}
