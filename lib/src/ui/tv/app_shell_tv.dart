library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/update_models.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/update_dialog.dart';
import 'catalog_page_tv.dart';
import 'home_page_tv.dart';
import 'library_page_tv.dart';
import 'settings_page_tv.dart';

class AppShellTv extends ConsumerStatefulWidget {
  const AppShellTv({super.key});

  @override
  ConsumerState<AppShellTv> createState() => _AppShellTvState();
}

class _AppShellTvState extends ConsumerState<AppShellTv> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = false;

  final List<FocusNode> _sidebarFocusNodes =
      List.generate(4, (i) => FocusNode(debugLabel: 'tvSidebarNode_$i'));

  final List<FocusScopeNode> _pageFocusScopes =
      List.generate(4, (i) => FocusScopeNode(debugLabel: 'tvPageScope_$i'));

  bool get _isSidebarFocused => _sidebarFocusNodes.any((n) => n.hasFocus);

  @override
  void initState() {
    super.initState();

    for (final node in _sidebarFocusNodes) {
      node.addListener(_onSidebarFocusNodeChange);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        ref.read(syncServiceProvider).fullSync();
      } catch (_) {}

      final settings = ref.read(settingsRepositoryProvider);
      final autoUpdate =
          await settings.get(SettingsKeys.autoUpdate, defaultValue: '1');
      if (autoUpdate == '1' && mounted) {
        _checkForUpdateOnStartup();
      }

      // Par défaut au démarrage, donne le focus au contenu de la page d'accueil
      if (mounted) {
        _focusContent();
      }
    });
  }

  void _onSidebarFocusNodeChange() {
    final hasFocus = _isSidebarFocused;
    if (mounted && _sidebarExpanded != hasFocus) {
      setState(() => _sidebarExpanded = hasFocus);
    }
  }

  @override
  void dispose() {
    for (final node in _sidebarFocusNodes) {
      node.removeListener(_onSidebarFocusNodeChange);
      node.dispose();
    }
    for (final scope in _pageFocusScopes) {
      scope.dispose();
    }
    super.dispose();
  }

  void _focusContent() {
    setState(() => _sidebarExpanded = false);
    final scope = _pageFocusScopes[_selectedIndex];
    final last = scope.focusedChild;
    if (last != null) {
      last.requestFocus();
      return;
    }
    final firstChild = scope.traversalDescendants.firstOrNull;
    if (firstChild != null) {
      firstChild.requestFocus();
    } else {
      scope.requestFocus();
    }
  }

  void _focusSidebar() {
    setState(() => _sidebarExpanded = true);
    _sidebarFocusNodes[_selectedIndex].requestFocus();
  }

  Future<void> _checkForUpdateOnStartup() async {
    try {
      final status = await ref.read(updateCheckProvider.future);
      if (!mounted) return;
      if (status is UpdateAvailable) {
        showUpdateDialog(context, status);
      }
    } catch (_) {}
  }

  static const _navItems = [
    (icon: Icons.home_rounded, label: 'Accueil'),
    (icon: Icons.video_library_rounded, label: 'Ma Liste'),
    (icon: Icons.search_rounded, label: 'Recherche'),
    (icon: Icons.settings_rounded, label: 'Paramètres'),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(slugMigrationProvider);
    final hasNewEpisode = ref.watch(newEpisodeIdsProvider).maybeWhen(
          data: (ids) => ids.isNotEmpty,
          orElse: () => false,
        );

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return PopScope(
      canPop: _selectedIndex == 0 && _isSidebarFocused,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_isSidebarFocused) {
          // Focus est dans la page -> retour vers la sidebar
          _focusSidebar();
        } else if (_selectedIndex != 0) {
          // Déjà sur la sidebar mais sur un autre onglet -> retour vers l'onglet Accueil
          setState(() => _selectedIndex = 0);
          _sidebarFocusNodes[0].requestFocus();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            // --- BARRE LATÉRALE RÉTRACTABLE (Style Netflix / YouTube TV) ---
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: _sidebarExpanded ? 230.0 : 72.0,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0F),
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                boxShadow: _sidebarExpanded
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Logo Terebi
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/branding/logo_sombre_texte.png',
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Destinations de navigation
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _navItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = _navItems[i];
                        final isSelected = _selectedIndex == i;

                        return TvFocusable(
                          focusNode: _sidebarFocusNodes[i],
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight) {
                              _focusContent();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          onPressed: () {
                            setState(() {
                              _selectedIndex = i;
                              _sidebarExpanded = false;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _focusContent();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.22)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Badge(
                                  isLabelVisible: i == 1 && hasNewEpisode,
                                  child: Icon(
                                    item.icon,
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.white70,
                                    size: 24,
                                  ),
                                ),
                                if (_sidebarExpanded) ...[
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // --- CONTENU PRINCIPAL DE LA PAGE ACTIVE ---
            Expanded(
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    final primary = FocusManager.instance.primaryFocus;
                    final movedInside = primary?.focusInDirection(
                            TraversalDirection.left) ??
                        false;
                    if (!movedInside) {
                      // Au bord gauche extrême du contenu : retour vers la barre latérale
                      _focusSidebar();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    FocusScope(
                      node: _pageFocusScopes[0],
                      child: const HomepageTv(),
                    ),
                    FocusScope(
                      node: _pageFocusScopes[1],
                      child: const LibraryPageTv(),
                    ),
                    FocusScope(
                      node: _pageFocusScopes[2],
                      child: const CatalogPageTv(),
                    ),
                    FocusScope(
                      node: _pageFocusScopes[3],
                      child: const SettingsPageTv(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
