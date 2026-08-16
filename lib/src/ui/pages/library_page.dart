/// Page Bibliothèque : entrées par statut avec badges de comptage, tri et filtres.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/logic/effective_status_service.dart';
import '../../domain/logic/filter_sort_service.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/season_progress_repository.dart';
import '../../services/animesama_resolver.dart';
import '../widgets/anime_sama_image.dart';
import 'media_detail_page.dart';
import 'resume_helper.dart';

// ---------------------------------------------------------------------------
// Providers (visibles pour les tests via import)
// ---------------------------------------------------------------------------

final countByStatusProvider = StreamProvider<Map<ListStatus, int>>((ref) {
  final listRepo = ref.watch(listRepositoryProvider);
  final seasonProgress = ref.watch(seasonProgressRepositoryProvider);
  return listRepo.watchAllEntries().asyncMap((all) async {
    final counts = <ListStatus, int>{};
    for (final e in all) {
      final hasProgress =
          e.progress > 0 || await seasonProgress.hasAnyProgress(e.mediaId);
      final eff = effectiveStatus(entry: e, hasProgress: hasProgress);
      if (eff == null) continue;
      counts[eff] = (counts[eff] ?? 0) + 1;
    }
    return counts;
  });
});

final entriesByStatusProvider =
    StreamProvider.family<List<ListEntry>, ListStatus>((ref, status) {
  final listRepo = ref.watch(listRepositoryProvider);
  final seasonProgress = ref.watch(seasonProgressRepositoryProvider);
  return listRepo.watchAllEntries().asyncMap((all) async {
    final result = <ListEntry>[];
    for (final e in all) {
      final hasProgress =
          e.progress > 0 || await seasonProgress.hasAnyProgress(e.mediaId);
      final eff = effectiveStatus(entry: e, hasProgress: hasProgress);
      if (eff == status) result.add(e);
    }
    return result;
  });
});

/// Vrai si un anime a un « nouvel épisode disponible » (drapeau posé par le
/// recheck). Sert à afficher un badge sur sa tuile de bibliothèque.
final newEpisodeFlagProvider =
    FutureProvider.family<bool, int>((ref, mediaId) async {
  final v = await ref
      .watch(settingsRepositoryProvider)
      .get(SettingsKeys.newEpisodeFor(mediaId));
  return v == '1';
});

/// Map mediaId → Media chargée depuis le dépôt local (pour le filtrage).
/// Utilisée par _FilterBar (genres/années disponibles) et _SortedEntriesList
/// (application du filtre). Un seul appel getAllMedia() pour toute la page.
final _allMediaMapProvider = FutureProvider<Map<int, Media>>((ref) async {
  final all = await ref.watch(mediaRepositoryProvider).getAllMedia();
  return {for (final m in all) m.anilistId: m};
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

  /// Filtre courant, partagé entre tous les onglets.
  MediaFilter _filter = const MediaFilter();

  /// Recherche textuelle par titre (partagée entre onglets). Vide = pas de
  /// filtre. Comparaison insensible à la casse/accents (via normalisation).
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusOrder.length, vsync: this);
    // Au montage : d'abord fusionner d'éventuels doublons (même anime sous 2 ids
    // à cause d'un titre variable planning/catalogue), PUIS revalider les
    // « Terminé ».
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _normalizeLegacyStatuses();
      await _dedupeDoublons();
      await _recheckCompleted();
    });
  }

  /// Migration légère (one-shot par ouverture) : convertit les anciens statuts
  /// STOCKÉS `current` en `planning`. Depuis la refonte, « En cours » n'est plus
  /// stocké mais DÉRIVÉ de la progression (cf. effectiveStatus) ; une ligne
  /// héritée `current` reste correctement affichée « En cours » tant qu'il y a
  /// de la progression, mais on normalise le stockage pour éviter toute
  /// incohérence (ex. `current` sans progression = fantôme hors listes).
  Future<void> _normalizeLegacyStatuses() async {
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final all = await listRepo.getAllEntries();
      var changed = false;
      for (final e in all) {
        if (e.status == ListStatus.current) {
          await listRepo.upsertEntry(
              e.copyWith(status: ListStatus.planning, updatedAt: e.updatedAt));
          changed = true;
        }
      }
      if (changed && mounted) {
        ref.invalidate(entriesByStatusProvider);
        ref.invalidate(countByStatusProvider);
      }
    } catch (_) {/* best-effort */}
  }

  /// Fusionne les doublons de bibliothèque : deux animes dont le titre
  /// anime-sama est inclus l'un dans l'autre (ex. « Trapped in a Dating Sim »
  /// vs « …: The World of Otome Games… ») sont le MÊME anime apparu sous 2 ids.
  /// On garde l'entrée avec la plus grande progression et on supprime l'autre.
  /// One-shot best-effort : ne casse jamais la page.
  Future<void> _dedupeDoublons() async {
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final entries = await listRepo.getAllEntries();
      if (entries.length < 2) return;

      // Clé d'IDENTITÉ par mediaId : slug anime-sama en priorité (identité réelle
      // et unique), repli sur le titre normalisé EXACT. On ne fusionne QUE des
      // entrées de même identité — surtout pas par inclusion de sous-chaîne, qui
      // confondrait « Naruto » et « Naruto Shippuden » (deux animes distincts).
      final keyById = <int, String>{};
      for (final e in entries) {
        final m = await mediaRepo.getMedia(e.mediaId);
        final slug = m?.animeSamaSlug;
        if (slug != null && slug.isNotEmpty) {
          keyById[e.mediaId] = 'slug:$slug';
        } else {
          final t = m?.animeSamaTitle ?? m?.title.preferred;
          if (t != null && t.isNotEmpty) {
            keyById[e.mediaId] = 'title:${normalizeAnimeTitle(t)}';
          }
        }
      }

      var changed = false;
      // Regroupe par clé d'identité ; s'il y a >1 entrée pour la même clé, on ne
      // garde que la plus avancée et on supprime les autres.
      final byKey = <String, List<ListEntry>>{};
      for (final e in entries) {
        final k = keyById[e.mediaId];
        if (k == null) continue;
        (byKey[k] ??= []).add(e);
      }
      for (final group in byKey.values) {
        if (group.length < 2) continue;
        var keep = group.first;
        for (final e in group.skip(1)) {
          keep = _preferredEntry(keep, e);
        }
        for (final e in group) {
          if (!identical(e, keep)) {
            await listRepo.deleteEntry(e.mediaId);
            changed = true;
          }
        }
      }
      if (changed && mounted) {
        ref.invalidate(entriesByStatusProvider);
        ref.invalidate(countByStatusProvider);
      }
    } catch (_) {/* best-effort : la dédup ne doit jamais casser la biblio */}
  }

  /// Entrée à conserver entre deux doublons : la plus avancée (progress le plus
  /// haut ; à égalité, un « Terminé » prime).
  ListEntry _preferredEntry(ListEntry a, ListEntry b) {
    if (a.progress != b.progress) return a.progress > b.progress ? a : b;
    final aDone = a.status == ListStatus.completed;
    final bDone = b.status == ListStatus.completed;
    if (aDone != bDone) return aDone ? a : b;
    return a; // égalité complète : peu importe.
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
          // Il reste des épisodes non vus → retire le drapeau « Terminé »
          // (repasse `planning` ; l'effectif redevient « En cours » via la
          // progression). Pose le drapeau « nouvel épisode » pour l'afficher.
          await listRepo.upsertEntry(entry.copyWith(
            status: ListStatus.planning,
            updatedAt: DateTime.now(),
          ));
          await settings.set(SettingsKeys.newEpisodeFor(entry.mediaId), '1');
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(countByStatusProvider);
    final mediaMapAsync = ref.watch(_allMediaMapProvider);

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

        // --- Barre de recherche par titre ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Rechercher dans la bibliothèque…',
              border: const OutlineInputBorder(),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Effacer',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
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

        // --- Barre de filtres (genres, format, année) ---
        mediaMapAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (mediaMap) => _FilterBar(
            filter: _filter,
            mediaMap: mediaMap,
            onChanged: (updated) => setState(() => _filter = updated),
          ),
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
                      filter: _filter,
                      searchQuery: _searchQuery,
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
// Barre de filtres
// ---------------------------------------------------------------------------

/// Barre de filtres : format, genres (multi-sélection), année.
/// Affiche un bouton « Réinitialiser » si le filtre est non vide.
class _FilterBar extends StatelessWidget {
  final MediaFilter filter;
  final Map<int, Media> mediaMap;
  final void Function(MediaFilter updated) onChanged;

  const _FilterBar({
    required this.filter,
    required this.mediaMap,
    required this.onChanged,
  });

  // --- Données dérivées de la bibliothèque ---

  /// Genres présents dans la bibliothèque, triés alphabétiquement.
  List<String> _availableGenres() {
    final set = <String>{};
    for (final m in mediaMap.values) {
      set.addAll(m.genres);
    }
    final list = set.toList()..sort();
    return list;
  }

  // --- Handlers ---

  /// Affiche un popup de sélection multiple de genres via des FilterChip.
  void _showGenrePopup(BuildContext context) async {
    final genres = _availableGenres();
    if (genres.isEmpty) return;

    // On travaille sur une copie locale pour éviter de déclencher des rebuilds
    // à chaque clic sur un chip ; on confirme une fois la popup fermée.
    var selected = Set<String>.from(filter.genres);
    var query = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        // Dialog responsive : largeur/hauteur bornees a la taille de la fenetre
        // (evite le debordement sur petit ecran). Zone de chips scrollable.
        final media = MediaQuery.of(ctx);
        final dialogWidth = media.size.width.clamp(0.0, 520.0) - 48;
        final maxListHeight = media.size.height * 0.5;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final q = query.trim().toLowerCase();
            final visible = q.isEmpty
                ? genres
                : genres.where((g) => g.toLowerCase().contains(q)).toList();
            return AlertDialog(
              title: Text(selected.isEmpty
                  ? 'Filtrer par genre'
                  : 'Filtrer par genre (${selected.length})'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recherche de genre.
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un genre…',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setDialogState(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    // Chips scrollables, hauteur bornee.
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxListHeight),
                      child: SingleChildScrollView(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (visible.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text('Aucun genre correspondant'),
                                ),
                              for (final g in visible)
                                FilterChip(
                                  label: Text(g),
                                  selected: selected.contains(g),
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (v) {
                                    setDialogState(() {
                                      if (v) {
                                        selected = {...selected, g};
                                      } else {
                                        selected = selected.difference({g});
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => setDialogState(() => selected = {}),
                  child: const Text('Tout décocher'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Appliquer'),
                ),
              ],
            );
          },
        );
      },
    );

    // Applique la sélection finale après fermeture de la dialog.
    onChanged(MediaFilter(
      genres: selected,
      year: filter.year,
      status: filter.status,
      format: filter.format,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasGenres = filter.genres.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Text('Filtrer :', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),

          // -- Bouton GENRES -- (Format et Annee retires : plus de donnees
          //    depuis le passage 100% anime-sama.)
          FilterChip(
            label: Text(
              hasGenres
                  ? 'Genres (${filter.genres.length})'
                  : 'Genres',
            ),
            selected: hasGenres,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => _showGenrePopup(context),
          ),

          // -- Bouton RÉINITIALISER (visible si filtre non vide) --
          if (!filter.isEmpty) ...[
            const SizedBox(width: 10),
            ActionChip(
              label: const Text('Réinitialiser'),
              avatar: const Icon(Icons.clear, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(const MediaFilter()),
            ),
          ],
        ],
      ),
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
  /// Filtre courant à appliquer sur les entrées.
  final MediaFilter filter;
  /// Recherche textuelle par titre (vide = pas de filtre).
  final String searchQuery;

  const _EntriesTab({
    required this.status,
    required this.sortField,
    required this.sortDesc,
    required this.filter,
    required this.searchQuery,
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

        // Tri et filtrage : le champ "titre" nécessite un cache local de titres.
        return _SortedEntriesList(
          entries: entries,
          sortField: sortField,
          sortDesc: sortDesc,
          filter: filter,
          searchQuery: searchQuery,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Liste triée + filtrée avec résolution des titres (pour tri par titre)
// ---------------------------------------------------------------------------

class _SortedEntriesList extends ConsumerWidget {
  final List<ListEntry> entries;
  final EntrySortField sortField;
  final bool sortDesc;
  /// Filtre à appliquer sur les entrées (via la map Media du provider).
  final MediaFilter filter;
  /// Recherche textuelle par titre (vide = pas de filtre).
  final String searchQuery;

  const _SortedEntriesList({
    required this.entries,
    required this.sortField,
    required this.sortDesc,
    required this.filter,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pour le tri par titre, on construit un cache des titres déjà chargés.
    // Les autres champs de tri n'ont pas besoin de Media.
    final filterService = ref.read(filterSortServiceProvider);
    final mediaRepo = ref.read(mediaRepositoryProvider);

    // Map Media pour le filtrage (chargée par _allMediaMapProvider).
    final mediaMapAsync = ref.watch(_allMediaMapProvider);
    final mediaMap = mediaMapAsync.maybeWhen(
      data: (m) => m,
      orElse: () => const <int, Media>{},
    );

    // Filtre les entrées selon le MediaFilter courant.
    // - Si le filtre est vide : toutes les entrées passent.
    // - Sinon : une entrée passe si son Media est connu ET matches() == true.
    //   Si le Media est inconnu, on l'exclut (on ne peut pas garantir le match).
    var filteredEntries = filter.isEmpty
        ? entries
        : entries.where((e) {
            final media = mediaMap[e.mediaId];
            if (media == null) return false;
            return filter.matches(media);
          }).toList();

    // Recherche textuelle par titre (insensible casse/accents). Cherche dans le
    // titre préféré ET le titre anime-sama. Une entrée sans Media connu est
    // exclue quand une recherche est active (titre inconnu).
    final query = normalizeAnimeTitle(searchQuery);
    if (query.isNotEmpty) {
      filteredEntries = filteredEntries.where((e) {
        final media = mediaMap[e.mediaId];
        if (media == null) return false;
        final t1 = normalizeAnimeTitle(media.title.preferred);
        final t2 = normalizeAnimeTitle(media.animeSamaTitle ?? '');
        return t1.contains(query) || t2.contains(query);
      }).toList();
    }

    // Cache synchrone des titres disponibles depuis les FutureBuilder en cours.
    // On trie dès maintenant avec les titres disponibles (les non-chargés tombent
    // en fin de liste avec une chaîne vide).
    return _MediaTitleResolver(
      entries: filteredEntries,
      mediaRepo: mediaRepo,
      builder: (titleOf) {
        final sorted = filterService.sortEntries(
          filteredEntries,
          sortField,
          descending: sortDesc,
          titleOf: titleOf,
        );

        if (sorted.isEmpty && (!filter.isEmpty || query.isNotEmpty)) {
          // Aucun résultat après filtrage/recherche : message informatif.
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list_off,
                    size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                Text(
                  query.isNotEmpty
                      ? 'Aucun anime ne correspond à la recherche'
                      : 'Aucun anime ne correspond aux filtres',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200, // ~1 carte / 200px de large (adaptatif)
            childAspectRatio: 0.62, // cover 2/3 + bandeau titre/progression
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: sorted.length,
          itemBuilder: (context, i) => _EntryCard(entry: sorted[i]),
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

class _EntryCard extends ConsumerWidget {
  final ListEntry entry;
  const _EntryCard({required this.entry});

  /// Récupère le média depuis le cache local. anime-sama étant la source unique,
  /// l'enrichissement (image/synopsis) est écrit en DB par le catalog service ;
  /// ici on lit simplement le cache (null si absent -> fallback d'affichage).
  Future<Media?> _resolveMedia(WidgetRef ref) async {
    return ref.read(mediaRepositoryProvider).getMedia(entry.mediaId);
  }

  /// Lance le lecteur directement (sans passer par la fiche) sur l'épisode à
  /// reprendre — logique partagée (helper `resumePlayback`).
  Future<void> _resume(BuildContext context, WidgetRef ref, Media media) =>
      resumePlayback(context, ref, media);

  /// Retire le drapeau « nouvel épisode » (l'utilisateur a ouvert/repris
  /// l'anime → il l'a vu). Best-effort ; rafraîchit le badge.
  void _clearNewEpisodeFlag(WidgetRef ref, int mediaId) {
    ref
        .read(settingsRepositoryProvider)
        .delete(SettingsKeys.newEpisodeFor(mediaId))
        .then((_) => ref.invalidate(newEpisodeFlagProvider(mediaId)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<Media?>(
      future: _resolveMedia(ref),
      builder: (context, snap) {
        final media = snap.data;
        final title = media?.title.preferred ?? 'ID ${entry.mediaId}';
        final coverUrl = media?.coverUrl;
        final slug = media?.animeSamaSlug ?? '';

        // Label de progression. Un anime « Terminé » l'affiche toujours comme
        // tel, MÊME si entry.progress est resté à 0 (le passage en « Terminé »
        // manuel ne remplissait pas toujours progress) : on ne veut pas afficher
        // « Pas encore commencé » sur un anime marqué fini.
        final progressLabel = entry.status == ListStatus.completed
            ? 'Terminé'
            : entry.progress <= 0
                ? 'Pas encore commencé'
                : entry.progress >= SeasonProgressRepository.fullyWatchedSentinel
                    ? 'Terminé'
                    : 'Progression : ép. ${entry.progress}';

        final showNew = ref.watch(newEpisodeFlagProvider(entry.mediaId)).maybeWhen(
              data: (v) => v,
              orElse: () => false,
            );

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _clearNewEpisodeFlag(ref, entry.mediaId);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaDetailPage(
                    anilistId: entry.mediaId,
                    displayTitle: media?.animeSamaTitle,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Cover + overlays ---
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image dérivée du slug (cascade d'extensions), coverUrl en
                      // fallback ; sinon coverUrl brut ; sinon placeholder.
                      if (slug.isNotEmpty)
                        AnimeSamaImage(
                          slug: slug,
                          fallbackUrl: coverUrl,
                          fit: BoxFit.cover,
                        )
                      else if (coverUrl != null)
                        Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),

                      // Badge « nouvel épisode » (haut-gauche).
                      if (showNew)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Nouv.',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onTertiary,
                              ),
                            ),
                          ),
                        ),

                      // Note (haut-droit).
                      if (entry.score != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  entry.score!.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bouton reprise (bas-droit), dès que le média est résolu.
                      if (media != null)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.play_arrow,
                                  color: Colors.white),
                              iconSize: 20,
                              tooltip: 'Reprendre',
                              onPressed: () {
                                _clearNewEpisodeFlag(ref, entry.mediaId);
                                _resume(context, ref, media);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // --- Titre + progression ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        progressLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
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
