/// Page Catalogue : recherche d'anime via AniList avec filtres et tri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/filter_sort_service.dart';
import '../../domain/models/anime_format.dart';
import '../../domain/models/media.dart';
import '../widgets/media_card.dart';
import 'media_detail_page.dart';

/// Provider de recherche brute (sans filtres).
final _searchResultsProvider =
    FutureProvider.family<List<Media>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  return ref.watch(aniListClientProvider).search(query.trim());
});

/// Page de recherche du catalogue.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _controller = TextEditingController();
  String _query = '';

  // --- Filtres ---
  Set<String> _selectedGenres = const {};
  int? _selectedYear;
  AnimeFormat? _selectedFormat;

  // --- Tri ---
  MediaSortField _sortField = MediaSortField.title;
  bool _sortDesc = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit(String value) {
    setState(() {
      _query = value.trim();
      // Réinitialise les filtres à chaque nouvelle recherche.
      _selectedGenres = const {};
      _selectedYear = null;
      _selectedFormat = null;
    });
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _query = '';
      _selectedGenres = const {};
      _selectedYear = null;
      _selectedFormat = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Barre de recherche ---
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Rechercher un anime…',
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
            onSubmitted: _onSubmit,
          ),
        ),

        // --- Résultats ---
        Expanded(
          child: _ResultsView(
            query: _query,
            selectedGenres: _selectedGenres,
            selectedYear: _selectedYear,
            selectedFormat: _selectedFormat,
            sortField: _sortField,
            sortDesc: _sortDesc,
            onFilterChanged: ({
              required Set<String> genres,
              required int? year,
              required AnimeFormat? format,
            }) {
              setState(() {
                _selectedGenres = genres;
                _selectedYear = year;
                _selectedFormat = format;
              });
            },
            onSortChanged: ({
              required MediaSortField field,
              required bool desc,
            }) {
              setState(() {
                _sortField = field;
                _sortDesc = desc;
              });
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vue résultats avec barre de filtres
// ---------------------------------------------------------------------------

class _ResultsView extends ConsumerWidget {
  final String query;
  final Set<String> selectedGenres;
  final int? selectedYear;
  final AnimeFormat? selectedFormat;
  final MediaSortField sortField;
  final bool sortDesc;
  final void Function({
    required Set<String> genres,
    required int? year,
    required AnimeFormat? format,
  }) onFilterChanged;
  final void Function({
    required MediaSortField field,
    required bool desc,
  }) onSortChanged;

  const _ResultsView({
    required this.query,
    required this.selectedGenres,
    required this.selectedYear,
    required this.selectedFormat,
    required this.sortField,
    required this.sortDesc,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.white38),
            SizedBox(height: 12),
            Text('Entrez un titre pour rechercher'),
          ],
        ),
      );
    }

    final results = ref.watch(_searchResultsProvider(query));

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Erreur lors de la recherche',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(err.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                Text('Aucun résultat pour « $query »'),
              ],
            ),
          );
        }

        final filterService = ref.read(filterSortServiceProvider);
        final availableGenres = filterService.availableGenres(items);

        final filter = MediaFilter(
          genres: selectedGenres,
          year: selectedYear,
          format: selectedFormat,
        );
        final filtered = filterService.filterMedia(items, filter);
        final sorted = filterService.sortMedia(filtered, sortField,
            descending: sortDesc);

        return Column(
          children: [
            // Barre filtres + tri
            _FilterBar(
              availableGenres: availableGenres,
              selectedGenres: selectedGenres,
              selectedYear: selectedYear,
              selectedFormat: selectedFormat,
              sortField: sortField,
              sortDesc: sortDesc,
              onFilterChanged: onFilterChanged,
              onSortChanged: onSortChanged,
            ),
            // Grille
            Expanded(
              child: sorted.isEmpty
                  ? const Center(
                      child: Text('Aucun résultat avec ces filtres'))
                  : GridView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: sorted.length,
                      itemBuilder: (context, i) {
                        final media = sorted[i];
                        return MediaCard(
                          media: media,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MediaDetailPage(
                                  anilistId: media.anilistId),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Barre de filtres + tri
// ---------------------------------------------------------------------------

const _formatLabels = {
  AnimeFormat.tv: 'TV',
  AnimeFormat.tvShort: 'TV Court',
  AnimeFormat.movie: 'Film',
  AnimeFormat.special: 'Spécial',
  AnimeFormat.ova: 'OVA',
  AnimeFormat.ona: 'ONA',
  AnimeFormat.music: 'Musique',
};

const _sortFieldLabels = {
  MediaSortField.title: 'Titre',
  MediaSortField.year: 'Année',
  MediaSortField.score: 'Score',
};

class _FilterBar extends StatelessWidget {
  final List<String> availableGenres;
  final Set<String> selectedGenres;
  final int? selectedYear;
  final AnimeFormat? selectedFormat;
  final MediaSortField sortField;
  final bool sortDesc;
  final void Function({
    required Set<String> genres,
    required int? year,
    required AnimeFormat? format,
  }) onFilterChanged;
  final void Function({
    required MediaSortField field,
    required bool desc,
  }) onSortChanged;

  const _FilterBar({
    required this.availableGenres,
    required this.selectedGenres,
    required this.selectedYear,
    required this.selectedFormat,
    required this.sortField,
    required this.sortDesc,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        selectedGenres.isNotEmpty || selectedYear != null || selectedFormat != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // --- Genres ---
          _GenreFilterChip(
            availableGenres: availableGenres,
            selectedGenres: selectedGenres,
            onChanged: (genres) => onFilterChanged(
              genres: genres,
              year: selectedYear,
              format: selectedFormat,
            ),
          ),
          const SizedBox(width: 8),

          // --- Année ---
          _YearFilterChip(
            selectedYear: selectedYear,
            onChanged: (year) => onFilterChanged(
              genres: selectedGenres,
              year: year,
              format: selectedFormat,
            ),
          ),
          const SizedBox(width: 8),

          // --- Format ---
          _FormatFilterChip(
            selectedFormat: selectedFormat,
            onChanged: (format) => onFilterChanged(
              genres: selectedGenres,
              year: selectedYear,
              format: format,
            ),
          ),
          const SizedBox(width: 8),

          // --- Séparateur ---
          const VerticalDivider(width: 16, indent: 4, endIndent: 4),
          const SizedBox(width: 4),

          // --- Tri ---
          _SortChip(
            sortField: sortField,
            sortDesc: sortDesc,
            onChanged: onSortChanged,
          ),

          // --- Réinitialiser ---
          if (hasFilters) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('Réinitialiser'),
              avatar: const Icon(Icons.clear, size: 16),
              onPressed: () => onFilterChanged(
                genres: const {},
                year: null,
                format: null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Chip genres ---

class _GenreFilterChip extends StatelessWidget {
  final List<String> availableGenres;
  final Set<String> selectedGenres;
  final void Function(Set<String>) onChanged;

  const _GenreFilterChip({
    required this.availableGenres,
    required this.selectedGenres,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = selectedGenres.isEmpty
        ? 'Genres'
        : selectedGenres.length == 1
            ? selectedGenres.first
            : '${selectedGenres.length} genres';

    return FilterChip(
      label: Text(label),
      selected: selectedGenres.isNotEmpty,
      avatar: const Icon(Icons.category_outlined, size: 16),
      onSelected: (_) async {
        final result = await showDialog<Set<String>>(
          context: context,
          builder: (_) => _GenrePickerDialog(
            available: availableGenres,
            selected: selectedGenres,
          ),
        );
        if (result != null) onChanged(result);
      },
    );
  }
}

class _GenrePickerDialog extends StatefulWidget {
  final List<String> available;
  final Set<String> selected;

  const _GenrePickerDialog({required this.available, required this.selected});

  @override
  State<_GenrePickerDialog> createState() => _GenrePickerDialogState();
}

class _GenrePickerDialogState extends State<_GenrePickerDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrer par genres'),
      content: SizedBox(
        width: 300,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in widget.available)
              CheckboxListTile(
                dense: true,
                title: Text(g),
                value: _selected.contains(g),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(g);
                  } else {
                    _selected.remove(g);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const <String>{}),
          child: const Text('Réinitialiser'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, Set.of(_selected)),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

// --- Chip année ---

class _YearFilterChip extends StatelessWidget {
  final int? selectedYear;
  final void Function(int?) onChanged;

  const _YearFilterChip({required this.selectedYear, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(selectedYear != null ? '$selectedYear' : 'Année'),
      selected: selectedYear != null,
      avatar: const Icon(Icons.calendar_today_outlined, size: 16),
      onSelected: (_) async {
        final now = DateTime.now();
        final years =
            List.generate(15, (i) => now.year - i);
        final result = await showDialog<int?>(
          context: context,
          builder: (_) => SimpleDialog(
            title: const Text('Filtrer par année'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Toutes les années'),
              ),
              for (final y in years)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, y),
                  child: Text('$y'),
                ),
            ],
          ),
        );
        // result == null means dialog dismissed without selection (not "toutes")
        // We need to distinguish: use a sentinel value -1 for "reset"
        // Actually showDialog returns null on dismiss vs explicit null from pop.
        // "Toutes les années" pops with null explicitly → onChanged(null).
        // Dismiss (back) → result is null too but we treat it as no change.
        // Since we can't distinguish, we accept null = reset filter.
        if (result == null && context.mounted) {
          // User either dismissed or chose "toutes" — in both cases reset.
          onChanged(null);
        } else if (result != null) {
          onChanged(result);
        }
      },
      onDeleted: selectedYear != null ? () => onChanged(null) : null,
    );
  }
}

// --- Chip format ---

class _FormatFilterChip extends StatelessWidget {
  final AnimeFormat? selectedFormat;
  final void Function(AnimeFormat?) onChanged;

  const _FormatFilterChip(
      {required this.selectedFormat, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final label = selectedFormat != null
        ? (_formatLabels[selectedFormat] ?? selectedFormat!.name)
        : 'Format';

    return FilterChip(
      label: Text(label),
      selected: selectedFormat != null,
      avatar: const Icon(Icons.theaters_outlined, size: 16),
      onSelected: (_) async {
        final result = await showDialog<AnimeFormat?>(
          context: context,
          builder: (_) => SimpleDialog(
            title: const Text('Filtrer par format'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Tous les formats'),
              ),
              for (final f in AnimeFormat.values)
                if (f != AnimeFormat.unknown)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, f),
                    child: Text(_formatLabels[f] ?? f.name),
                  ),
            ],
          ),
        );
        onChanged(result);
      },
      onDeleted: selectedFormat != null ? () => onChanged(null) : null,
    );
  }
}

// --- Chip tri ---

class _SortChip extends StatelessWidget {
  final MediaSortField sortField;
  final bool sortDesc;
  final void Function({required MediaSortField field, required bool desc})
      onChanged;

  const _SortChip({
    required this.sortField,
    required this.sortDesc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = _sortFieldLabels[sortField] ?? sortField.name;
    return ActionChip(
      label: Text(label),
      avatar: Icon(
        sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
        size: 16,
      ),
      onPressed: () async {
        final result = await showDialog<({MediaSortField field, bool desc})?>(
          context: context,
          builder: (_) => _SortDialog(field: sortField, desc: sortDesc),
        );
        if (result != null) {
          onChanged(field: result.field, desc: result.desc);
        }
      },
    );
  }
}

class _SortDialog extends StatefulWidget {
  final MediaSortField field;
  final bool desc;
  const _SortDialog({required this.field, required this.desc});

  @override
  State<_SortDialog> createState() => _SortDialogState();
}

class _SortDialogState extends State<_SortDialog> {
  late MediaSortField _field;
  late bool _desc;

  @override
  void initState() {
    super.initState();
    _field = widget.field;
    _desc = widget.desc;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trier par'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<MediaSortField>(
            groupValue: _field,
            onChanged: (v) => setState(() => _field = v!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in MediaSortField.values)
                  RadioListTile<MediaSortField>(
                    dense: true,
                    title: Text(_sortFieldLabels[f] ?? f.name),
                    value: f,
                  ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            dense: true,
            title: const Text('Ordre décroissant'),
            value: _desc,
            onChanged: (v) => setState(() => _desc = v),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, (field: _field, desc: _desc)),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}
