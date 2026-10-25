/// Shell mobile dédié pour smartphone : navigation inférieure (Material 3),
/// barre supérieure compacte avec indicateur de synchronisation Turso et raccourcis.
library;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/sync_service.dart';
import '../../services/update_models.dart';
import '../pages/settings_page.dart';
import '../widgets/mini_player_overlay.dart';
import '../widgets/update_dialog.dart';
import 'calendar_page_mobile.dart';
import 'catalog_page_mobile.dart';
import 'home_page_mobile.dart';
import 'library_page_mobile.dart';
import 'profile_page_mobile.dart';

/// Provider pour naviguer entre les onglets mobiles depuis n'importe où.
final mobileNavigationIndexProvider = StateProvider<int>((ref) => 0);

class AppShellMobile extends ConsumerStatefulWidget {
  const AppShellMobile({super.key});

  @override
  ConsumerState<AppShellMobile> createState() => _AppShellMobileState();
}

class _AppShellMobileState extends ConsumerState<AppShellMobile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Déclenche la synchronisation en tâche de fond
      try {
        ref.read(syncServiceProvider).fullSync();
      } catch (_) {}

      // Vérification des mises à jour au démarrage si configuré
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

  @override
  Widget build(BuildContext context) {
    ref.watch(slugMigrationProvider);
    final currentIndex = ref.watch(mobileNavigationIndexProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final hasNewEpisode = ref.watch(newEpisodeIdsProvider).maybeWhen(
          data: (ids) => ids.isNotEmpty,
          orElse: () => false,
        );
    final theme = Theme.of(context);

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentIndex != 0) {
          ref.read(mobileNavigationIndexProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 2,
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                theme.brightness == Brightness.dark
                    ? 'assets/branding/logo_sombre_texte.png'
                    : 'assets/branding/logo_clair_texte.png',
                height: 32,
                fit: BoxFit.contain,
              ),
            ],
          ),
          actions: [
            if (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.macOS)
              IconButton(
                icon: const Icon(Icons.desktop_windows_outlined),
                tooltip: 'Passer en vue bureau',
                onPressed: () {
                  ref.read(layoutModeProvider.notifier).state =
                      LayoutMode.desktop;
                },
              ),
            // Indicateur de synchronisation Turso en direct
            _CloudSyncButton(
              isLoggedIn: currentUser != null,
            ),
            // Raccourci vers les paramètres
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Paramètres',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: currentIndex,
              children: const [
                HomePageMobile(),
                CatalogPageMobile(),
                LibraryPageMobile(),
                CalendarPageMobile(),
                ProfilePageMobile(),
              ],
            ),
            // Mini lecteur incrusté au-dessus du contenu si actif
            const MiniPlayerOverlay(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (idx) {
            ref.read(mobileNavigationIndexProvider.notifier).state = idx;
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Explorer',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: hasNewEpisode,
                child: const Icon(Icons.video_library_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: hasNewEpisode,
                child: const Icon(Icons.video_library_rounded),
              ),
              label: 'Ma Liste',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Sorties',
            ),
            NavigationDestination(
              icon: currentUser != null
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        currentUser.avatarPngUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person_outline),
                      ),
                    )
                  : const Icon(Icons.person_outline),
              selectedIcon: currentUser != null
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        currentUser.avatarPngUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person_rounded),
                      ),
                    )
                  : const Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton d'indicateur et déclenchement de la synchronisation cloud
class _CloudSyncButton extends ConsumerWidget {
  final bool isLoggedIn;

  const _CloudSyncButton({
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLoggedIn) {
      return IconButton(
        icon: const Icon(Icons.cloud_off_outlined, color: Colors.white38),
        tooltip: 'Non connecté (données locales uniquement)',
        onPressed: () {
          ref.read(mobileNavigationIndexProvider.notifier).state = 4; // Aller sur Profil
        },
      );
    }

    final syncService = ref.watch(syncServiceProvider);
    final syncAsync = ref.watch(syncStatusProvider);
    final status = syncAsync.value ?? syncService.currentStatus;

    final isSyncing = status.state == SyncState.syncing;
    final isPending = status.pendingQueueCount > 0;

    if (isSyncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(
        isPending ? Icons.cloud_upload_outlined : Icons.cloud_done_rounded,
        color: isPending ? Colors.amberAccent : Colors.greenAccent,
      ),
      tooltip: isPending
          ? '${status.pendingQueueCount} modifs en attente (cliquer pour synchroniser)'
          : 'Synchronisé avec le cloud (cliquer pour actualiser)',
      onPressed: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronisation avec le cloud...'),
            duration: Duration(seconds: 1),
          ),
        );
        try {
          await ref.read(syncServiceProvider).fullSync();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Synchronisation réussie !'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur de synchronisation : $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
    );
  }
}
