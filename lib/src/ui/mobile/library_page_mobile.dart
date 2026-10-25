/// Page de bibliothèque mobile tactile optimisée pour smartphone.
/// Comprend : sélecteur de statut par onglets, recherche rapide locale,
/// et bouton direct « +1 épisode » sur chaque carte sans ouvrir de sous-menus.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/season_progress_repository.dart';
import '../pages/media_detail_page.dart';
import '../pages/resume_helper.dart';
import '../widgets/anime_sama_image.dart';

class LibraryPageMobile extends ConsumerStatefulWidget {
  const LibraryPageMobile({super.key});

  @override
  ConsumerState<LibraryPageMobile> createState() => _LibraryPageMobileState();
}

class _LibraryPageMobileState extends ConsumerState<LibraryPageMobile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;

  static const _statuses = [
    ListStatus.current,
    ListStatus.planning,
    ListStatus.completed,
    ListStatus.paused,
    ListStatus.dropped,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(countByStatusProvider);
    final hasNewEpisode = ref.watch(newEpisodeIdsProvider).maybeWhen(
          data: (ids) => ids.isNotEmpty,
          orElse: () => false,
        );
    final theme = Theme.of(context);

    return Column(
      children: [
        // --- 1. BARRE DE RECHERCHE LOCALE & TOGGLE VUE ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrer ma liste...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: Icon(
                  _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  size: 20,
                ),
                tooltip: _isGridView ? 'Vue liste' : 'Vue grille',
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
            ],
          ),
        ),

        // --- 2. ONGLETS PAR STATUT ---
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          tabs: [
            for (final s in _statuses)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s == ListStatus.current && hasNewEpisode)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(s.label),
                    const SizedBox(width: 6),
                    countsAsync.maybeWhen(
                      data: (counts) {
                        final c = counts[s] ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$c',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // --- 3. CONTENU DE L'ONGLET SÉLECTIONNÉ ---
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (final s in _statuses)
                _MobileStatusTab(
                  status: s,
                  searchQuery: _searchQuery,
                  isGridView: _isGridView,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Contenu pour un statut particulier
class _MobileStatusTab extends ConsumerWidget {
  final ListStatus status;
  final String searchQuery;
  final bool isGridView;

  const _MobileStatusTab({
    required this.status,
    required this.searchQuery,
    required this.isGridView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesByStatusProvider(status));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $err', textAlign: TextAlign.center),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                Text('Aucun anime dans « ${status.label} »'),
              ],
            ),
          );
        }

        return _MobileEntriesList(
          entries: entries,
          status: status,
          searchQuery: searchQuery,
          isGridView: isGridView,
        );
      },
    );
  }
}

/// Résolution des titres et affichage liste / grille
class _MobileEntriesList extends ConsumerWidget {
  final List<ListEntry> entries;
  final ListStatus status;
  final String searchQuery;
  final bool isGridView;

  const _MobileEntriesList({
    required this.entries,
    required this.status,
    required this.searchQuery,
    required this.isGridView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaMapAsync = ref.watch(allMediaMapProvider);
    final mediaMap = mediaMapAsync.asData?.value ?? const {};

    var items = entries.map((e) => (entry: e, media: mediaMap[e.mediaId])).toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items.where((it) {
        final title = it.media?.title.preferred.toLowerCase() ?? '';
        final sama = it.media?.animeSamaTitle?.toLowerCase() ?? '';
        final slug = it.media?.animeSamaSlug?.toLowerCase() ?? '';
        return title.contains(q) || sama.contains(q) || slug.contains(q);
      }).toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(searchQuery.isNotEmpty
                ? 'Aucun anime ne correspond à « $searchQuery »'
                : 'Aucun anime dans « ${status.label} »'),
          ],
        ),
      );
    }

    if (isGridView) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final it = items[index];
              return _MobileGridCard(entry: it.entry, media: it.media);
            },
          );
        }

        // Vue Liste détaillée (optimisée smartphone avec action +1 épisode)
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final it = items[index];
            return _MobileListCard(
              entry: it.entry,
              media: it.media,
            );
          },
        );
  }
}

/// Carte de liste mobile avec bouton +1 épisode en 1 clic
class _MobileListCard extends ConsumerWidget {
  final ListEntry entry;
  final Media? media;

  const _MobileListCard({
    required this.entry,
    required this.media,
  });

  Future<void> _incrementEpisode(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final settings = ref.read(settingsRepositoryProvider);
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final listRepo = ref.read(listRepositoryProvider);

    final storedSeason =
        await settings.get(SettingsKeys.animeSamaSeasonFor(entry.mediaId));
    final seasonIndex =
        (storedSeason != null ? int.tryParse(storedSeason) : null) ?? 1;

    final currentWatched =
        await seasonProgress.lastWatched(entry.mediaId, seasonIndex);
    final nextEpisode = currentWatched + 1;

    await seasonProgress.setLastWatched(entry.mediaId, seasonIndex, nextEpisode);

    // Met à jour la ListEntry
    await listRepo.upsertEntry(entry.copyWith(
      progress: entry.progress + 1,
      updatedAt: DateTime.now(),
    ));

    // Efface le drapeau « nouvel épisode » si présent
    await ref
        .read(libraryControllerProvider.notifier)
        .clearNewEpisodeFlag(entry.mediaId);
    ref.invalidate(newEpisodeFlagProvider(entry.mediaId));
    ref.invalidate(entriesByStatusProvider);
    ref.invalidate(countByStatusProvider);

    if (context.mounted) {
      final name = media?.title.preferred ?? 'Anime';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name : Épisode $nextEpisode marqué vu !'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = (media?.title.preferred.isNotEmpty ?? false)
        ? media!.title.preferred
        : (media?.animeSamaTitle?.isNotEmpty ?? false)
            ? media!.animeSamaTitle!
            : (media?.animeSamaSlug?.isNotEmpty ?? false)
                ? media!.animeSamaSlug!
                : 'Anime #${entry.mediaId}';
    final slug = media?.animeSamaSlug ?? '';
    final cover = media?.coverUrl;

    final showNew = ref.watch(newEpisodeFlagProvider(entry.mediaId)).maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );

    final progressLabel = entry.status == ListStatus.completed
        ? 'Terminé'
        : entry.progress <= 0
            ? 'Non commencé'
            : entry.progress >= SeasonProgressRepository.fullyWatchedSentinel
                ? 'Terminé'
                : 'Épisode ${entry.progress}';

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaDetailPage(
                mediaId: entry.mediaId,
                displayTitle: media?.animeSamaTitle ??
                    ((media?.title.preferred.isNotEmpty ?? false)
                        ? media!.title.preferred
                        : null),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Vignette poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 58,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      slug.isNotEmpty
                          ? AnimeSamaImage(
                              slug: slug,
                              fallbackUrl: cover,
                              fit: BoxFit.cover,
                            )
                          : (cover != null
                              ? Image.network(cover, fit: BoxFit.cover)
                              : Container(
                                  color: colorScheme.surfaceContainerHighest)),
                      if (showNew)
                        Positioned(
                          top: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NOUV',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Informations titre & progression
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            progressLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Boutons d'actions rapides : +1 et Reprendre
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bouton +1 épisode
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: colorScheme.primary, width: 1.2),
                    ),
                    onPressed: () => _incrementEpisode(context, ref),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 14),
                        Text(
                          '1 ép',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bouton lecture
                  if (media != null)
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_fill,
                        size: 28,
                        color: colorScheme.primary,
                      ),
                      tooltip: 'Reprendre',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => resumePlayback(context, ref, media!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte en grille
class _MobileGridCard extends ConsumerWidget {
  final ListEntry entry;
  final Media? media;

  const _MobileGridCard({
    required this.entry,
    required this.media,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = (media?.title.preferred.isNotEmpty ?? false)
        ? media!.title.preferred
        : (media?.animeSamaTitle?.isNotEmpty ?? false)
            ? media!.animeSamaTitle!
            : (media?.animeSamaSlug?.isNotEmpty ?? false)
                ? media!.animeSamaSlug!
                : 'Anime #${entry.mediaId}';
    final slug = media?.animeSamaSlug ?? '';
    final cover = media?.coverUrl;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaDetailPage(
              mediaId: entry.mediaId,
              displayTitle: media?.animeSamaTitle ??
                  ((media?.title.preferred.isNotEmpty ?? false)
                      ? media!.title.preferred
                      : null),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: slug.isNotEmpty
                      ? AnimeSamaImage(
                          slug: slug,
                          fallbackUrl: cover,
                          fit: BoxFit.cover,
                        )
                      : (cover != null
                          ? Image.network(cover, fit: BoxFit.cover)
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest)),
                ),
                if (media != null)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        iconSize: 20,
                        onPressed: () => resumePlayback(context, ref, media!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
