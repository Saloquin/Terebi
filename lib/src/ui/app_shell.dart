/// Shell principal de l'application : navigation latérale (desktop) entre les
/// grandes sections.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'pages/calendar_page.dart';
import 'pages/catalog_page.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';

/// Une destination de navigation.
class _Destination {
  final IconData icon;
  final String label;
  final Widget page;
  const _Destination(this.icon, this.label, this.page);
}

/// Index de l'onglet Paramètres (pour le garde « modifs non sauvegardées »).
const int _settingsIndex = 5;

/// Shell avec `NavigationRail` (adapté desktop).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _destinations = <_Destination>[
    _Destination(Icons.home_outlined, 'Accueil', HomePage()),
    _Destination(Icons.search, 'Catalogue', CatalogPage()),
    _Destination(Icons.calendar_month_outlined, 'Calendrier', CalendarPage()),
    _Destination(Icons.video_library_outlined, 'Bibliothèque', LibraryPage()),
    _Destination(Icons.bar_chart, 'Stats', StatsPage()),
    _Destination(Icons.settings_outlined, 'Paramètres', SettingsPage()),
  ];

  void _onSelect(int i) {
    if (i == _index) return;
    // Garde « modifs non sauvegardées » : si on quitte les Paramètres avec des
    // changements en attente, on bloque et on fait clignoter la barre.
    if (_index == _settingsIndex && ref.read(settingsDirtyProvider)) {
      ref.read(settingsFlashProvider.notifier).state++;
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(slugMigrationProvider); // declenche la migration au 1er boot (non bloquant)
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: _onSelect,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/branding/logo_sombre_texte.png'
                    : 'assets/branding/logo_clair_texte.png',
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          // IndexedStack : toutes les pages restent montées → l'état (recherche
          // du catalogue, position de scroll, données chargées) est conservé
          // quand on change d'onglet, sans re-scraper à chaque retour.
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [for (final d in _destinations) d.page],
            ),
          ),
        ],
      ),
    );
  }
}
