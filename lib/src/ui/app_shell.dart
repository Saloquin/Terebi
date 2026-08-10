/// Shell principal de l'application : navigation latérale (desktop) entre les
/// grandes sections.
library;

import 'package:flutter/material.dart';

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

/// Shell avec `NavigationRail` (adapté desktop).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = <_Destination>[
    _Destination(Icons.home_outlined, 'Accueil', HomePage()),
    _Destination(Icons.search, 'Catalogue', CatalogPage()),
    _Destination(Icons.calendar_month_outlined, 'Calendrier', CalendarPage()),
    _Destination(Icons.video_library_outlined, 'Bibliothèque', LibraryPage()),
    _Destination(Icons.bar_chart, 'Stats', StatsPage()),
    _Destination(Icons.settings_outlined, 'Paramètres', SettingsPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('テレビ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
