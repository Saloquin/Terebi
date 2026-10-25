/// Shell principal de l'application : navigation latérale (desktop) entre les
/// grandes sections.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/update_models.dart';
import 'pages/calendar_page.dart';
import 'pages/catalog_page.dart';
import 'pages/home_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/library_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'tv/app_shell_tv.dart';
import 'widgets/update_dialog.dart';

/// Provider global pour contrôler l'onglet actif depuis n'importe où dans l'application.
final appNavigationIndexProvider = StateProvider<int>((ref) => 0);

/// Une destination de navigation.
class _Destination {
  final IconData icon;
  final String label;
  final Widget page;
  const _Destination(this.icon, this.label, this.page);
}

/// Index de l'onglet Bibliothèque (pour la pastille « nouvel épisode »).
const int tabLibrary = 3;

/// Index de l'onglet Stats.
const int tabStats = 4;

/// Index de l'onglet Classement.
const int tabLeaderboard = 5;

/// Index de l'onglet Profil.
const int tabProfile = 6;

/// Index de l'onglet Paramètres (pour le garde « modifs non sauvegardées »).
const int tabSettings = 7;

/// Shell avec `NavigationRail` (adapté desktop).
class AppShellDesktop extends ConsumerStatefulWidget {
  const AppShellDesktop({super.key});

  @override
  ConsumerState<AppShellDesktop> createState() => _AppShellDesktopState();
}

class _AppShellDesktopState extends ConsumerState<AppShellDesktop> {

  @override
  void initState() {
    super.initState();
    // Vérifie les mises à jour au démarrage si le toggle auto-update est activé.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Déclenche la synchronisation bidirectionnelle intelligente en tâche de fond
      try {
        ref.read(syncServiceProvider).fullSync();
      } catch (_) {}

      final settings = ref.read(settingsRepositoryProvider);
      final autoUpdate =
          await settings.get(SettingsKeys.autoUpdate, defaultValue: '1');
      if (autoUpdate == '1' && mounted) {
        _checkForUpdateOnStartup();
      }
    });
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

  static const _destinations = <_Destination>[
    _Destination(Icons.home_outlined, 'Accueil', HomePage()),
    _Destination(Icons.search, 'Catalogue', CatalogPage()),
    _Destination(Icons.calendar_month_outlined, 'Calendrier', CalendarPage()),
    _Destination(Icons.video_library_outlined, 'Bibliothèque', LibraryPage()),
    _Destination(Icons.bar_chart, 'Stats', StatsPage()),
    _Destination(Icons.emoji_events_outlined, 'Classement', LeaderboardPage()),
    _Destination(Icons.person_outline, 'Profil', ProfilePage()),
    _Destination(Icons.settings_outlined, 'Paramètres', SettingsPage()),
  ];

  void _onSelect(int i) {
    final currentIndex = ref.read(appNavigationIndexProvider);
    if (i == currentIndex) return;
    // Garde « modifs non sauvegardées » : si on quitte les Paramètres avec des
    // changements en attente, on bloque et on fait clignoter la barre.
    if (currentIndex == tabSettings && ref.read(settingsDirtyProvider)) {
      ref.read(settingsFlashProvider.notifier).state++;
      return;
    }
    ref.read(appNavigationIndexProvider.notifier).state = i;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(slugMigrationProvider); // declenche la migration au 1er boot (non bloquant)
    final index = ref.watch(appNavigationIndexProvider);
    // Pastille « nouvel episode » sur l'onglet Bibliotheque si au moins un
    // anime a le drapeau (reactif via le stream des cles new_episode:*).
    final hasNewEpisode = ref.watch(newEpisodeIdsProvider).maybeWhen(
          data: (ids) => ids.isNotEmpty,
          orElse: () => false,
        );
    // Sur Android TV, le focus doit démarrer dans le contenu et non dans le
    // NavigationRail — on isole les deux zones via FocusTraversalGroup/FocusScope.
    final isTv = ref.watch(isTvProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    return Scaffold(
      body: Row(
        children: [
          // Isole la navigation latérale dans son propre groupe de traversée,
          // afin que la télécommande TV ne s'y retrouve pas piégée au démarrage.
          // descendantsAreFocusable:false sur TV exclut la rail de la traversée
          // D-pad (reste accessible à la souris via onDestinationSelected).
          FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            descendantsAreFocusable: !isTv,
            child: NavigationRail(
              selectedIndex: index,
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
                for (int i = 0; i < _destinations.length; i++)
                  NavigationRailDestination(
                    icon: i == tabLibrary
                        ? Badge(
                            isLabelVisible: hasNewEpisode,
                            child: Icon(_destinations[i].icon),
                          )
                        : (i == tabProfile && currentUser != null
                            ? Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  currentUser.avatarPngUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(_destinations[i].icon),
                                ),
                              )
                            : Icon(_destinations[i].icon)),
                    label: Text(_destinations[i].label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // IndexedStack : toutes les pages restent montées → l'état (recherche
          // du catalogue, position de scroll, données chargées) est conservé
          // quand on change d'onglet, sans re-scraper à chaque retour.
          // Sur TV, autofocus=true garantit que le focus initial tombe ici et
          // non dans le NavigationRail.
          Expanded(
            child: FocusScope(
              autofocus: isTv,
              child: IndexedStack(
                index: index,
                children: [for (final d in _destinations) d.page],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Point d'entrée unique : route vers le bon shell selon la plateforme.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(appPlatformProvider)) {
      AppPlatform.tv      => const AppShellTv(),
      AppPlatform.mobile  => const AppShellDesktop(),
      AppPlatform.desktop => const AppShellDesktop(),
    };
  }
}
