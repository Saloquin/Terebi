/// Page Paramètres : chemins ani-cli/mpv, langue, token AniList, health-check.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/health_service.dart';

// ---------------------------------------------------------------------------
// Providers locaux
// ---------------------------------------------------------------------------

/// Charge tous les settings d'un coup pour pré-remplir les champs.
final _settingsLoadProvider = FutureProvider<Map<String, String?>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return {
    SettingsKeys.aniCliPath:
        await repo.get(SettingsKeys.aniCliPath, defaultValue: 'ani-cli'),
    SettingsKeys.mpvPath:
        await repo.get(SettingsKeys.mpvPath, defaultValue: 'mpv'),
    SettingsKeys.playbackLanguage: await repo.get(
      SettingsKeys.playbackLanguage,
      defaultValue: 'vostfr',
    ),
    SettingsKeys.streamSource:
        await repo.get(SettingsKeys.streamSource, defaultValue: 'animesama'),
    SettingsKeys.pythonPath: await repo.get(SettingsKeys.pythonPath),
    SettingsKeys.animeSamaScript: await repo.get(SettingsKeys.animeSamaScript),
  };
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _aniCliCtrl = TextEditingController();
  final _mpvCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _pythonCtrl = TextEditingController();
  final _animeSamaCtrl = TextEditingController();
  bool _isVf = false;
  // Source de lecture : 'animesama' (VOSTFR/VF) ou 'ani_cli' (anglais).
  String _source = 'animesama';
  bool _initialized = false;

  // Health-check state
  bool _checking = false;
  HealthReport? _report;
  String? _checkError;

  @override
  void dispose() {
    _aniCliCtrl.dispose();
    _mpvCtrl.dispose();
    _tokenCtrl.dispose();
    _pythonCtrl.dispose();
    _animeSamaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'anilist_token');
    if (mounted) {
      _tokenCtrl.text = token ?? '';
    }
  }

  void _initFromSettings(Map<String, String?> settings) {
    if (_initialized) return;
    _initialized = true;
    _aniCliCtrl.text = settings[SettingsKeys.aniCliPath] ?? 'ani-cli';
    _mpvCtrl.text = settings[SettingsKeys.mpvPath] ?? 'mpv';
    _isVf = (settings[SettingsKeys.playbackLanguage] ?? 'vostfr') == 'vf';
    _source = settings[SettingsKeys.streamSource] ?? 'animesama';
    _pythonCtrl.text = settings[SettingsKeys.pythonPath] ?? '';
    _animeSamaCtrl.text = settings[SettingsKeys.animeSamaScript] ?? '';
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.set(SettingsKeys.aniCliPath, _aniCliCtrl.text.trim());
    await repo.set(SettingsKeys.mpvPath, _mpvCtrl.text.trim());
    await repo.set(
      SettingsKeys.playbackLanguage,
      _isVf ? 'vf' : 'vostfr',
    );
    await repo.set(SettingsKeys.streamSource, _source);
    await repo.set(SettingsKeys.pythonPath, _pythonCtrl.text.trim());
    await repo.set(SettingsKeys.animeSamaScript, _animeSamaCtrl.text.trim());

    final token = _tokenCtrl.text.trim();
    final storage = ref.read(secureStorageProvider);
    if (token.isEmpty) {
      await storage.delete(key: 'anilist_token');
    } else {
      await storage.write(key: 'anilist_token', value: token);
    }

    // Invalide les resolvers pour qu'ils rechargent chemins et source.
    ref.invalidate(aniCliResolverProvider);
    ref.invalidate(animeSamaResolverProvider);
    ref.invalidate(activeResolverProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres sauvegardés')),
      );
    }
  }

  Future<void> _runHealthCheck() async {
    final aniCli = _aniCliCtrl.text.trim();
    final mpv = _mpvCtrl.text.trim();

    setState(() {
      _checking = true;
      _report = null;
      _checkError = null;
    });

    try {
      final storage = ref.read(secureStorageProvider);
      final db = ref.read(databaseProvider);
      final httpClient = ref.read(httpClientProvider);
      final runner = ref.read(processRunnerProvider);

      final service = HealthService(
        runner: runner,
        aniCliPath: aniCli.isEmpty ? 'ani-cli' : aniCli,
        mpvPath: mpv.isEmpty ? 'mpv' : mpv,
        hasValidToken: () async {
          final token = await storage.read(key: 'anilist_token');
          return token != null && token.isNotEmpty;
        },
        databaseOk: () async {
          await db.select(db.appSettings).get();
          return true;
        },
        networkOk: () async {
          try {
            final resp = await httpClient.post(
              Uri.parse('https://graphql.anilist.co'),
              headers: {'Content-Type': 'application/json'},
              body:
                  '{"query":"{ Page(page:1,perPage:1){ media{ id } } }"}',
            );
            return resp.statusCode < 500;
          } catch (_) {
            return false;
          }
        },
      );

      final report = await service.run();
      if (mounted) {
        setState(() {
          _report = report;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkError = e.toString();
          _checking = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(_settingsLoadProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err')),
      data: (settings) {
        _initFromSettings(settings);
        // Charge le token la première fois (asynchrone, pas bloquant).
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadToken());

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paramètres',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),

              // --- Source de lecture ---
              _SectionTitle('Source de lecture'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'animesama',
                      label: Text('Anime-sama (VOSTFR/VF)')),
                  ButtonSegment(
                      value: 'ani_cli', label: Text('ani-cli (anglais)')),
                ],
                selected: {_source},
                onSelectionChanged: (s) => setState(() => _source = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Anime-sama fournit du VOSTFR/VF (nécessite Python + le projet '
                'animesama-cli). ani-cli fournit de la VO sous-titrée anglais.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _PathField(
                label: 'Chemin Python (optionnel)',
                hint: 'python',
                controller: _pythonCtrl,
              ),
              const SizedBox(height: 12),
              _PathField(
                label: 'Chemin anime_sama.py (si non détecté)',
                hint: r'…\animesama-cli\anime_sama.py',
                controller: _animeSamaCtrl,
              ),
              const SizedBox(height: 24),

              // --- Chemins externes ---
              _SectionTitle('Lecteur externe'),
              const SizedBox(height: 12),
              _PathField(
                label: 'Chemin ani-cli',
                hint: 'ani-cli',
                controller: _aniCliCtrl,
              ),
              const SizedBox(height: 12),
              _PathField(
                label: 'Chemin mpv',
                hint: 'mpv',
                controller: _mpvCtrl,
              ),
              const SizedBox(height: 16),

              // --- Langue ---
              _SectionTitle('Langue de lecture'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('VOSTFR'),
                  Switch(
                    value: _isVf,
                    onChanged: (v) => setState(() => _isVf = v),
                  ),
                  const Text('VF'),
                ],
              ),
              const SizedBox(height: 24),

              // --- Token AniList ---
              _SectionTitle('Compte AniList'),
              const SizedBox(height: 8),
              _RedirectUriCard(),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Token AniList (Bearer)',
                  hintText: 'Coller le token ici',
                  border: OutlineInputBorder(),
                  helperText:
                      'Obtenu via le flux OAuth — voir le Redirect URI ci-dessus.',
                ),
                obscureText: true,
                maxLines: 1,
              ),
              const SizedBox(height: 24),

              // --- Bouton Sauvegarder ---
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Sauvegarder'),
              ),
              const SizedBox(height: 32),

              // --- Health-check ---
              _SectionTitle('Vérification système'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _checking ? null : _runHealthCheck,
                icon: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety_outlined),
                label: const Text('Vérifier'),
              ),

              if (_checkError != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Erreur : $_checkError',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],

              if (_report != null) ...[
                const SizedBox(height: 16),
                _HealthReportWidget(report: _report!),
              ],

              const SizedBox(height: 32),

              // --- Cache ---
              _SectionTitle('Cache des données'),
              const SizedBox(height: 8),
              Text(
                'Les métadonnées AniList sont mises en cache pour accélérer '
                'l\'app et éviter le rate-limit. Videz-le pour forcer un '
                'rechargement complet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(metaCacheRepositoryProvider).clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache vidé.')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Vider le cache'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliaires
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _PathField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;

  const _PathField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Affiche le Redirect URI OAuth (lecture seule + bouton copier).
class _RedirectUriCard extends StatelessWidget {
  static const _uri = 'http://localhost:8080/callback';

  const _RedirectUriCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Redirect URI OAuth',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _uri,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copier',
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: _uri));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URI copié')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Affiche le rapport health-check sous forme de liste de tuiles.
class _HealthReportWidget extends StatelessWidget {
  final HealthReport report;

  const _HealthReportWidget({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              report.allOk ? Icons.check_circle : Icons.warning_amber_rounded,
              color: report.allOk ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              report.allOk ? 'Tous les composants sont OK' : 'Problèmes détectés',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final check in report.checks)
          _HealthCheckTile(check: check),
      ],
    );
  }
}

class _HealthCheckTile extends StatelessWidget {
  final HealthCheck check;

  const _HealthCheckTile({required this.check});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (check.state) {
      HealthState.ok => (Icons.check_circle_outline, Colors.green),
      HealthState.missing => (Icons.block_outlined, Colors.red),
      HealthState.error => (Icons.error_outline, Colors.orange),
    };

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(check.component),
      subtitle: check.detail != null ? Text(check.detail!) : null,
    );
  }
}
