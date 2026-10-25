/// Page de recherche et catalogue mobile tactile.
/// Comprend : barre de recherche instantanée, chips horizontales de genres rapides,
/// grille de posters 2/3 colonnes avec badges de bibliothèque, et panneau de filtres en BottomSheet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/catalog_genre.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/list_status.dart';
import '../../services/stream_resolver.dart';
import '../pages/media_detail_page.dart';
import '../widgets/anime_sama_image.dart';

/// Provider de recherche anime-sama dédié au mobile
final _mobileSearchProvider =
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

String _slugOf(AnimeSamaCatalogueItem it) =>
    it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);

class CatalogPageMobile extends ConsumerStatefulWidget {
  const CatalogPageMobile({super.key});

  @override
  ConsumerState<CatalogPageMobile> createState() => _CatalogPageMobileState();
}

class _CatalogPageMobileState extends ConsumerState<CatalogPageMobile> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  // Filtres
  String? _selectedGenre;
  String _anneeMin = '';
  String _anneeMax = '';
  String _epsMin = '';
  String _epsMax = '';
  CatalogSortField _sort = CatalogSortField.titleAsc;
  bool _hideLibrary = false;

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (_query.isNotEmpty) setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && trimmed != _query) {
        setState(() => _query = trimmed);
      }
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _setHideLibrary(bool val) async {
    setState(() => _hideLibrary = val);
    final settings = ref.read(settingsRepositoryProvider);
    await settings.set(SettingsKeys.catalogHideLibrary, val ? '1' : '0');
  }

  bool get _hasActiveFilters =>
      _anneeMin.isNotEmpty ||
      _anneeMax.isNotEmpty ||
      _epsMin.isNotEmpty ||
      _epsMax.isNotEmpty ||
      _sort != CatalogSortField.titleAsc ||
      _hideLibrary;

  void _openFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtres avancés',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  // Tri
                  Text('Trier par', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<CatalogSortField>(
                    segments: const [
                      ButtonSegment(
                        value: CatalogSortField.titleAsc,
                        label: Text('Titre (A → Z)'),
                      ),
                      ButtonSegment(
                        value: CatalogSortField.titleDesc,
                        label: Text('Titre (Z → A)'),
                      ),
                    ],
                    selected: {_sort},
                    onSelectionChanged: (s) {
                      setSheetState(() => _sort = s.first);
                      setState(() => _sort = s.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Toggle masquer bibliothèque
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Masquer mes animes'),
                    subtitle: const Text('N\'affiche pas les animes déjà suivis'),
                    value: _hideLibrary,
                    onChanged: (v) {
                      setSheetState(() => _hideLibrary = v);
                      _setHideLibrary(v);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              _anneeMin = '';
                              _anneeMax = '';
                              _epsMin = '';
                              _epsMax = '';
                              _sort = CatalogSortField.titleAsc;
                            });
                            setState(() {
                              _anneeMin = '';
                              _anneeMax = '';
                              _epsMin = '';
                              _epsMax = '';
                              _sort = CatalogSortField.titleAsc;
                            });
                            _setHideLibrary(false);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;
    final isBrowsing = _selectedGenre != null || _hasActiveFilters;

    return Column(
      children: [
        // --- 1. BARRE DE RECHERCHE MOBILE & FILTRES ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Rechercher un anime...',
                  leading: const Icon(Icons.search, size: 20),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: _clearSearch,
                      ),
                  ],
                  elevation: const WidgetStatePropertyAll(1),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: Badge(
                  isLabelVisible: _hasActiveFilters,
                  child: const Icon(Icons.tune_rounded),
                ),
                tooltip: 'Filtres',
                onPressed: _openFiltersBottomSheet,
              ),
            ],
          ),
        ),

        // --- 2. CHIPS DE GENRES HORIZONTALES DÉROULANTES ---
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 1 + kAnimeSamaGenres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isAll = _selectedGenre == null;
                return ChoiceChip(
                  label: const Text('Tous'),
                  selected: isAll,
                  onSelected: (_) {
                    setState(() => _selectedGenre = null);
                  },
                );
              }
              final g = kAnimeSamaGenres[index - 1];
              final isSelected = _selectedGenre == g;
              return ChoiceChip(
                label: Text(g),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedGenre = selected ? g : null);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // --- 3. CONTENU / RÉSULTATS ---
        Expanded(
          child: _buildBody(context, isSearching, isBrowsing),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isSearching, bool isBrowsing) {
    if (isSearching) {
      // Mode recherche par mots-clés
      final searchAsync = ref.watch(_mobileSearchProvider(_query));
      return searchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $err', textAlign: TextAlign.center),
          ),
        ),
        data: (items) => _buildGrid(items),
      );
    }

    if (isBrowsing) {
      // Mode filtrage par genre / critères
      final criteria = (
        genre: _selectedGenre ?? '',
        anneeMin: _anneeMin,
        anneeMax: _anneeMax,
        episodesMin: _epsMin,
        episodesMax: _epsMax,
      );
      final filterAsync = ref.watch(animeSamaCatalogFilterProvider(criteria));
      return filterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $err', textAlign: TextAlign.center),
          ),
        ),
        data: (items) => _buildGrid(items),
      );
    }

    // Aucun filtre ni recherche : invite avec suggestions
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Explorez le catalogue',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tapez un titre ou sélectionnez un genre ci-dessus pour découvrir des animes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<AnimeSamaCatalogueItem> rawItems) {
    final statusMap = ref.watch(libraryStatusMapProvider).maybeWhen(
          data: (m) => m,
          orElse: () => const <int, ListStatus>{},
        );

    var items = List<AnimeSamaCatalogueItem>.from(rawItems);
    if (_sort == CatalogSortField.titleDesc) {
      items.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    } else {
      items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    if (_hideLibrary) {
      items = items
          .where((it) => !statusMap.containsKey(animeSamaIdForSlug(_slugOf(it))))
          .toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              'Aucun résultat trouvé',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth > 520 ? 3 : 2;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final slug = _slugOf(item);
            final mediaId = animeSamaIdForSlug(slug);
            final status = statusMap[mediaId];

            return _MobileCatalogCard(
              item: item,
              slug: slug,
              status: status,
            );
          },
        );
      },
    );
  }
}

/// Carte de poster dans la grille mobile
class _MobileCatalogCard extends StatelessWidget {
  final AnimeSamaCatalogueItem item;
  final String slug;
  final ListStatus? status;

  const _MobileCatalogCard({
    required this.item,
    required this.slug,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaDetailPage(
              mediaId: animeSamaIdForSlug(slug),
              displayTitle: item.title,
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
                  child: AnimeSamaImage(
                    slug: slug,
                    fallbackUrl: item.cover,
                    fit: BoxFit.cover,
                  ),
                ),
                // Badge de statut dans ma bibliothèque
                if (status != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(colorScheme, status!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status!.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
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

  Color _statusColor(ColorScheme cs, ListStatus status) {
    switch (status) {
      case ListStatus.current:
        return Colors.green;
      case ListStatus.completed:
        return Colors.blueAccent;
      case ListStatus.planning:
        return Colors.orangeAccent;
      case ListStatus.paused:
        return Colors.purpleAccent;
      case ListStatus.dropped:
        return Colors.redAccent;
      case ListStatus.repeating:
        return Colors.teal;
    }
  }
}
