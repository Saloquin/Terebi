/// Page de profil mobile tactile : authentification simple sans email,
/// personnalisation d'avatar DiceBear, état de synchronisation Cloud en direct,
/// statistiques rapides et hub d'accès au Classement et Paramètres.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/user_account.dart';
import '../../services/sync_service.dart';
import '../pages/leaderboard_page.dart';
import '../pages/settings_page.dart';
import '../pages/stats_page.dart';

class ProfilePageMobile extends ConsumerStatefulWidget {
  const ProfilePageMobile({super.key});

  @override
  ConsumerState<ProfilePageMobile> createState() => _ProfilePageMobileState();
}

class _ProfilePageMobileState extends ConsumerState<ProfilePageMobile> {
  // Auth Form
  int _authTabIndex = 0; // 0 = Connexion, 1 = Inscription
  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  final _regUserCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  String _regStyle = 'lorelei';
  String _regSeed = 'Thomas';
  bool _obscureLogin = true;
  bool _obscureReg = true;
  bool _isSubmitting = false;
  String? _authError;

  @override
  void dispose() {
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    _regUserCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  void _randomizeRegSeed() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    final seed = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    setState(() => _regSeed = seed);
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isSubmitting = true;
      _authError = null;
    });
    try {
      await ref.read(currentUserProvider.notifier).login(
            _loginUserCtrl.text,
            _loginPassCtrl.text,
          );
      await ref.read(syncServiceProvider).fullSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion réussie ! Vos animes sont synchronisés.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _authError = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isSubmitting = true;
      _authError = null;
    });
    try {
      await ref.read(currentUserProvider.notifier).register(
            username: _regUserCtrl.text,
            password: _regPassCtrl.text,
            avatarStyle: _regStyle,
            avatarSeed: _regSeed.isNotEmpty ? _regSeed : _regUserCtrl.text,
          );
      await ref.read(syncServiceProvider).fullSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé avec succès ! Vos animes sont synchronisés.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _authError = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openAvatarEditor(UserAccount user) {
    String currentStyle = user.avatarStyle;
    String currentSeed = user.avatarSeed;
    final seedCtrl = TextEditingController(text: currentSeed);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final avatarUrl =
                'https://api.dicebear.com/9.x/$currentStyle/png?seed=${Uri.encodeComponent(currentSeed)}';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Personnaliser mon avatar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // Aperçu
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(avatarUrl, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                  // Dropdown du style
                  DropdownButtonFormField<String>(
                    initialValue: currentStyle,
                    decoration: const InputDecoration(
                      labelText: 'Style d\'avatar',
                      border: OutlineInputBorder(),
                    ),
                    items: UserAccount.availableAvatarStyles.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => currentStyle = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Champ graine
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: seedCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Graine (Seed)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            setSheetState(() => currentSeed = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.casino_rounded),
                        tooltip: 'Générer aléatoirement',
                        onPressed: () {
                          const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
                          final rand = Random();
                          final s = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
                          seedCtrl.text = s;
                          setSheetState(() => currentSeed = s);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      await ref.read(currentUserProvider.notifier).updateProfile(
                            avatarStyle: currentStyle,
                            avatarSeed: currentSeed,
                          );
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Avatar mis à jour !')),
                        );
                      }
                    },
                    child: const Text('Enregistrer l\'avatar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (user) {
        if (user == null) {
          return _buildAuthView(context);
        }
        return _buildLoggedInView(context, user);
      },
    );
  }

  // --- 1. VUE CONNECTÉE ---
  Widget _buildLoggedInView(BuildContext context, UserAccount user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final syncService = ref.watch(syncServiceProvider);
    final syncAsync = ref.watch(syncStatusProvider);
    final status = syncAsync.value ?? syncService.currentStatus;

    final isSyncing = status.state == SyncState.syncing;
    final isPending = status.pendingQueueCount > 0;
    final countsAsync = ref.watch(countByStatusProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Carte Header Profil
          Material(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar DiceBear avec bouton d'édition
                  Stack(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          user.avatarPngUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            onTap: () => _openAvatarEditor(user),
                            child: Icon(Icons.edit, size: 14, color: colorScheme.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Pseudo et statut
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Membre depuis ${user.createdAt.year}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Carte État de Synchronisation Terebi Cloud
          Material(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    isSyncing
                        ? Icons.sync
                        : (isPending
                            ? Icons.cloud_upload_outlined
                            : Icons.cloud_done_rounded),
                    color: isPending
                        ? Colors.amberAccent
                        : Colors.greenAccent,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSyncing
                              ? 'Synchronisation en cours...'
                              : (isPending
                                  ? '${status.pendingQueueCount} modifs en attente'
                                  : 'Synchronisé avec le cloud'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dernière synchro : À l\'instant',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Synchro'),
                    onPressed: () async {
                      try {
                        await ref.read(syncServiceProvider).fullSync();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Synchronisation terminée !')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur : $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Résumé de la bibliothèque (cartes chiffrées)
          countsAsync.maybeWhen(
            data: (counts) {
              final inProgress = counts[ListStatus.current] ?? 0;
              final completed = counts[ListStatus.completed] ?? 0;
              final planning = counts[ListStatus.planning] ?? 0;

              return Row(
                children: [
                  _StatTile(
                    title: 'En cours',
                    value: '$inProgress',
                    icon: Icons.play_arrow_rounded,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _StatTile(
                    title: 'Terminés',
                    value: '$completed',
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 8),
                  _StatTile(
                    title: 'À voir',
                    value: '$planning',
                    icon: Icons.bookmark_outline_rounded,
                    color: Colors.orangeAccent,
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Hub d'actions et navigation
          Text(
            'Fonctionnalités',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                  title: const Text('Classement Communautaire'),
                  subtitle: const Text('Top membres et statistiques globales'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.bar_chart_rounded, color: colorScheme.primary),
                  title: const Text('Statistiques Détaillées'),
                  subtitle: const Text('Temps de visionnage et répartition par genre'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StatsPage()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Paramètres'),
                  subtitle: const Text('Lecture, interface, cache et mises à jour'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Déconnexion
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text(
                      'Êtes-vous sûr de vouloir vous déconnecter de votre compte Terebi ? Vos données restent sauvegardées dans le cloud.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Déconnecter'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(currentUserProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }

  // --- 2. VUE FORMULAIRE DE CONNEXION / INSCRIPTION ---
  Widget _buildAuthView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.account_circle_outlined, size: 64, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Compte Terebi',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sauvegardez vos animes dans le cloud et synchronisez-les sur tous vos appareils',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Sélecteur Connexion / Inscription
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Connexion')),
                ButtonSegment(value: 1, label: Text('Créer un compte')),
              ],
              selected: {_authTabIndex},
              onSelectionChanged: (s) {
                setState(() {
                  _authTabIndex = s.first;
                  _authError = null;
                });
              },
            ),
            const SizedBox(height: 20),

            if (_authError != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _authError!,
                  style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_authTabIndex == 0) ...[
              // FORMULAIRE DE CONNEXION
              TextField(
                controller: _loginUserCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _loginPassCtrl,
                obscureText: _obscureLogin,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureLogin ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _isSubmitting ? null : _handleLogin,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Se connecter'),
              ),
            ] else ...[
              // FORMULAIRE D'INSCRIPTION (PAS D'EMAIL, AVATAR DICEBEAR)
              TextField(
                controller: _regUserCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _regPassCtrl,
                obscureText: _obscureReg,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureReg ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureReg = !_obscureReg),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Aperçu de l'avatar et sélection de style
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      'https://api.dicebear.com/9.x/$_regStyle/png?seed=${Uri.encodeComponent(_regSeed.isNotEmpty ? _regSeed : 'User')}',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _regStyle,
                      decoration: const InputDecoration(
                        labelText: 'Style d\'avatar',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: UserAccount.availableAvatarStyles.entries.map((e) {
                        return DropdownMenuItem(value: e.key, child: Text(e.value));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _regStyle = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.casino_rounded),
                    tooltip: 'Aléatoire',
                    onPressed: _randomizeRegSeed,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _isSubmitting ? null : _handleRegister,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Créer mon compte'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Material(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
