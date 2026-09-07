library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/list_status.dart';
import '../../services/stream_resolver.dart';
import '../widgets/anime_sama_image.dart';
import '../widgets/tv_focusable.dart';
import 'media_detail_page_tv.dart';
import 'widgets/tv_genre_grid.dart';

// Provider de recherche (privé, identique à catalog_page.dart).
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

String _slugOf(AnimeSamaCatalogueItem it) =>
    it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);

class CatalogPageTv extends ConsumerStatefulWidget {
  const CatalogPageTv({super.key});

  @override
  ConsumerState<CatalogPageTv> createState() => _CatalogPageTvState();
}

class _CatalogPageTvState extends ConsumerState<CatalogPageTv> {
  String _query = '';
  String? _selectedGenre;
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

  Future<void> _openSearch() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TvSearchDialog(initialValue: _query),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _query = result;
        _selectedGenre = null;
      });
    }
  }

  Future<void> _toggleHideLibrary() async {
    final newValue = !_hideLibrary;
    setState(() => _hideLibrary = newValue);
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.catalogHideLibrary, newValue ? '1' : '0');
  }

  void _clearResults() {
    setState(() {
      _query = '';
      _selectedGenre = null;
    });
  }

  bool get _showResults => _query.isNotEmpty || _selectedGenre != null;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          // Barre supérieure
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                TvFocusable(
                  autofocus: !_showResults,
                  onPressed: _openSearch,
                  child: GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _query.isNotEmpty ? _query : 'Rechercher…',
                            style: TextStyle(
                              color: _query.isNotEmpty
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                TvFocusable(
                  onPressed: _toggleHideLibrary,
                  child: GestureDetector(
                    onTap: _toggleHideLibrary,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _hideLibrary
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color:
                            _hideLibrary ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                if (_showResults) ...[
                  const SizedBox(width: 16),
                  TvFocusable(
                    onPressed: _clearResults,
                    child: GestureDetector(
                      onTap: _clearResults,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.arrow_back, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
                if (_selectedGenre != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    _selectedGenre!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          // Corps
          Expanded(
            child: _showResults
                ? _ResultsGrid(
                    query: _query,
                    genre: _selectedGenre,
                    hideLibrary: _hideLibrary,
                  )
                : TvGenreGrid(
                    onGenreSelected: (genre) =>
                        setState(() => _selectedGenre = genre),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grille de résultats (recherche ou genre)
// ---------------------------------------------------------------------------

class _ResultsGrid extends ConsumerWidget {
  final String query;
  final String? genre;
  final bool hideLibrary;

  const _ResultsGrid({
    required this.query,
    required this.genre,
    required this.hideLibrary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AnimeSamaCatalogueItem>> resultsAsync;
    if (query.isNotEmpty) {
      resultsAsync = ref.watch(_searchResultsProvider(query));
    } else {
      resultsAsync = ref.watch(animeSamaByGenreProvider(genre!));
    }

    final statusMap = ref.watch(libraryStatusMapProvider).asData?.value ?? {};

    return resultsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Erreur : $e',
            style: const TextStyle(color: Colors.white54)),
      ),
      data: (items) {
        final filtered = hideLibrary
            ? items
                .where((it) =>
                    statusMap[animeSamaIdForSlug(_slugOf(it))] == null)
                .toList()
            : items;

        if (filtered.isEmpty) {
          return const Center(
            child: Text('Aucun résultat',
                style: TextStyle(color: Colors.white54)),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2 / 3,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final it = filtered[i];
            final slug = _slugOf(it);
            final mediaId = animeSamaIdForSlug(slug);
            final status = statusMap[mediaId];
            return _CatalogTileTv(
              item: it,
              slug: slug,
              status: status,
              autofocus: i == 0,
            );
          },
        );
      },
    );
  }
}

class _CatalogTileTv extends StatelessWidget {
  final AnimeSamaCatalogueItem item;
  final String slug;
  final ListStatus? status;
  final bool autofocus;

  const _CatalogTileTv({
    required this.item,
    required this.slug,
    required this.status,
    required this.autofocus,
  });

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailPageTv(
          mediaId: animeSamaIdForSlug(slug),
          displayTitle: item.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onPressed: () => _openDetail(context),
      child: GestureDetector(
        onTap: () => _openDetail(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimeSamaImage(slug: slug, fit: BoxFit.cover),
              // Gradient bas + titre
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              // Badge statut bibliothèque
              if (status != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _StatusBadge(status: status!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ListStatus status;
  const _StatusBadge({required this.status});

  static const _labels = {
    ListStatus.current: 'En cours',
    ListStatus.planning: 'Planifié',
    ListStatus.completed: 'Terminé',
    ListStatus.paused: 'Pause',
    ListStatus.dropped: 'Abandonné',
    ListStatus.repeating: 'Revu',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _labels[status] ?? status.name,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog de recherche TV
// ---------------------------------------------------------------------------

class _TvSearchDialog extends StatefulWidget {
  final String initialValue;
  const _TvSearchDialog({required this.initialValue});

  @override
  State<_TvSearchDialog> createState() => _TvSearchDialogState();
}

class _TvSearchDialogState extends State<_TvSearchDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechercher'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Titre de l\'anime…',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Rechercher'),
        ),
      ],
    );
  }
}
