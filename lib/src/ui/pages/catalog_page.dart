/// Page Catalogue : recherche d'anime via AniList.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/media.dart';
import '../widgets/media_card.dart';
import 'media_detail_page.dart';

/// Provider de recherche : retourne la liste des médias pour une requête.
/// Chaîne vide → liste vide (pas de requête inutile).
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit(String value) {
    setState(() => _query = value.trim());
  }

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
        Expanded(child: _ResultsView(query: _query)),
      ],
    );
  }
}

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
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final media = items[i];
            return MediaCard(
              media: media,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MediaDetailPage(anilistId: media.anilistId),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
