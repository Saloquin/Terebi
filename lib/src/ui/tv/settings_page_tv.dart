library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/sync_service.dart';
import '../../services/update_models.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/update_dialog.dart';

class SettingsPageTv extends ConsumerStatefulWidget {
  const SettingsPageTv({super.key});

  @override
  ConsumerState<SettingsPageTv> createState() => _SettingsPageTvState();
}

class _SettingsPageTvState extends ConsumerState<SettingsPageTv> {
  String _preferredLanguage = 'vostfr';
  bool _aniSkipEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsRepositoryProvider);
    final lang = await settings.get(SettingsKeys.playbackLanguage, defaultValue: 'vostfr');
    final skip = (await settings.get(SettingsKeys.autoSkipOpening, defaultValue: '1')) == '1';
    if (mounted) {
      setState(() {
        _preferredLanguage = lang ?? 'vostfr';
        _aniSkipEnabled = skip;
      });
    }
  }

  Future<void> _saveLanguage(String lang) async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.set(SettingsKeys.playbackLanguage, lang);
    setState(() => _preferredLanguage = lang);
  }

  Future<void> _toggleAniSkip() async {
    final settings = ref.read(settingsRepositoryProvider);
    final next = !_aniSkipEnabled;
    await settings.set(SettingsKeys.autoSkipOpening, next ? '1' : '0');
    setState(() => _aniSkipEnabled = next);
  }

  Future<void> _triggerSync() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation en cours avec le Cloud Turso...'),
          duration: Duration(seconds: 2),
        ),
      );
      await syncService.fullSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronisation réussie !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de synchronisation : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final status = await ref.read(updateCheckProvider.future);
      if (!mounted) return;
      if (status is UpdateAvailable) {
        showUpdateDialog(context, status);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous utilisez déjà la dernière version de Terebi !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de vérifier les mises à jour.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final syncStatus = ref.watch(syncServiceProvider).currentStatus;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        children: [
          const Text(
            'Paramètres & Compte',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personnalisez votre expérience Terebi sur grand écran.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // --- 1. SECTION COMPTE & SYNCHRONISATION ---
          _buildSectionHeader('Compte & Synchronisation', Icons.cloud_sync_outlined),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  backgroundImage: user != null ? NetworkImage(user.avatarPngUrl) : null,
                  child: user == null ? const Icon(Icons.person, size: 32, color: Colors.white) : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user != null ? user.username : 'Non connecté (Mode Local)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user != null
                            ? (user.email ?? 'Compte Cloud synchronisé')
                            : 'Vos données sont stockées uniquement sur cet appareil.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            syncStatus.state == SyncState.synced
                                ? Icons.check_circle
                                : syncStatus.state == SyncState.syncing
                                    ? Icons.sync
                                    : Icons.cloud_off,
                            color: syncStatus.state == SyncState.synced
                                ? Colors.green
                                : syncStatus.state == SyncState.syncing
                                    ? Colors.amber
                                    : Colors.white38,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            syncStatus.state == SyncState.synced
                                ? 'Synchronisé avec Turso'
                                : syncStatus.state == SyncState.syncing
                                    ? 'Synchronisation en cours...'
                                    : 'Prêt',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TvFocusable(
                  onPressed: _triggerSync,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Synchroniser',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- 2. SECTION LECTURE & VIDÉO ---
          _buildSectionHeader('Lecture & Audio', Icons.play_circle_outline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildChoiceCard(
                  title: 'VOSTFR',
                  subtitle: 'Voix japonaises, sous-titres FR',
                  icon: Icons.subtitles,
                  selected: _preferredLanguage == 'vostfr',
                  onPressed: () => _saveLanguage('vostfr'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildChoiceCard(
                  title: 'VF',
                  subtitle: 'Version Française doublée',
                  icon: Icons.record_voice_over,
                  selected: _preferredLanguage == 'vf',
                  onPressed: () => _saveLanguage('vf'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildChoiceCard(
                  title: 'AniSkip (Openings)',
                  subtitle: _aniSkipEnabled ? 'Saut automatique activé' : 'Désactivé',
                  icon: Icons.fast_forward,
                  selected: _aniSkipEnabled,
                  onPressed: _toggleAniSkip,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // --- 3. SECTION MISES À JOUR ---
          _buildSectionHeader('Application', Icons.info_outline),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 28),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terebi v2.2.1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Application optimisée pour grand écran et télécommande.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                TvFocusable(
                  onPressed: _checkForUpdate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'Rechercher une mise à jour',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return TvFocusable(
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.2) : const Color(0xFF161618),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primaryColor : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? primaryColor : Colors.white70,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
