/// Page Catalogue : recherche par titre via **anime-sama**, ou **parcourir** le
/// catalogue par filtres (genre, année, nombre d'épisodes) sans taper de titre.
///
/// - Recherche : la liste vient d'anime-sama (`search`), au clic on ouvre la
///   fiche (identité = id slug anime-sama).
/// - Parcourir : filtres serveur (`catalogue-filter`) quand le champ titre est
///   vide et qu'au moins un filtre est actif.
/// - Chaque résultat déjà en bibliothèque porte un badge de statut (effectif) ;
///   un toggle mémorisé permet de masquer la bibliothèque des résultats.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/catalog_genre.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart';
import '../widgets/anime_sama_image.dart';
import 'media_detail_page.dart';

/// Provider de recherche anime-sama (liste jouable) par titre.
final _searchResultsProvider =
    FutureProvider.family<List<AnimeSamaCatalogueItem>, String>(
        (ref, query) async {
  if (query.trim().isEmpty) return const [];
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  final settings = ref.watch(settingsRepositoryProvider);
  final langStr =
      await settings.get(SettingsKeys.playbackLanguage, defaultValue: 'vostfr');
  final language =
      langStr == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
  return resolver.search(query: query.trim(), language: language);
});

/// Résout un item catalogue en [Media] (image/description). Cherche d'abord
/// le cache local (par id slug anime-sama) ; retourne un Media minimal si absent.
final _mediaForItemProvider =
    FutureProvider.family<Media, ({String slug, String title})>(
        (ref, arg) async {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final id = animeSamaIdForSlug(arg.slug);
  final cached = await mediaRepo.getMedia(id);
  if (cached != null) return cached;
  return Media.fromAnimeSama(slug: arg.slug, title: arg.title);
});

/// Trie [items] selon [sort] (pur, synchrone). Le serveur ne trie pas.
List<AnimeSamaCatalogueItem> _sortItems(
    List<AnimeSamaCatalogueItem> items, CatalogSortField sort) {
  final sorted = List<AnimeSamaCatalogueItem>.from(items);
  switch (sort) {
    case CatalogSortField.titleAsc:
      sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case CatalogSortField.titleDesc:
      sorted.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
  }
  return sorted;
}

/// Slug effectif d'un item (champ slug, sinon dérivé de l'URL).
String _slugOf(AnimeSamaCatalogueItem it) =>
    it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);

/// Page de recherche / parcours du catalogue.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  // --- Filtres « parcourir » ---
  String? _selectedGenre; // null = tous les genres
  String _anneeMin = '';
  String _anneeMax = '';
  String _epsMin = '';
  String _epsMax = '';
  CatalogSortField _sort = CatalogSortField.titleAsc;

  // --- Toggle masquer biblio (chargé depuis les settings persistés) ---
  bool _hideLibrary = false;

  // --- Panneau filtres déplié ? ---
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    // Chargement du toggle « masquer biblio » depuis les settings.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = ref.read(settingsRepositoryProvider);
      final v = await settings.get(SettingsKeys.catalogHideLibrary,
          defaultValue: '0');
      if (mounted) setState(() => _hideLibrary = v == '1');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
  }

  /// Recherche à la frappe, temporisée (600 ms, min 3 caractères) : chaque
  /// recherche lance un process Python, on évite de scraper à chaque lettre.
  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      // Champ vidé/trop court : on repasse en mode parcourir/invite.
      if (trimmed.isEmpty && _query.isNotEmpty) setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted && trimmed != _query) setState(() => _query = trimmed);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  Future<void> _setHideLibrary(bool value) async {
    setState(() => _hideLibrary = value);
    final settings = ref.read(settingsRepositoryProvider);
    await settings.set(SettingsKeys.catalogHideLibrary, value ? '1' : '0');
  }

  bool get _hasActiveFilters =>
      _selectedGenre != null ||
      _anneeMin.isNotEmpty ||
      _anneeMax.isNotEmpty ||
      _epsMin.isNotEmpty ||
      _epsMax.isNotEmpty;

  void _resetFilters() {
    setState(() {
      _selectedGenre = null;
      _anneeMin = '';
      _anneeMax = '';
      _epsMin = '';
      _epsMax = '';
      _sort = CatalogSortField.titleAsc;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Barre de recherche + bouton filtres ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un anime (anime-sama)…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clear,
                            tooltip: 'Effacer',
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: _onSubmit,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: Badge(
                  isLabelVisible: _hasActiveFilters,
                  child: Icon(_filtersExpanded
                      ? Icons.filter_list_off
                      : Icons.filter_list),
                ),
                tooltip: 'Filtres',
                onPressed: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
              ),
            ],
          ),
        ),

        // --- Panneau filtres ---
        if (_filtersExpanded)
          _FiltersPanel(
            selectedGenre: _selectedGenre,
            anneeMin: _anneeMin,
            anneeMax: _anneeMax,
            epsMin: _epsMin,
            epsMax: _epsMax,
            sort: _sort,
            hideLibrary: _hideLibrary,
            hasActiveFilters: _hasActiveFilters,
            onGenreChanged: (g) => setState(() => _selectedGenre = g),
            onAnneeMinChanged: (v) => setState(() => _anneeMin = v),
            onAnneeMaxChanged: (v) => setState(() => _anneeMax = v),
            onEpsMinChanged: (v) => setState(() => _epsMin = v),
            onEpsMaxChanged: (v) => setState(() => _epsMax = v),
            onSortChanged: (s) => setState(() => _sort = s),
            onHideLibraryChanged: _setHideLibrary,
            onReset: _resetFilters,
          ),

        // --- Résultats ---
        Expanded(
          child: _ResultsView(
            query: _query,
            genre: _selectedGenre,
            anneeMin: _anneeMin,
            anneeMax: _anneeMax,
            epsMin: _epsMin,
            epsMax: _epsMax,
            sort: _sort,
            hideLibrary: _hideLibrary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Panneau de filtres
// ---------------------------------------------------------------------------

class _FiltersPanel extends StatelessWidget {
  final String? selectedGenre;
  final String anneeMin;
  final String anneeMax;
  final String epsMin;
  final String epsMax;
  final CatalogSortField sort;
  final bool hideLibrary;
  final bool hasActiveFilters;
  final ValueChanged<String?> onGenreChanged;
  final ValueChanged<String> onAnneeMinChanged;
  final ValueChanged<String> onAnneeMaxChanged;
  final ValueChanged<String> onEpsMinChanged;
  final ValueChanged<String> onEpsMaxChanged;
  final ValueChanged<CatalogSortField> onSortChanged;
  final ValueChanged<bool> onHideLibraryChanged;
  final VoidCallback onReset;

  const _FiltersPanel({
    required this.selectedGenre,
    required this.anneeMin,
    required this.anneeMax,
    required this.epsMin,
    required this.epsMax,
    required this.sort,
    required this.hideLibrary,
    required this.hasActiveFilters,
    required this.onGenreChanged,
    required this.onAnneeMinChanged,
    required this.onAnneeMaxChanged,
    required this.onEpsMinChanged,
    required this.onEpsMaxChanged,
    required this.onSortChanged,
    required this.onHideLibraryChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Genre
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      initialValue: selectedGenre,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Genre',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tous les genres'),
                        ),
                        for (final g in kAnimeSamaGenres)
                          DropdownMenuItem<String?>(value: g, child: Text(g)),
                      ],
                      onChanged: onGenreChanged,
                    ),
                  ),
                  // Année min/max
                  _NumberField(
                      label: 'Année min',
                      value: anneeMin,
                      onChanged: onAnneeMinChanged),
                  _NumberField(
                      label: 'Année max',
                      value: anneeMax,
                      onChanged: onAnneeMaxChanged),
                  // Épisodes min/max
                  _NumberField(
                      label: 'Ép. min',
                      value: epsMin,
                      onChanged: onEpsMinChanged),
                  _NumberField(
                      label: 'Ép. max',
                      value: epsMax,
                      onChanged: onEpsMaxChanged),
                  // Tri
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<CatalogSortField>(
                      initialValue: sort,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tri',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final e in kCatalogSortLabels.entries)
                          DropdownMenuItem(
                              value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (s) {
                        if (s != null) onSortChanged(s);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Switch(
                    value: hideLibrary,
                    onChanged: onHideLibraryChanged,
                  ),
                  const Text('Masquer ma bibliothèque'),
                  const Spacer(),
                  if (hasActiveFilters)
                    TextButton.icon(
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Réinitialiser'),
                      onPressed: onReset,
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

/// Petit champ numérique (année / nombre d'épisodes).
class _NumberField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _NumberField(
      {required this.label, required this.value, required this.onChanged});

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    // Sync externe (ex. Réinitialiser) sans casser la saisie en cours.
    if (widget.value != _c.text) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextField(
        controller: _c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vue résultats (3 modes : recherche / parcourir / invite)
// ---------------------------------------------------------------------------

class _ResultsView extends ConsumerWidget {
  final String query;
  final String? genre;
  final String anneeMin;
  final String anneeMax;
  final String epsMin;
  final String epsMax;
  final CatalogSortField sort;
  final bool hideLibrary;

  const _ResultsView({
    required this.query,
    required this.genre,
    required this.anneeMin,
    required this.anneeMax,
    required this.epsMin,
    required this.epsMax,
    required this.sort,
    required this.hideLibrary,
  });

  bool get _hasFilter =>
      genre != null ||
      anneeMin.isNotEmpty ||
      anneeMax.isNotEmpty ||
      epsMin.isNotEmpty ||
      epsMax.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isSearch = query.length >= 3;
    final bool isBrowse = query.isEmpty && _hasFilter;

    if (!isSearch && !isBrowse) {
      return const _EmptyPrompt();
    }

    final AsyncValue<List<AnimeSamaCatalogueItem>> resultsAsync;
    if (isSearch) {
      resultsAsync = ref.watch(_searchResultsProvider(query));
    } else {
      final criteria = (
        genre: genre ?? '',
        anneeMin: anneeMin,
        anneeMax: anneeMax,
        episodesMin: epsMin,
        episodesMax: epsMax,
      );
      resultsAsync = ref.watch(animeSamaCatalogFilterProvider(criteria));
    }

    return resultsAsync.when(
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
              Text('Erreur lors de la recherche',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                err is ResolveException ? err.message : err.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      data: (rawItems) {
        // Statut biblio de tous les animes (un seul watch) pour badges + masquage.
        final statusMap = ref.watch(libraryStatusMapProvider).maybeWhen(
              data: (m) => m,
              orElse: () => const <int, ListStatus>{},
            );

        var items = _sortItems(rawItems, sort);
        if (hideLibrary) {
          items = items
              .where((it) =>
                  !statusMap.containsKey(animeSamaIdForSlug(_slugOf(it))))
              .toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                Text(isBrowse
                    ? 'Aucun résultat pour ces filtres'
                    : 'Aucun résultat pour « $query »'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final it = items[i];
            final status = statusMap[animeSamaIdForSlug(_slugOf(it))];
            return _CatalogTile(item: it, status: status);
          },
        );
      },
    );
  }
}

/// Écran d'invite (aucune recherche ni filtre actif).
class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.white38),
            SizedBox(height: 12),
            Text(
              'Recherchez par titre, ou utilisez les filtres pour parcourir le '
              'catalogue',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ligne de résultat : clic → fiche ; badge de statut si en bibliothèque
// ---------------------------------------------------------------------------

class _CatalogTile extends ConsumerWidget {
  final AnimeSamaCatalogueItem item;

  /// Statut effectif si l'anime est en bibliothèque, sinon null.
  final ListStatus? status;

  const _CatalogTile({required this.item, this.status});

  void _openDetail(BuildContext context, String slug) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          mediaId: animeSamaIdForSlug(slug),
          displayTitle: item.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slug = _slugOf(item);
    final mediaAsync =
        ref.watch(_mediaForItemProvider((slug: slug, title: item.title)));
    final coverUrl = mediaAsync.asData?.value.coverUrl;

    return ListTile(
      leading: _Thumbnail(
          slug: slug, coverUrl: coverUrl, loading: mediaAsync.isLoading),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: status != null ? _StatusBadge(status: status!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openDetail(context, slug),
    );
  }
}

/// Badge « en bibliothèque » avec le statut effectif.
class _StatusBadge extends StatelessWidget {
  final ListStatus status;
  const _StatusBadge({required this.status});

  // Labels FR (inclut `repeating`, absent de la map de library_page).
  static const _labels = {
    ListStatus.current: 'En cours',
    ListStatus.planning: 'Planifié',
    ListStatus.completed: 'Terminé',
    ListStatus.paused: 'En pause',
    ListStatus.dropped: 'Abandonné',
    ListStatus.repeating: 'Revisionnage',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_added,
                size: 12, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(
              _labels[status] ?? status.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vignette poster (ratio 2/3) : image dérivée du slug (cascade d'extensions),
/// coverUrl du cache en fallback, spinner pendant la résolution, icône sinon.
class _Thumbnail extends StatelessWidget {
  final String slug;
  final String? coverUrl;
  final bool loading;
  const _Thumbnail(
      {required this.slug, required this.coverUrl, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 40,
        height: 60,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: theme.colorScheme.surfaceContainerHighest),
            if (slug.isNotEmpty)
              AnimeSamaImage(
                  slug: slug, fallbackUrl: coverUrl, fit: BoxFit.cover)
            else if (coverUrl != null)
              Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 18, color: Colors.white38),
                ),
              )
            else
              Center(
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.movie_outlined,
                        size: 18, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}
