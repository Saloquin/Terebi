library;

import 'package:flutter/material.dart';
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

  final List<FocusNode> _sidebarFocusNodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
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
    });
  }

  @override
  void dispose() {
    for (final node in _sidebarFocusNodes) {
      node.dispose();
    }
    super.dispose();
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
      canPop: _selectedIndex == 0 && !_sidebarExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sidebarExpanded) {
          setState(() => _sidebarExpanded = false);
        } else if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            // --- BARRE LATÉRALE RÉTRACTABLE (Style Netflix / YouTube TV) ---
            FocusScope(
              onFocusChange: (hasNavFocus) {
                if (mounted) {
                  setState(() => _sidebarExpanded = hasNavFocus);
                }
              },
              child: AnimatedContainer(
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
                            onPressed: () {
                              setState(() {
                                _selectedIndex = i;
                                _sidebarExpanded = false;
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
                                      color: isSelected ? primaryColor : Colors.white70,
                                      size: 24,
                                    ),
                                  ),
                                  if (_sidebarExpanded) ...[
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white70,
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
            ),

            // --- CONTENU PRINCIPAL DE LA PAGE ACTIVE ---
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  HomepageTv(),
                  LibraryPageTv(),
                  CatalogPageTv(),
                  SettingsPageTv(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
