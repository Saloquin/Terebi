/// Page Catalogue : recherche via **anime-sama** (ce qui est réellement jouable),
/// puis fiche enrichie **AniList** au clic (retour utilisateur — hybride).
///
/// La liste des résultats vient d'anime-sama (`search`). Un clic rematch le
/// titre vers AniList (pour un `anilistId`) et ouvre la fiche détaillée. Le
/// titre affiché reste celui d'anime-sama.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/stream_resolver.dart';
import 'media_detail_page.dart';

/// Provider de recherche anime-sama (liste jouable).
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

/// Page de recherche du catalogue.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit(String value) => setState(() => _query = value.trim());

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
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
            onSubmitted: _onSubmit,
          ),
        ),

        // --- Résultats ---
        Expanded(child: _ResultsView(query: _query)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vue résultats
// ---------------------------------------------------------------------------

class _ResultsView extends ConsumerWidget {
  final String query;
  const _ResultsView({required this.query});

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

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => _CatalogTile(item: items[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Ligne de résultat : clic → rematch AniList → fiche
// ---------------------------------------------------------------------------

class _CatalogTile extends ConsumerStatefulWidget {
  final AnimeSamaCatalogueItem item;
  const _CatalogTile({required this.item});

  @override
  ConsumerState<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends ConsumerState<_CatalogTile> {
  bool _loading = false;

  Future<void> _openDetail() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final matcher = ref.read(titleMatcherProvider);
      final media = await matcher.match(widget.item.title);
      if (media == null) {
        messenger.showSnackBar(SnackBar(
          content: Text('« ${widget.item.title} » introuvable sur AniList.'),
        ));
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaDetailPage(
            anilistId: media.anilistId,
            displayTitle: widget.item.title,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fiche indisponible : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.movie_outlined),
      title: Text(widget.item.title,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _loading ? null : _openDetail,
    );
  }
}
