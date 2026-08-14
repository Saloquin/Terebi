/// Page Catalogue : recherche via **anime-sama** (ce qui est réellement jouable),
/// puis fiche enrichie **AniList** au clic (retour utilisateur — hybride).
///
/// La liste des résultats vient d'anime-sama (`search`). Un clic rematch le
/// titre vers AniList (pour un `anilistId`) et ouvre la fiche détaillée. Le
/// titre affiché reste celui d'anime-sama.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/media.dart';
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

/// Résout un titre anime-sama en [Media] (image/description). Cherche d'abord
/// le cache local (par id anime-sama) ; retourne un Media minimal si absent.
/// Réutilisé par la vignette de chaque résultat.
final _mediaForTitleProvider =
    FutureProvider.family<Media, String>((ref, title) async {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final id = animeSamaIdFor(title);
  final cached = await mediaRepo.getMedia(id);
  if (cached != null) return cached;
  return Media(
    anilistId: id,
    title: MediaTitle(romaji: title),
    animeSamaTitle: title,
  );
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
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit(String value) {
    _debounce?.cancel(); // Entrée : recherche immédiate, on annule le debounce.
    setState(() => _query = value.trim());
  }

  /// Recherche à la frappe, temporisée. Chaque recherche lance un process
  /// Python : on attend une pause de saisie (600 ms) et au moins 3 caractères
  /// pour ne pas scraper sur chaque lettre.
  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 3) return; // trop court → on attend (ou l'utilisateur valide)
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted && trimmed != _query) setState(() => _query = trimmed);
    });
  }

  void _clear() {
    _debounce?.cancel();
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
            onChanged: _onChanged,
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

class _CatalogTile extends ConsumerWidget {
  final AnimeSamaCatalogueItem item;
  const _CatalogTile({required this.item});

  void _openDetail(BuildContext context) {
    // Navigation IMMÉDIATE (pas d'attente réseau) : l'identité est l'id
    // anime-sama dérivé du titre (instantané). La fiche charge l'enrichissement
    // AniList (image/description) en arrière-plan via son propre provider.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          anilistId: animeSamaIdFor(item.title),
          displayTitle: item.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(_mediaForTitleProvider(item.title));
    final coverUrl = mediaAsync.asData?.value.coverUrl;

    return ListTile(
      leading: _Thumbnail(coverUrl: coverUrl, loading: mediaAsync.isLoading),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openDetail(context),
    );
  }
}

/// Vignette poster (ratio 2/3) : image en cache/AniList si disponible, spinner
/// pendant la résolution, icône neutre sinon (anime sans image trouvée).
class _Thumbnail extends StatelessWidget {
  final String? coverUrl;
  final bool loading;
  const _Thumbnail({required this.coverUrl, required this.loading});

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
            if (coverUrl != null)
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
