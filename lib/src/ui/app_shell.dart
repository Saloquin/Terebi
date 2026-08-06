/// Shell principal de l'application : navigation latérale (desktop) entre les
/// grandes sections. Les pages réelles sont branchées au fur et à mesure.
library;

import 'package:flutter/material.dart';

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
    _Destination(Icons.home_outlined, 'Accueil', _Placeholder('Accueil')),
    _Destination(Icons.search, 'Catalogue', _Placeholder('Catalogue')),
    _Destination(Icons.calendar_month_outlined, 'Planning', _Placeholder('Planning')),
    _Destination(Icons.video_library_outlined, 'Bibliothèque', _Placeholder('Bibliothèque')),
    _Destination(Icons.settings_outlined, 'Paramètres', _Placeholder('Paramètres')),
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
          Expanded(child: _destinations[_index].page),
        ],
      ),
    );
  }
}

/// Placeholder temporaire d'une section (remplacé par les vraies pages).
class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Section en construction',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
