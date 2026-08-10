/// Page Bibliothèque : entrées par statut avec badges de comptage et tri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/filter_sort_service.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/season_progress_repository.dart';
import '../../services/animesama_resolver.dart';
import 'media_detail_page.dart';
import 'player_page.dart';

// ---------------------------------------------------------------------------
// Providers (visibles pour les tests via import)
// ---------------------------------------------------------------------------

final countByStatusProvider =
    FutureProvider<Map<ListStatus, int>>((ref) async {
  return ref.watch(listRepositoryProvider).countByStatus();
});

final entriesByStatusProvider =
    FutureProvider.family<List<ListEntry>, ListStatus>((ref, status) async {
  return ref.watch(listRepositoryProvider).entriesByStatus(status);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

const _statusOrder = [
  ListStatus.current,
  ListStatus.planning,
  ListStatus.completed,
  ListStatus.paused,
  ListStatus.dropped,
];

const _statusLabels = {
  ListStatus.current: 'En cours',
  ListStatus.planning: 'Planifié',
  ListStatus.completed: 'Terminé',
  ListStatus.paused: 'En pause',
  ListStatus.dropped: 'Abandonné',
};

const _sortFieldLabels = {
  EntrySortField.title: 'Titre',
  EntrySortField.score: 'Score',
  EntrySortField.progress: 'Progression',
  EntrySortField.updated: 'Mis à jour',
};

/// Page de bibliothèque avec onglets par statut de liste.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tri par onglet : un réglage indépendant par statut.
  final _sortFields = {
    for (final s in _statusOrder) s: EntrySortField.updated,
  };
  final _sortDescs = {
    for (final s in _statusOrder) s: true,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusOrder.length, vsync: this);
    // Revalide les anime « Terminé » : si une nouvelle saison/épisode est dispo
    // sur anime-sama (dernier vu < total), on les repasse « En cours ».
    WidgetsBinding.instance.addPostFrameCallback((_) => _recheckCompleted());
  }

  Future<void> _recheckCompleted() async {
    try {
      await _recheckCompletedImpl();
    } catch (_) {
      // Best-effort : un recheck qui échoue ne doit jamais casser la page.
    }
  }

  Future<void> _recheckCompletedImpl() async {
    final settings = ref.read(settingsRepositoryProvider);

    // Garde 1×/jour : le recheck fait plusieurs requêtes anime-sama par anime
    // « Terminé » ; inutile de le refaire à chaque ouverture de la biblio.
    final lastRaw = await settings.get(SettingsKeys.lastCompletedRecheck);
    if (lastRaw != null) {
      final last = DateTime.tryParse(lastRaw);
      if (last != null &&
          DateTime.now().difference(last) < const Duration(days: 1)) {
        return; // déjà fait dans les dernières 24 h.
      }
    }

    final listRepo = ref.read(listRepositoryProvider);
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);

    final completed = await listRepo.entriesByStatus(ListStatus.completed);
    if (completed.isEmpty) {
      await settings.set(
          SettingsKeys.lastCompletedRecheck, DateTime.now().toIso8601String());
      return;
    }

    final AnimeSamaResolver resolver;
    try {
      resolver = await ref.read(animeSamaResolverProvider.future);
    } catch (_) {
      return; // résolveur indisponible → pas de recheck (ne marque pas la date).
    }

    var changed = false;
    for (final entry in completed) {
      try {
        final media = await mediaRepo.getMedia(entry.mediaId);
        // Titre anime-sama de référence (le titre AniList peut diverger et faire
        // échouer le scraping). Repli sur le titre préféré si non renseigné.
        final title = media?.animeSamaTitle ?? media?.title.preferred;
        if (title == null) continue;

        final seasons = await resolver.listSeasons(title: title);
        if (seasons.isEmpty) continue;
        final last = seasons.last;

        final eps = await resolver.listEpisodes(
          title: title,
          seasonIndex: last.index,
        );
        if (eps.isEmpty) continue;

        final watched =
            await seasonProgress.lastWatched(entry.mediaId, last.index);
        // Marqué « entièrement vu » (sentinelle) → l'utilisateur l'a déclaré
        // terminé : ne jamais le rétrograder automatiquement.
        if (watched >= SeasonProgressRepository.fullyWatchedSentinel) continue;
        // Compare au DERNIER numéro d'épisode réel (numérotation parfois non
        // contiguë : OAV, épisodes .5…), pas au simple compte de la liste.
        if (watched < eps.last) {
          // Il reste des épisodes non vus → l'anime n'est plus « Terminé ».
          await listRepo.upsertEntry(entry.copyWith(
            status: ListStatus.current,
            updatedAt: DateTime.now(),
          ));
          changed = true;
        }
      } catch (_) {
        // Ignore les erreurs individuelles (réseau, anime introuvable…).
      }
      // Espace les requêtes pour ne pas se faire throttle par anime-sama.
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // Mémorise la date du recheck (réussi) pour la garde 1×/jour.
    await settings.set(
        SettingsKeys.lastCompletedRecheck, DateTime.now().toIso8601String());

    if (changed && mounted) {
      ref.invalidate(countByStatusProvider);
      ref.invalidate(entriesByStatusProvider);
      // La fiche a son propre provider d'entrée : l'invalider aussi pour éviter
      // un statut incohérent entre la bibliothèque et la page de détail.
      ref.invalidate(listEntryProvider);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(countByStatusProvider);

    return Column(
      children: [
        // --- Tab bar avec badges ---
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _statusOrder.map((status) {
            final count = countsAsync.maybeWhen(
              data: (m) => m[status] ?? 0,
              orElse: () => null,
            );
            final label = _statusLabels[status] ?? status.name;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (count != null && count > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(count: count),
                  ],
                ],
              ),
            );
          }).toList(),
        ),

        // --- Barre de tri (réactive à l'onglet actif) ---
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final status = _statusOrder[_tabController.index];
            return _SortBar(
              sortField: _sortFields[status]!,
              sortDesc: _sortDescs[status]!,
              onChanged: ({required EntrySortField field, required bool desc}) {
                setState(() {
                  _sortFields[status] = field;
                  _sortDescs[status] = desc;
                });
              },
            );
          },
        ),

        // --- Contenu des onglets ---
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _statusOrder
                .map((status) => _EntriesTab(
                      status: status,
                      sortField: _sortFields[status]!,
                      sortDesc: _sortDescs[status]!,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Barre de tri
// ---------------------------------------------------------------------------

class _SortBar extends StatelessWidget {
  final EntrySortField sortField;
  final bool sortDesc;
  final void Function({required EntrySortField field, required bool desc})
      onChanged;

  const _SortBar({
    required this.sortField,
    required this.sortDesc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text('Trier :',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          for (final f in EntrySortField.values) ...[
            _SortFieldChip(
              label: _sortFieldLabels[f] ?? f.name,
              field: f,
              currentField: sortField,
              desc: sortDesc,
              onTap: () {
                if (sortField == f) {
                  onChanged(field: f, desc: !sortDesc);
                } else {
                  onChanged(field: f, desc: false);
                }
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _SortFieldChip extends StatelessWidget {
  final String label;
  final EntrySortField field;
  final EntrySortField currentField;
  final bool desc;
  final VoidCallback onTap;

  const _SortFieldChip({
    required this.label,
    required this.field,
    required this.currentField,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = field == currentField;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      avatar: isActive
          ? Icon(
              desc ? Icons.arrow_downward : Icons.arrow_upward,
              size: 14,
            )
          : null,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet pour un statut donné
// ---------------------------------------------------------------------------

class _EntriesTab extends ConsumerWidget {
  final ListStatus status;
  final EntrySortField sortField;
  final bool sortDesc;

  const _EntriesTab({
    required this.status,
    required this.sortField,
    required this.sortDesc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesByStatusProvider(status));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $err'),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                Text(
                  'Aucun anime dans « ${_statusLabels[status]} »',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        }

        // Tri : le champ "titre" nécessite un cache local de titres.
        return _SortedEntriesList(
          entries: entries,
          sortField: sortField,
          sortDesc: sortDesc,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Liste triée avec résolution des titres (pour tri par titre)
// ---------------------------------------------------------------------------

class _SortedEntriesList extends ConsumerWidget {
  final List<ListEntry> entries;
  final EntrySortField sortField;
  final bool sortDesc;

  const _SortedEntriesList({
    required this.entries,
    required this.sortField,
    required this.sortDesc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pour le tri par titre, on construit un cache des titres déjà chargés.
    // Les autres champs de tri n'ont pas besoin de Media.
    final filterService = ref.read(filterSortServiceProvider);
    final mediaRepo = ref.read(mediaRepositoryProvider);

    // Cache synchrone des titres disponibles depuis les FutureBuilder en cours.
    // On trie dès maintenant avec les titres disponibles (les non-chargés tombent
    // en fin de liste avec une chaîne vide).
    return _MediaTitleResolver(
      entries: entries,
      mediaRepo: mediaRepo,
      builder: (titleOf) {
        final sorted = filterService.sortEntries(
          entries,
          sortField,
          descending: sortDesc,
          titleOf: titleOf,
        );
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sorted.length,
          itemBuilder: (context, i) => _EntryTile(entry: sorted[i]),
        );
      },
    );
  }
}

/// Widget qui charge tous les titres des entrées en parallèle puis
/// reconstruit avec un cache titleOf complet.
class _MediaTitleResolver extends StatefulWidget {
  final List<ListEntry> entries;
  final dynamic mediaRepo; // MediaRepository
  final Widget Function(String Function(int) titleOf) builder;

  const _MediaTitleResolver({
    required this.entries,
    required this.mediaRepo,
    required this.builder,
  });

  @override
  State<_MediaTitleResolver> createState() => _MediaTitleResolverState();
}

class _MediaTitleResolverState extends State<_MediaTitleResolver> {
  final Map<int, String> _titles = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTitles();
  }

  @override
  void didUpdateWidget(_MediaTitleResolver old) {
    super.didUpdateWidget(old);
    if (old.entries != widget.entries) _loadTitles();
  }

  Future<void> _loadTitles() async {
    final ids = widget.entries.map((e) => e.mediaId).toSet();
    final results = await Future.wait(
      ids.map((id) async {
        final media = await (widget.mediaRepo as dynamic).getMedia(id) as Media?;
        return (id: id, title: media?.title.preferred ?? '');
      }),
    );
    if (mounted) {
      setState(() {
        for (final r in results) {
          _titles[r.id] = r.title;
        }
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded && _titles.isEmpty) {
      // Affichage immédiat sans titre (sera retriggé après chargement).
      return widget.builder((_) => '');
    }
    return widget.builder((id) => _titles[id] ?? '');
  }
}

// ---------------------------------------------------------------------------
// Tuile d'une entrée
// ---------------------------------------------------------------------------

class _EntryTile extends ConsumerWidget {
  final ListEntry entry;
  const _EntryTile({required this.entry});

  /// Récupère le média : d'abord le cache local, sinon AniList (client caché),
  /// puis le sauvegarde. Évite l'affichage « ID xxxxx » quand seules les
  /// entrées de liste ont été enregistrées sans leurs métadonnées.
  Future<Media?> _resolveMedia(WidgetRef ref) async {
    final repo = ref.read(mediaRepositoryProvider);
    final local = await repo.getMedia(entry.mediaId);
    if (local != null) return local;
    // Un id NÉGATIF est une identité anime-sama (pas un anilistId) : inutile —
    // et invalide — d'interroger AniList avec. On garde le fallback local.
    if (entry.mediaId <= 0) return null;
    try {
      final fetched =
          await ref.read(aniListClientProvider).mediaDetail(entry.mediaId);
      await repo.upsertMedia(fetched);
      return fetched;
    } catch (_) {
      return null; // Hors-ligne / rate-limité : on gardera le fallback ID.
    }
  }

  /// Lance le lecteur directement (sans passer par la fiche) sur l'épisode à
  /// reprendre. Tout est calculé en local (saison mémorisée + dernier vu) :
  /// aucun appel réseau, reprise en 1 clic depuis la bibliothèque.
  Future<void> _resume(BuildContext context, WidgetRef ref, Media media) async {
    final settings = ref.read(settingsRepositoryProvider);
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);

    final storedSeason =
        await settings.get(SettingsKeys.animeSamaSeasonFor(media.anilistId));
    final seasonIndex =
        (storedSeason != null ? int.tryParse(storedSeason) : null) ?? 1;
    final lastWatched =
        await seasonProgress.lastWatched(media.anilistId, seasonIndex);
    // Sentinelle « tout vu » → on ne reprend pas au-delà : on relit depuis 1.
    final startEpisode =
        lastWatched >= SeasonProgressRepository.fullyWatchedSentinel
            ? 1
            : lastWatched + 1;

    final entryForPlayer = await ref.read(listRepositoryProvider)
            .getEntry(media.anilistId) ??
        entry;

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          media: media,
          episode: startEpisode,
          entry: entryForPlayer,
          animeSamaTitle: media.animeSamaTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaFuture = _resolveMedia(ref);

    return FutureBuilder<Media?>(
      future: mediaFuture,
      builder: (context, snap) {
        final media = snap.data;
        final title = media?.title.preferred ?? 'ID ${entry.mediaId}';
        final coverUrl = media?.coverUrl;

        // Borne l'affichage : si la sentinelle « tout vu » a pu se glisser dans
        // progress, ne pas afficher « ép. 1048577 ».
        final progressLabel = entry.progress <= 0
            ? 'Pas encore commencé'
            : entry.progress >= SeasonProgressRepository.fullyWatchedSentinel
                ? 'Terminé'
                : 'Progression : ép. ${entry.progress}';

        return ListTile(
          leading: coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    coverUrl,
                    width: 40,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 40, height: 56),
                  ),
                )
              : const SizedBox(width: 40, height: 56),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            progressLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.score != null) ...[
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 2),
                Text(entry.score!.toStringAsFixed(1)),
                const SizedBox(width: 8),
              ],
              // Reprendre directement (1 clic) — visible dès que le média est
              // résolu (pour connaître le titre anime-sama).
              if (media != null)
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: 'Reprendre',
                  onPressed: () => _resume(context, ref, media),
                ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaDetailPage(
                anilistId: entry.mediaId,
                displayTitle: media?.animeSamaTitle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Badge de comptage
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
