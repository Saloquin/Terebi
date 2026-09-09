library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../pages/calendar_page.dart';
import 'catalog_page_tv.dart';
import 'library_page_tv.dart';
import '../pages/settings_page.dart';
import '../pages/stats_page.dart';
import '../widgets/tv_focusable.dart';
import 'home_page_tv.dart';

const int _settingsIndex = 5;
const int _libraryIndex = 3;

/// Permet aux pages TV de demander le focus sur la navbar via le contexte.
class TvNavFocusRequest extends InheritedWidget {
  final VoidCallback requestNavFocus;

  const TvNavFocusRequest({
    super.key,
    required this.requestNavFocus,
    required super.child,
  });

  static TvNavFocusRequest? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvNavFocusRequest>();

  @override
  bool updateShouldNotify(TvNavFocusRequest oldWidget) =>
      requestNavFocus != oldWidget.requestNavFocus;
}

class _Destination {
  final IconData icon;
  final String label;
  final Widget page;
  const _Destination(this.icon, this.label, this.page);
}

class AppShellTv extends ConsumerStatefulWidget {
  const AppShellTv({super.key});

  @override
  ConsumerState<AppShellTv> createState() => _AppShellTvState();
}

class _AppShellTvState extends ConsumerState<AppShellTv> {
  int _index = 0;
  // FocusNode de la navbar : permet au contenu de lui rendre le focus via arrowUp
  final _navFocusScope = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = ref.read(settingsRepositoryProvider);
      final autoUpdate =
          await settings.get(SettingsKeys.autoUpdate, defaultValue: '0');
      if (autoUpdate == '1' && mounted) {
        ref.invalidate(updateCheckProvider);
      }
    });
  }

  @override
  void dispose() {
    _navFocusScope.dispose();
    super.dispose();
  }

  static const _destinations = <_Destination>[
    _Destination(Icons.home_outlined, 'Accueil', HomepageTv()),
    _Destination(Icons.search, 'Catalogue', CatalogPageTv()),
    _Destination(Icons.calendar_month_outlined, 'Calendrier', CalendarPage()),
    _Destination(Icons.video_library_outlined, 'Bibliothèque', LibraryPageTv()),
    _Destination(Icons.bar_chart, 'Stats', StatsPage()),
    _Destination(Icons.settings_outlined, 'Paramètres', SettingsPage()),
  ];

  void _onSelect(int i) {
    if (i == _index) return;
    if (_index == _settingsIndex && ref.read(settingsDirtyProvider)) {
      ref.read(settingsFlashProvider.notifier).state++;
      return;
    }
    setState(() => _index = i);
  }

  // Appelé par le contenu quand l'utilisateur appuie arrowUp depuis le haut
  void _focusNav() {
    _navFocusScope.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(slugMigrationProvider);
    final hasNewEpisode = ref.watch(newEpisodeIdsProvider).maybeWhen(
          data: (ids) => ids.isNotEmpty,
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Navbar dans son propre FocusScope — complètement indépendant du contenu
          FocusScope(
            node: _navFocusScope,
            child: _TvTopBar(
              destinations: _destinations,
              selectedIndex: _index,
              hasNewEpisode: hasNewEpisode,
              onSelect: (i) {
                _onSelect(i);
                // Après sélection d'un onglet, rendre le focus au contenu
                FocusScope.of(context).requestFocus(FocusNode());
              },
            ),
          ),
          // Contenu : écoute arrowUp depuis le sommet pour remonter à la navbar
          Expanded(
            child: TvNavFocusRequest(
              requestNavFocus: _focusNav,
              child: _TvContentArea(
                index: _index,
                destinations: _destinations,
                onRequestNavFocus: _focusNav,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zone de contenu qui intercepte arrowUp pour remonter à la navbar.
class _TvContentArea extends StatefulWidget {
  final int index;
  final List<_Destination> destinations;
  final VoidCallback onRequestNavFocus;

  const _TvContentArea({
    required this.index,
    required this.destinations,
    required this.onRequestNavFocus,
  });

  @override
  State<_TvContentArea> createState() => _TvContentAreaState();
}

class _TvContentAreaState extends State<_TvContentArea> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      // Intercepte arrowUp uniquement quand aucun descendant ne l'a consommé
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          // Si le focus est sur un élément tout en haut (pas de défilement
          // possible vers le haut), on remonte à la navbar.
          // On délègue à la page de décider via son propre onKeyEvent.
          // Ici on le laisse remonter sauf si un descendant l'a géré.
          return KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: FocusScope(
        autofocus: true,
        child: IndexedStack(
          index: widget.index,
          children: [for (final d in widget.destinations) d.page],
        ),
      ),
    );
  }
}

class _TvTopBar extends StatelessWidget {
  final List<_Destination> destinations;
  final int selectedIndex;
  final bool hasNewEpisode;
  final void Function(int) onSelect;

  const _TvTopBar({
    required this.destinations,
    required this.selectedIndex,
    required this.hasNewEpisode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.asset(
            'assets/branding/logo_sombre_texte.png',
            height: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                for (int i = 0; i < destinations.length; i++)
                  _TvTabItem(
                    icon: destinations[i].icon,
                    label: destinations[i].label,
                    selected: selectedIndex == i,
                    showBadge: i == _libraryIndex && hasNewEpisode,
                    onPressed: () => onSelect(i),
                    // Pas d'autofocus sur la navbar au démarrage — le contenu doit
                    // avoir le focus initial. L'utilisateur remonte avec arrowUp.
                    autofocus: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onPressed;
  final bool autofocus;

  const _TvTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showBadge,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: showBadge,
                child: Icon(
                  icon,
                  color: selected ? Colors.white : Colors.white38,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 2,
                width: selected ? 32.0 : 0.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
