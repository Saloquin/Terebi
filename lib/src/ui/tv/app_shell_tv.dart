library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../pages/calendar_page.dart';
import '../pages/catalog_page.dart';
import '../pages/library_page.dart';
import '../pages/settings_page.dart';
import '../pages/stats_page.dart';
import '../widgets/tv_focusable.dart';
import 'home_page_tv.dart';

const int _settingsIndex = 5;
const int _libraryIndex = 3;

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

  static const _destinations = <_Destination>[
    _Destination(Icons.home_outlined, 'Accueil', HomepageTv()),
    _Destination(Icons.search, 'Catalogue', CatalogPage()),
    _Destination(Icons.calendar_month_outlined, 'Calendrier', CalendarPage()),
    _Destination(Icons.video_library_outlined, 'Bibliothèque', LibraryPage()),
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
      body: Column(
        children: [
          _TvTopBar(
            destinations: _destinations,
            selectedIndex: _index,
            hasNewEpisode: hasNewEpisode,
            onSelect: _onSelect,
          ),
          Expanded(
            child: FocusScope(
              autofocus: true,
              child: IndexedStack(
                index: _index,
                children: [for (final d in _destinations) d.page],
              ),
            ),
          ),
        ],
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
      color: Colors.black87,
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
                    autofocus: i == 0,
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
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
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
                  color: selected ? Colors.white : Colors.white54,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
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
