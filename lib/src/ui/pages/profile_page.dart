/// Page de profil utilisateur avec personnalisation d'avatar DiceBear en direct,
/// statistiques de compte et gestion de la session.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/turso_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/user_account.dart';
import '../../app/providers.dart';
import '../../services/sync_service.dart';
import '../app_shell.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // Mode formulaire auth si non connecté (0 = login, 1 = register)
  int _authTabIndex = 0;
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regUsernameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  String _regSelectedStyle = 'lorelei';
  String _regSeed = '';

  bool _obscureLoginPwd = true;
  bool _obscureRegPwd = true;
  bool _isSubmitting = false;
  String? _authError;

  // Édition de profil (quand connecté)
  bool _isEditingAvatar = false;
  late String _selectedStyle;
  late String _currentSeed;
  final _seedController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _selectedStyle = 'lorelei';
    _currentSeed = 'Thomas';
    _seedController.text = _currentSeed;
  }

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _regUsernameController.dispose();
    _regPasswordController.dispose();
    _seedController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _randomizeSeed() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    final randomSeed = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    setState(() {
      _currentSeed = randomSeed;
      _seedController.text = randomSeed;
    });
  }

  void _randomizeRegSeed() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    final randomSeed = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    setState(() {
      _regSeed = randomSeed;
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isSubmitting = true;
      _authError = null;
    });
    try {
      await ref.read(currentUserProvider.notifier).login(
            _loginUsernameController.text,
            _loginPasswordController.text,
          );
      // Synchronisation automatique et immédiate de tous les animes
      await ref.read(syncServiceProvider).fullSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion réussie ! Vos animes sont synchronisés.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _authError = e is TursoException ? e.message : e.toString();
        });
      }
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
      final username = _regUsernameController.text.trim();
      final seed = _regSeed.isNotEmpty ? _regSeed : username;
      await ref.read(currentUserProvider.notifier).register(
            username: username,
            password: _regPasswordController.text,
            avatarStyle: _regSelectedStyle,
            avatarSeed: seed,
          );
      // Synchronisation automatique et immédiate de tous les animes locaux vers le compte
      await ref.read(syncServiceProvider).fullSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé ! Vos animes ont été synchronisés automatiquement.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _authError = e is TursoException ? e.message : e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveAvatar(UserAccount user) async {
    setState(() => _isSavingProfile = true);
    try {
      await ref.read(currentUserProvider.notifier).updateProfile(
            avatarStyle: _selectedStyle,
            avatarSeed: _seedController.text.trim().isNotEmpty
                ? _seedController.text.trim()
                : user.username,
            bio: _bioController.text.trim(),
          );
      if (mounted) {
        setState(() => _isEditingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _showChangeUsernameDialog(UserAccount user) {
    final usernameController = TextEditingController(text: user.username);
    String? errorMsg;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier mon nom d\'utilisateur'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null) ...[
                      Text(errorMsg!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau pseudo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setDialogState(() {
                            isLoading = true;
                            errorMsg = null;
                          });
                          try {
                            await ref.read(currentUserProvider.notifier).updateProfile(
                                  username: usernameController.text.trim(),
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nom d\'utilisateur mis à jour !')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorMsg = e is TursoException ? e.message : e.toString();
                              isLoading = false;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangePasswordDialog(UserAccount user) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    String? errorMsg;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier le mot de passe'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null) ...[
                      Text(errorMsg!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: oldController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setDialogState(() {
                            isLoading = true;
                            errorMsg = null;
                          });
                          try {
                            await ref.read(authRepositoryProvider).changePassword(
                                  userId: user.id,
                                  oldPassword: oldController.text,
                                  newPassword: newController.text,
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Mot de passe modifié avec succès !')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorMsg = e is TursoException ? e.message : e.toString();
                              isLoading = false;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Tes données en ligne sur Turso restent sauvegardées. '
          'Tu pourras te reconnecter à tout moment.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(currentUserProvider.notifier).logout();
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Erreur de synchronisation avec Turso: $e', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(currentUserProvider.notifier).init(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
      data: (user) {
        if (user == null) {
          return _buildAuthView(context);
        }
        return _buildProfileView(context, user);
      },
    );
  }

  /// Vue lorsque l'utilisateur n'est pas encore connecté.
  Widget _buildAuthView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_sync_outlined, size: 36, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Terebi Cloud',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Synchronise tes listes, tes épisodes vus et ton historique sur tous tes appareils via Turso.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sélecteur Onglet Connexion / Inscription
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Connexion'), icon: Icon(Icons.login)),
                      ButtonSegment(value: 1, label: Text('Créer un compte'), icon: Icon(Icons.person_add_outlined)),
                    ],
                    selected: {_authTabIndex},
                    onSelectionChanged: (s) => setState(() {
                      _authTabIndex = s.first;
                      _authError = null;
                    }),
                  ),
                  const SizedBox(height: 20),

                  if (_authError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _authError!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_authTabIndex == 0) ...[
                    // --- Formulaire de connexion ---
                    TextField(
                      controller: _loginUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Pseudo',
                        prefixIcon: Icon(Icons.person),
                        hintText: 'Ex: Thomas',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _loginPasswordController,
                      obscureText: _obscureLoginPwd,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureLoginPwd ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureLoginPwd = !_obscureLoginPwd),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _handleLogin,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Se connecter'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ] else ...[
                    // --- Formulaire d'inscription ---
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colorScheme.primary, width: 2),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              'https://api.dicebear.com/9.x/$_regSelectedStyle/png?seed=${Uri.encodeComponent(_regSeed.isNotEmpty ? _regSeed : (_regUsernameController.text.isNotEmpty ? _regUsernameController.text : "new"))}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
                            ),
                          ),
                          IconButton.filledTonal(
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.casino),
                            tooltip: 'Graine aléatoire',
                            onPressed: _randomizeRegSeed,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _regUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Pseudo unique',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _regPasswordController,
                      obscureText: _obscureRegPwd,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe (min 4 car.)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureRegPwd ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureRegPwd = !_obscureRegPwd),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Style d\'avatar DiceBear',
                        prefixIcon: Icon(Icons.palette_outlined),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _regSelectedStyle,
                          isExpanded: true,
                          items: UserAccount.availableAvatarStyles.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _regSelectedStyle = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _handleRegister,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: const Text('Créer mon compte'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Vue lorsque l'utilisateur est connecté.
  Widget _buildProfileView(BuildContext context, UserAccount user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statsAsync = ref.watch(currentUserStatsProvider);

    if (!_isEditingAvatar) {
      _selectedStyle = user.avatarStyle;
      _currentSeed = user.avatarSeed;
      _seedController.text = _currentSeed;
      _bioController.text = user.bio;
    }

    final avatarUrl = _isEditingAvatar
        ? 'https://api.dicebear.com/9.x/$_selectedStyle/png?seed=${Uri.encodeComponent(_currentSeed)}'
        : user.avatarPngUrl;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- CARTE D'EN-TÊTE PROFIL ---
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar DiceBear avec halo
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.surfaceContainerHighest,
                                border: Border.all(color: colorScheme.primary, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 54),
                              ),
                            ),
                            IconButton.filled(
                              icon: Icon(_isEditingAvatar ? Icons.close : Icons.edit, size: 18),
                              tooltip: _isEditingAvatar ? 'Annuler' : 'Changer de photo de profil',
                              onPressed: () {
                                setState(() {
                                  _isEditingAvatar = !_isEditingAvatar;
                                  if (!_isEditingAvatar) {
                                    _selectedStyle = user.avatarStyle;
                                    _currentSeed = user.avatarSeed;
                                    _seedController.text = _currentSeed;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        // Pseudo, bio et statut
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.username,
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    tooltip: 'Modifier mon pseudo',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _showChangeUsernameDialog(user),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Turso Cloud',
                                      style: TextStyle(
                                        color: colorScheme.onPrimaryContainer,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user.bio.isNotEmpty ? user.bio : 'Membre passionné d\'anime sur Terebi',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Compte créé le ${user.createdAt.day.toString().padLeft(2, '0')}/${user.createdAt.month.toString().padLeft(2, '0')}/${user.createdAt.year}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- PERSONNALISATION DICEBEAR (Quand activé) ---
                if (_isEditingAvatar) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.palette_outlined, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Personnaliser l\'avatar DiceBear',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('1. Style artistique DiceBear :', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Choisir un style artistique',
                              prefixIcon: Icon(Icons.palette_outlined),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedStyle,
                                isExpanded: true,
                                items: UserAccount.availableAvatarStyles.entries.map((e) {
                                  return DropdownMenuItem<String>(
                                    value: e.key,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: colorScheme.outlineVariant),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Image.network(
                                            'https://api.dicebear.com/9.x/${e.key}/png?seed=${Uri.encodeComponent(_currentSeed.isNotEmpty ? _currentSeed : "seed")}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16),
                                          ),
                                        ),
                                        Expanded(child: Text(e.value)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedStyle = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: UserAccount.availableAvatarStyles.entries.map((e) {
                                final isSelected = _selectedStyle == e.key;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    avatar: Container(
                                      width: 20,
                                      height: 20,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: const BoxDecoration(shape: BoxShape.circle),
                                      child: Image.network(
                                        'https://api.dicebear.com/9.x/${e.key}/png?seed=${Uri.encodeComponent(_currentSeed.isNotEmpty ? _currentSeed : "seed")}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 14),
                                      ),
                                    ),
                                    label: Text(e.value.split(' (').first),
                                    selected: isSelected,
                                    onSelected: (val) {
                                      if (val) setState(() => _selectedStyle = e.key);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('2. Graine de génération (Seed) :', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _seedController,
                                  decoration: InputDecoration(
                                    hintText: 'Tape un mot, un pseudo...',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _seedController.clear();
                                        setState(() => _currentSeed = user.username);
                                      },
                                    ),
                                  ),
                                  onChanged: (val) => setState(() => _currentSeed = val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _randomizeSeed,
                                icon: const Icon(Icons.casino),
                                label: const Text('Aléatoire'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('3. Ta Bio (description courte) :', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _bioController,
                            maxLength: 120,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Fan d\'Isekai et de Shōnen...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _isEditingAvatar = false),
                                child: const Text('Annuler'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _isSavingProfile ? null : () => _saveAvatar(user),
                                icon: _isSavingProfile
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.check),
                                label: const Text('Enregistrer mon avatar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // --- CARTE STATUT DE SYNCHRONISATION CLOUD & DIFF ---
                _buildSyncCard(context),

                const SizedBox(height: 24),

                // --- STATISTIQUES DE VISIONNAGE ---
                Text(
                  'Statistiques de ta bibliothèque',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                statsAsync.when(
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (stats) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 550;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 4 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            _buildStatCard(
                              context,
                              title: 'Total Animes',
                              value: stats.totalEntries.toString(),
                              icon: Icons.video_library_outlined,
                              color: colorScheme.primary,
                            ),
                            _buildStatCard(
                              context,
                              title: 'Terminés',
                              value: stats.completedCount.toString(),
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            _buildStatCard(
                              context,
                              title: 'Épisodes Vus',
                              value: stats.watchedEpisodesCount.toString(),
                              icon: Icons.play_circle_outline,
                              color: Colors.orange,
                            ),
                            _buildStatCard(
                              context,
                              title: 'Temps Visionné',
                              value: stats.totalWatchedHours >= 1.0
                                  ? '${stats.totalWatchedHours.toStringAsFixed(1)} h'
                                  : '${(stats.totalWatchedHours * 60).toInt()} min',
                              icon: Icons.access_time,
                              color: Colors.purple,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // --- ACCÈS RAPIDE AUX SECTIONS ---
                Text(
                  'Accès rapide',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 580;
                    final statsCard = Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Redirection vers l'onglet Statistiques
                          ref.read(appNavigationIndexProvider.notifier).state = tabStats;
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.bar_chart, color: colorScheme.onPrimaryContainer),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Statistiques Détaillées',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Graphiques d\'activité, temps vu et répartition des genres',
                                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );

                    final leaderboardCard = Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Redirection vers l'onglet Classement
                          ref.read(appNavigationIndexProvider.notifier).state = tabLeaderboard;
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Classement Communautaire',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Podium des membres, dashboards et top 5 anime',
                                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: statsCard),
                          const SizedBox(width: 12),
                          Expanded(child: leaderboardCard),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        statsCard,
                        const SizedBox(height: 10),
                        leaderboardCard,
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // --- ACTIONS DU COMPTE ---
                Text(
                  'Sécurité & Compte',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Modifier mon nom d\'utilisateur'),
                        subtitle: Text('Pseudo actuel : ${user.username}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showChangeUsernameDialog(user),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.password_outlined),
                        title: const Text('Modifier mon mot de passe'),
                        subtitle: const Text('Met à jour le mot de passe de ton compte Turso'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showChangePasswordDialog(user),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.logout, color: colorScheme.error),
                        title: Text('Se déconnecter', style: TextStyle(color: colorScheme.error)),
                        subtitle: const Text('Déconnecte cet appareil de ton compte'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _confirmLogout,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastSync(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return "À l'instant";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours} h";
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour}h${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildSyncCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final syncService = ref.watch(syncServiceProvider);
    final syncAsync = ref.watch(syncStatusProvider);
    final status = syncAsync.value ?? syncService.currentStatus;

    final isSyncing = status.state == SyncState.syncing;
    final isOffline = status.state == SyncState.offline || status.pendingQueueCount > 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSyncing
                    ? colorScheme.primaryContainer
                    : (isOffline
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.15)),
                shape: BoxShape.circle,
              ),
              child: isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isOffline ? Icons.cloud_queue : Icons.cloud_done_outlined,
                      color: isOffline ? Colors.amber[800] : Colors.green[700],
                      size: 22,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isSyncing
                            ? 'Synchronisation avec Turso...'
                            : (isOffline
                                ? '${status.pendingQueueCount} modification(s) en attente'
                                : 'Cloud synchronise'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isOffline) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Hors-ligne',
                            style: TextStyle(
                              color: Colors.amber[900],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSyncing
                        ? 'Synchronisation avec le cloud en cours...'
                        : (status.lastSyncedAt != null
                            ? 'Dernière synchro : ${_formatLastSync(status.lastSyncedAt!)}'
                            : (isOffline
                                ? 'Non synchronisé avec le cloud'
                                : 'Synchronisé avec le cloud')),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: isSyncing
                  ? null
                  : () async {
                      final ok = await syncService.fullSync();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Synchronisation reussie ! Vos donnees sont a jour.'
                                : 'Erreur de connexion : vos modifications restent securisees en local.'),
                          ),
                        );
                      }
                    },
              icon: isSyncing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync, size: 18),
              label: Text(isSyncing ? 'En cours...' : 'Synchroniser'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
