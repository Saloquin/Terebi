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
import '../../services/stream_resolver.dart';
import '../pages/home_providers.dart';
import '../widgets/anime_sama_image.dart';
import '../widgets/tv_focusable.dart';
import 'media_detail_page_tv.dart';

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
  String _inputText = '';
  String _debouncedQuery = '';
  String? _selectedGenre;
  bool _hideLibrary = false;
  Timer? _debounce;

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
    super.dispose();
  }

  void _onChar(String c) {
    final next = '$_inputText$c';
    setState(() {
      _inputText = next;
      _selectedGenre = null;
    });
    _triggerDebouncedSearch(next);
  }

  void _onSpace() {
    if (_inputText.isNotEmpty && !_inputText.endsWith(' ')) {
      final next = '$_inputText ';
      setState(() => _inputText = next);
      _triggerDebouncedSearch(next);
    }
  }

  void _onBackspace() {
    if (_inputText.isNotEmpty) {
      final next = _inputText.substring(0, _inputText.length - 1);
      setState(() => _inputText = next);
      if (next.trim().isEmpty) {
        _debounce?.cancel();
        setState(() => _debouncedQuery = '');
      } else {
        _triggerDebouncedSearch(next);
      }
    }
  }

  void _onClear() {
    _debounce?.cancel();
    setState(() {
      _inputText = '';
      _debouncedQuery = '';
      _selectedGenre = null;
    });
  }

  void _triggerDebouncedSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _debouncedQuery = text.trim();
        });
      }
    });
  }

  void _onGenreSelected(String genre) {
    _debounce?.cancel();
    setState(() {
      _selectedGenre = _selectedGenre == genre ? null : genre;
      if (_selectedGenre != null) {
        _inputText = '';
        _debouncedQuery = '';
      }
    });
  }

  Future<void> _toggleHideLibrary() async {
    final newValue = !_hideLibrary;
    setState(() => _hideLibrary = newValue);
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.catalogHideLibrary, newValue ? '1' : '0');
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) {
          final ch = event.character;
          if (ch != null &&
              ch.isNotEmpty &&
              RegExp(r'^[a-zA-Z0-9]$').hasMatch(ch)) {
            _onChar(ch.toUpperCase());
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ColoredBox(
        color: Colors.black,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Colonne gauche : Clavier virtuel TV Netflix + Filtres ─────────
            SizedBox(
              width: 320,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF111114),
                  border: Border(
                    right: BorderSide(color: Colors.white12, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barre d'affichage du texte recherché
                    _TvSearchDisplay(
                      query: _inputText,
                      onClear: _onClear,
                    ),

                    // Clavier virtuel D-pad Netflix
                    _TvVirtualKeyboard(
                      onChar: _onChar,
                      onSpace: _onSpace,
                      onBackspace: _onBackspace,
                      onClear: _onClear,
                    ),

                    const SizedBox(height: 8),

                    // Bouton filtre bibliothèque
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _SidebarButton(
                        icon: _hideLibrary
                            ? Icons.visibility_off
                            : Icons.visibility,
                        label: _hideLibrary
                            ? 'Afficher déjà vus'
                            : 'Masquer déjà vus',
                        selected: false,
                        onPressed: _toggleHideLibrary,
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Divider(color: Colors.white12, height: 14),
                    ),

                    // Liste des genres
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                            child: Text(
                              'GENRES',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          for (int i = 0; i < kAnimeSamaGenres.length; i++)
                            _SidebarButton(
                              icon: _genreIcon(kAnimeSamaGenres[i]),
                              label: kAnimeSamaGenres[i],
                              selected: _selectedGenre == kAnimeSamaGenres[i],
                              autofocus: false,
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

            // ─── Panneau droit : Résultats ou Tendances ────────────────────────
            Expanded(
              child: _ResultsGrid(
                query: _debouncedQuery,
                genre: _selectedGenre,
                hideLibrary: _hideLibrary,
              ),
            ),
          ],
        ),
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
// Barre d'affichage du texte tapé (Netflix TV Search Bar)
// ---------------------------------------------------------------------------

class _TvSearchDisplay extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _TvSearchDisplay({
    required this.query,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = query.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 14, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF18181D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasQuery
              ? theme.colorScheme.primary.withValues(alpha: 0.8)
              : Colors.white12,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: hasQuery ? theme.colorScheme.primary : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: hasQuery
                ? Row(
                    children: [
                      Flexible(
                        child: Text(
                          query,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const _BlinkingCursor(),
                    ],
                  )
                : const Text(
                    'Rechercher un anime…',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
          if (hasQuery)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 18,
        margin: const EdgeInsets.only(left: 3),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clavier virtuel D-pad TV (Style Netflix)
// ---------------------------------------------------------------------------

class _TvVirtualKeyboard extends StatelessWidget {
  final void Function(String) onChar;
  final VoidCallback onSpace;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _TvVirtualKeyboard({
    required this.onChar,
    required this.onSpace,
    required this.onBackspace,
    required this.onClear,
  });

  static const List<List<String>> _rows = [
    ['A', 'B', 'C', 'D', 'E', 'F'],
    ['G', 'H', 'I', 'J', 'K', 'L'],
    ['M', 'N', 'O', 'P', 'Q', 'R'],
    ['S', 'T', 'U', 'V', 'W', 'X'],
    ['Y', 'Z', '1', '2', '3', '4'],
    ['5', '6', '7', '8', '9', '0'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int r = 0; r < _rows.length; r++) ...[
            if (r > 0) const SizedBox(height: 5),
            Row(
              children: [
                for (int c = 0; c < _rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: 5),
                  Expanded(
                    child: _TvKey(
                      label: _rows[r][c],
                      autofocus: r == 0 && c == 0,
                      onPressed: () => onChar(_rows[r][c]),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 5),
          // Ligne 7 : Touches d'action
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _TvKey(
                  label: 'ESPACE',
                  icon: Icons.space_bar_rounded,
                  onPressed: onSpace,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child: _TvKey(
                  label: 'EFFACER',
                  icon: Icons.backspace_outlined,
                  onPressed: onBackspace,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child: _TvKey(
                  label: 'VIDER',
                  icon: Icons.clear_all_rounded,
                  onPressed: onClear,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TvKey extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool autofocus;
  final VoidCallback onPressed;

  const _TvKey({
    required this.label,
    this.icon,
    this.autofocus = false,
    required this.onPressed,
  });

  @override
  State<_TvKey> createState() => _TvKeyState();
}

class _TvKeyState extends State<_TvKey> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return TvFocusable(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      scaleFactor: 1.10,
      borderRadius: BorderRadius.circular(8),
      onPressed: widget.onPressed,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hasFocus
                ? primaryColor.withValues(alpha: 0.35)
                : const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.icon != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 14,
                      color: _hasFocus ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: _hasFocus ? Colors.white : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    color: _hasFocus ? Colors.white : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
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
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.25)
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
// Modèle d'affichage de grille de catalogue
// ---------------------------------------------------------------------------

class _CatalogGridItem {
  final int mediaId;
  final String slug;
  final String title;

  const _CatalogGridItem({
    required this.mediaId,
    required this.slug,
    required this.title,
  });
}

// ---------------------------------------------------------------------------
// Grille de résultats / Tendances (Panneau droit)
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
    if (query.isNotEmpty) {
      final resultsAsync = ref.watch(_searchResultsProvider(query));
      return resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erreur : $e',
              style: const TextStyle(color: Colors.white54)),
        ),
        data: (items) {
          final gridItems = [
            for (final it in items)
              _CatalogGridItem(
                mediaId: animeSamaIdForSlug(_slugOf(it)),
                slug: _slugOf(it),
                title: it.title,
              ),
          ];
          return _buildGrid(
            context,
            ref,
            header: 'Résultats pour « $query »',
            items: gridItems,
          );
        },
      );
    } else if (genre != null) {
      final resultsAsync = ref.watch(animeSamaByGenreProvider(genre!));
      return resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erreur : $e',
              style: const TextStyle(color: Colors.white54)),
        ),
        data: (items) {
          final gridItems = [
            for (final it in items)
              _CatalogGridItem(
                mediaId: animeSamaIdForSlug(_slugOf(it)),
                slug: _slugOf(it),
                title: it.title,
              ),
          ];
          return _buildGrid(
            context,
            ref,
            header: 'Genre : $genre',
            items: gridItems,
          );
        },
      );
    } else {
      // Par défaut : Tendances & Sorties récentes (aucun écran vide !)
      final trendingAsync = ref.watch(recentlyReleasedProvider);
      return trendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erreur : $e',
              style: const TextStyle(color: Colors.white54)),
        ),
        data: (medias) {
          final gridItems = [
            for (final m in medias)
              _CatalogGridItem(
                mediaId: m.mediaId,
                slug: m.animeSamaSlug ?? '',
                title: m.animeSamaTitle ?? m.title.preferred,
              ),
          ];
          return _buildGrid(
            context,
            ref,
            header: '🔥 Tendances & Sorties récentes',
            items: gridItems,
          );
        },
      );
    }
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref, {
    required String header,
    required List<_CatalogGridItem> items,
  }) {
    final statusMap = ref.watch(libraryStatusMapProvider).asData?.value ?? {};
    final filtered = hideLibrary
        ? items.where((it) => statusMap[it.mediaId] == null).toList()
        : items;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 56, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              query.isNotEmpty
                  ? 'Aucun résultat pour « $query »'
                  : 'Aucun contenu disponible',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Text(
                header,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${filtered.length})',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2 / 3,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final it = filtered[i];
              final status = statusMap[it.mediaId];
              return _CatalogTileTv(
                mediaId: it.mediaId,
                slug: it.slug,
                title: it.title,
                status: status,
                autofocus: false,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Carte d'anime dans la grille TV
// ---------------------------------------------------------------------------

class _CatalogTileTv extends StatelessWidget {
  final int mediaId;
  final String slug;
  final String title;
  final ListStatus? status;
  final bool autofocus;

  const _CatalogTileTv({
    required this.mediaId,
    required this.slug,
    required this.title,
    required this.status,
    this.autofocus = false,
  });

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailPageTv(
          mediaId: mediaId,
          displayTitle: title,
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
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}
