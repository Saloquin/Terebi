library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/catalog_genre.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/list_status.dart';
import '../../services/stream_resolver.dart';
import '../widgets/anime_sama_image.dart';
import '../widgets/tv_focusable.dart';
import 'media_detail_page_tv.dart';

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
  // Délai de debounce supprimé : la saisie passe par un dialog, pas en temps réel.
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

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openSearch() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TvSearchDialog(initialValue: _query),
    );
    if (result != null) {
      setState(() {
        _query = result;
        if (_query.isNotEmpty) _selectedGenre = null;
      });
    }
  }

  void _onGenreSelected(String genre) {
    setState(() {
      _selectedGenre = _selectedGenre == genre ? null : genre;
      if (_selectedGenre != null) _query = '';
    });
  }

  Future<void> _toggleHideLibrary() async {
    final newValue = !_hideLibrary;
    setState(() => _hideLibrary = newValue);
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.catalogHideLibrary, newValue ? '1' : '0');
  }

  bool get _showResults => _query.isNotEmpty || _selectedGenre != null;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Colonne gauche : recherche + genres ─────────────────────────
          SizedBox(
            width: 280,
            child: Focus(
              canRequestFocus: false,
              // Flèche droite depuis la colonne gauche → premier focusable du
              // panneau résultats (traversée naturelle vers la droite).
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  FocusManager.instance.primaryFocus
                      ?.focusInDirection(TraversalDirection.right);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF111111),
                  border: Border(
                    right: BorderSide(color: Colors.white12, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bouton recherche — ouvre un dialog de saisie au OK.
                    // On n'utilise pas de TextField inline car Android TV ouvre
                    // le clavier virtuel automatiquement dès qu'un TextField
                    // reçoit le focus, même sans autofocus.
                    _SidebarButton(
                      icon: Icons.search,
                      label: _query.isNotEmpty ? _query : 'Rechercher…',
                      selected: _query.isNotEmpty,
                      autofocus: false,
                      onPressed: _openSearch,
                    ),
                    // Bouton masquer/afficher bibliothèque
                    _SidebarButton(
                      icon: _hideLibrary
                          ? Icons.visibility_off
                          : Icons.visibility,
                      label: _hideLibrary
                          ? 'Afficher déjà vus'
                          : 'Masquer déjà vus',
                      selected: false,
                      onPressed: _toggleHideLibrary,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(color: Colors.white12, height: 16),
                    ),
                    // Liste des genres
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          for (int i = 0; i < kAnimeSamaGenres.length; i++)
                            _SidebarButton(
                              icon: _genreIcon(kAnimeSamaGenres[i]),
                              label: kAnimeSamaGenres[i],
                              selected: _selectedGenre == kAnimeSamaGenres[i],
                              autofocus: i == 0,
                              onPressed: () =>
                                  _onGenreSelected(kAnimeSamaGenres[i]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Panneau droit : résultats ────────────────────────────────────
          Expanded(
            child: Focus(
              canRequestFocus: false,
              // Flèche gauche depuis le bord gauche de la grille → sidebar.
              // focusInDirection tente d'abord de bouger dans la grille ; s'il
              // ne trouve rien à gauche (bord), on retourne au textfield.
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  // Tente de bouger à gauche dans la grille ; si on est sur le
                  // bord gauche, focusInDirection échoue et on laisse la
                  // traversée naturelle remonter vers la sidebar.
                  FocusManager.instance.primaryFocus
                      ?.focusInDirection(TraversalDirection.left);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: _showResults
                  ? _ResultsGrid(
                      query: _query,
                      genre: _selectedGenre,
                      hideLibrary: _hideLibrary,
                    )
                  : _EmptyPanel(),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _genreIcon(String genre) {
    const icons = <String, IconData>{
      'Action': Icons.sports_martial_arts,
      'Arts martiaux': Icons.sports_kabaddi,
      'Autre monde': Icons.public,
      'Aventure': Icons.explore,
      'Combats': Icons.sports_mma,
      'Comédie': Icons.sentiment_very_satisfied,
      'Crime': Icons.gavel,
      'Démons': Icons.whatshot,
      'Drame': Icons.theater_comedy,
      'Ecchi': Icons.favorite_border,
      'Fantastique': Icons.auto_awesome,
      'Fantasy': Icons.castle,
      'Ghibli': Icons.forest,
      'Guerre': Icons.military_tech,
      'Harem': Icons.group,
      'Historique': Icons.history_edu,
      'Horreur': Icons.nightlight,
      'Isekai': Icons.swap_horiz,
      'Josei': Icons.woman,
      'Magie': Icons.stars,
      'Mecha': Icons.precision_manufacturing,
      'Musique': Icons.music_note,
      'Mystère': Icons.search,
      'Politique': Icons.account_balance,
      'Psychologique': Icons.psychology,
      'Réincarnation': Icons.refresh,
      'Romance': Icons.favorite,
      'School Life': Icons.school,
      'Science-Fiction': Icons.rocket_launch,
      'Seinen': Icons.man,
      'Shônen': Icons.boy,
      'Slice of Life': Icons.home,
      'Sport': Icons.sports_soccer,
      'Surnaturel': Icons.blur_on,
      'Thriller': Icons.crisis_alert,
      'Tournois': Icons.emoji_events,
      'Vengeance': Icons.flash_on,
    };
    return icons[genre] ?? Icons.category;
  }
}

// ---------------------------------------------------------------------------
// Champ de recherche TV
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Dialog de saisie de recherche (clavier système Android TV)
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
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Effacer'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Rechercher'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bouton de la sidebar gauche
// ---------------------------------------------------------------------------

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.white54, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panneau vide (aucun filtre actif)
// ---------------------------------------------------------------------------

class _EmptyPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.white12),
          SizedBox(height: 16),
          Text(
            'Recherchez un titre ou choisissez un genre',
            style: TextStyle(color: Colors.white38, fontSize: 14),
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
          animeSamaSlug: slug,
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
