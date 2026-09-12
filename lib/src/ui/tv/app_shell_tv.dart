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
import 'widgets/tv_focus_scope.dart';

const int _settingsIndex = 5;
const int _libraryIndex = 3;

/// Fournit le [TvFocusController] du shell aux pages TV descendantes.
class TvFocusScopeProvider extends InheritedWidget {
  final TvFocusController controller;

  const TvFocusScopeProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  static TvFocusController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TvFocusScopeProvider>()
      ?.controller;

  @override
  bool updateShouldNotify(TvFocusScopeProvider oldWidget) =>
      controller != oldWidget.controller;
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
  // Pont de focus navbar ↔ contenu (remonte/redescend le focus au D-pad).
  final _focus = TvFocusController();

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
    _focus.dispose();
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

  @override
  Widget build(BuildContext context) {
    ref.watch(slugMigrationProvider);
    final hasNewEpisode = ref.watch(newEpisodeIdsProvider).maybeWhen(
          data: (ids) => ids.isNotEmpty,
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: Colors.black,
      body: TvFocusScopeProvider(
        controller: _focus,
        child: TvFocusScope(
          controller: _focus,
          navBar: _TvTopBar(
            destinations: _destinations,
            selectedIndex: _index,
            hasNewEpisode: hasNewEpisode,
            onSelect: (i) {
              _onSelect(i);
              // Après sélection d'un onglet, rendre le focus au contenu.
              _focus.focusContent();
            },
            onArrowDown: _focus.focusContent,
          ),
          content: _TvContentArea(
            index: _index,
            destinations: _destinations,
          ),
        ),
      ),
    );
  }
}

/// Zone de contenu du shell. La remontée vers la navbar est gérée par les
/// pages (arrowUp au sommet) via [TvFocusScopeProvider].
class _TvContentArea extends StatelessWidget {
  final int index;
  final List<_Destination> destinations;

  const _TvContentArea({
    required this.index,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: [for (final d in destinations) d.page],
    );
  }
}

class _TvTopBar extends StatelessWidget {
  final List<_Destination> destinations;
  final int selectedIndex;
  final bool hasNewEpisode;
  final void Function(int) onSelect;
  final VoidCallback onArrowDown;

  const _TvTopBar({
    required this.destinations,
    required this.selectedIndex,
    required this.hasNewEpisode,
    required this.onSelect,
    required this.onArrowDown,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          onArrowDown();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
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
