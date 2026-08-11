/// Page Paramètres : lecture (langue, saut…), chemins anime-sama, health-check.
library;

import 'package:flutter/material.dart';
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
    SettingsKeys.playbackLanguage: await repo.get(
      SettingsKeys.playbackLanguage,
      defaultValue: 'vostfr',
    ),
    SettingsKeys.autoPlayNext:
        await repo.get(SettingsKeys.autoPlayNext, defaultValue: '0'),
    SettingsKeys.singleLanguage:
        await repo.get(SettingsKeys.singleLanguage, defaultValue: '0'),
    SettingsKeys.seekForwardSeconds:
        await repo.get(SettingsKeys.seekForwardSeconds, defaultValue: '10'),
    SettingsKeys.seekBackwardSeconds:
        await repo.get(SettingsKeys.seekBackwardSeconds, defaultValue: '10'),
    SettingsKeys.pythonPath: await repo.get(SettingsKeys.pythonPath),
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

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  final _pythonCtrl = TextEditingController();
  bool _isVf = false;
  bool _autoPlay = false; // enchaînement auto de l'épisode suivant
  bool _singleLang = false; // masque le sélecteur VF/VOSTFR du lecteur
  int _seekFwd = 10; // saut avant (→), secondes
  int _seekBwd = 10; // saut arrière (←), secondes
  bool _initialized = false;

  /// Valeurs proposées pour les sauts avant/arrière (secondes).
  static const _seekChoices = [2, 5, 10, 30];

  // --- Suivi des modifications non sauvegardées ------------------------------
  /// Snapshot des valeurs au dernier chargement/sauvegarde, pour détecter les
  /// changements (barre « modifications non sauvegardées »).
  Map<String, String> _snapshot = const {};
  bool _dirty = false;

  /// `true` une fois le snapshot initial pris. Avant, on ignore les
  /// recalculs « dirty » (les listeners de controllers se déclenchent au
  /// remplissage initial des champs → faux positifs).
  bool _snapshotReady = false;

  /// Contrôleur d'animation pour faire clignoter la barre en rouge quand on
  /// tente de quitter avec des modifs non sauvées. Initialisé dans initState
  /// (pas en `late final` paresseux : sinon il serait créé lors du dispose si
  /// la barre n'a jamais été affichée → crash « deactivated widget »).
  late final AnimationController _flashController;
  int _lastFlashSeen = 0;

  // Health-check state
  bool _checking = false;
  HealthReport? _report;
  String? _checkError;

  // Installation des dépendances Python
  bool _installing = false;
  String? _installResult;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    // Toute frappe dans un champ peut changer l'état « dirty ».
    for (final c in [
      _pythonCtrl,
    ]) {
      c.addListener(_recomputeDirty);
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _pythonCtrl.dispose();
    super.dispose();
  }

  /// Valeurs courantes des champs (pour comparaison au snapshot).
  Map<String, String> _currentValues() => {
        'python': _pythonCtrl.text.trim(),
        'isVf': '$_isVf',
        'autoPlay': '$_autoPlay',
        'singleLang': '$_singleLang',
        'seekFwd': '$_seekFwd',
        'seekBwd': '$_seekBwd',
      };

  /// Recalcule l'état « dirty » et le publie pour l'AppShell.
  void _recomputeDirty() {
    if (!_snapshotReady) return; // snapshot initial pas encore pris
    final dirty = !_mapEquals(_currentValues(), _snapshot);
    if (dirty != _dirty) {
      setState(() => _dirty = dirty);
      // Publie hors phase de build (le listener peut se déclencher pendant).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(settingsDirtyProvider.notifier).state = dirty;
      });
    }
  }

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  void _initFromSettings(Map<String, String?> settings) {
    if (_initialized) return;
    _initialized = true;
    _isVf = (settings[SettingsKeys.playbackLanguage] ?? 'vostfr') == 'vf';
    _autoPlay = (settings[SettingsKeys.autoPlayNext] ?? '0') == '1';
    _singleLang = (settings[SettingsKeys.singleLanguage] ?? '0') == '1';
    _pythonCtrl.text = settings[SettingsKeys.pythonPath] ?? '';
    _seekFwd = _normalizeSeek(settings[SettingsKeys.seekForwardSeconds]);
    _seekBwd = _normalizeSeek(settings[SettingsKeys.seekBackwardSeconds]);
    _snapshot = _currentValues();
    _snapshotReady = true;
  }

  /// Convertit une valeur stockée en un des choix proposés (défaut 10).
  static int _normalizeSeek(String? raw) {
    final v = int.tryParse(raw ?? '');
    return (v != null && _seekChoices.contains(v)) ? v : 10;
  }

  /// Réinitialise les champs aux dernières valeurs sauvegardées (bouton Annuler).
  void _resetToSnapshot() {
    _pythonCtrl.text = _snapshot['python'] ?? '';
    setState(() {
      _isVf = _snapshot['isVf'] == 'true';
      _autoPlay = _snapshot['autoPlay'] == 'true';
      _singleLang = _snapshot['singleLang'] == 'true';
      _seekFwd = _normalizeSeek(_snapshot['seekFwd']);
      _seekBwd = _normalizeSeek(_snapshot['seekBwd']);
    });
    _recomputeDirty();
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.set(
      SettingsKeys.playbackLanguage,
      _isVf ? 'vf' : 'vostfr',
    );
    await repo.set(SettingsKeys.autoPlayNext, _autoPlay ? '1' : '0');
    await repo.set(SettingsKeys.singleLanguage, _singleLang ? '1' : '0');
    await repo.set(SettingsKeys.seekForwardSeconds, '$_seekFwd');
    await repo.set(SettingsKeys.seekBackwardSeconds, '$_seekBwd');
    await repo.set(SettingsKeys.pythonPath, _pythonCtrl.text.trim());

    // Invalide les resolvers pour qu'ils rechargent chemins/langue.
    ref.invalidate(animeSamaResolverProvider);
    ref.invalidate(activeResolverProvider);
    // Invalide le cache de chargement pour que la page relise les valeurs
    // sauvegardées à la prochaine ouverture (sinon champs re-remplis à vide).
    ref.invalidate(_settingsLoadProvider);

    // Fige le nouveau snapshot → plus de modifs en attente.
    _snapshot = _currentValues();
    _recomputeDirty();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres sauvegardés')),
      );
    }
  }

  /// Installe les dépendances Python du résolveur anime-sama via
  /// `python -m pip install --user requests beautifulsoup4`. Nécessite Python.
  Future<void> _installPythonDeps() async {
    final python = _pythonCtrl.text.trim().isEmpty
        ? 'python'
        : _pythonCtrl.text.trim();
    setState(() {
      _installing = true;
      _installResult = null;
    });
    try {
      final runner = ref.read(processRunnerProvider);
      final r = await runner(python, [
        '-m', 'pip', 'install', '--user', 'requests', 'beautifulsoup4',
      ]);
      if (mounted) {
        setState(() {
          _installResult = r.ok
              ? '✓ Dépendances installées (requests, beautifulsoup4).'
              : '✗ Échec (code ${r.exitCode}). '
                  '${r.stderr.trim().split('\n').last}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _installResult = '✗ Impossible de lancer Python ($python) : $e');
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _runHealthCheck() async {
    final python = _pythonCtrl.text.trim();

    setState(() {
      _checking = true;
      _report = null;
      _checkError = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final httpClient = ref.read(httpClientProvider);
      final runner = ref.read(processRunnerProvider);

      final service = HealthService(
        runner: runner,
        pythonPath: python.isEmpty ? 'python' : python,
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

    // Déclenche le clignotement rouge quand l'AppShell signale une tentative de
    // sortie avec des modifs non sauvées.
    ref.listen<int>(settingsFlashProvider, (prev, next) {
      if (next != _lastFlashSeen) {
        _lastFlashSeen = next;
        _flashController.forward(from: 0).then((_) => _flashController.reverse());
      }
    });

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err')),
      data: (settings) {
        _initFromSettings(settings);

        return Scaffold(
          // La barre d'actions n'apparaît qu'en présence de modifs non sauvées.
          bottomNavigationBar: _dirty ? _buildDirtyBar(context) : null,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paramètres',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),

                // --- Lecture ---
                _SectionTitle('Lecture'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Version française (VF)'),
                  subtitle: const Text(
                      'Désactivé = VOSTFR. Certains animes n\'ont qu\'une des deux.'),
                  value: _isVf,
                  onChanged: (v) {
                    setState(() => _isVf = v);
                    _recomputeDirty();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Langue unique'),
                  subtitle: const Text(
                      'Masque le sélecteur VF/VOSTFR du lecteur et n\'effectue aucun test de langue (plus rapide si vous regardez toujours dans la même langue).'),
                  value: _singleLang,
                  onChanged: (v) {
                    setState(() => _singleLang = v);
                    _recomputeDirty();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enchaîner l\'épisode suivant'),
                  subtitle: const Text(
                      'Lance automatiquement le prochain épisode en fin de lecture (compte à rebours annulable).'),
                  value: _autoPlay,
                  onChanged: (v) {
                    setState(() => _autoPlay = v);
                    _recomputeDirty();
                  },
                ),
                const SizedBox(height: 12),
                // Durées de saut (flèches ← / → du lecteur).
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Recul (←)',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButton<int>(
                          value: _seekBwd,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final s in _seekChoices)
                              DropdownMenuItem(value: s, child: Text('$s s')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _seekBwd = v);
                            _recomputeDirty();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Avance (→)',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButton<int>(
                          value: _seekFwd,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final s in _seekChoices)
                              DropdownMenuItem(value: s, child: Text('$s s')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _seekFwd = v);
                            _recomputeDirty();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Source anime-sama ---
                _SectionTitle('Source (anime-sama)'),
                const SizedBox(height: 8),
                Text(
                  'La lecture provient d\'anime-sama (VOSTFR/VF), via Python. Le '
                  'script de résolution est intégré à l\'app : il suffit d\'avoir '
                  'Python et ses deux dépendances (requests, beautifulsoup4).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _installing ? null : _installPythonDeps,
                  icon: _installing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: const Text('Installer les dépendances Python'),
                ),
                if (_installResult != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _installResult!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                _PathField(
                  label: 'Chemin Python (optionnel)',
                  hint: 'python',
                  controller: _pythonCtrl,
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
          ),
        );
      },
    );
  }

  /// Barre d'actions « modifications non sauvegardées » (façon Discord),
  /// affichée en bas de page. Clignote en rouge quand on tente de quitter.
  Widget _buildDirtyBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, _) {
        // Interpole vers le rouge d'erreur pendant le clignotement.
        final base = scheme.surfaceContainerHighest;
        final color = Color.lerp(base, scheme.errorContainer, _flashController.value)!;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Vous avez des modifications non sauvegardées.'),
                ),
                TextButton(
                  onPressed: _resetToSnapshot,
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Sauvegarder'),
                ),
              ],
            ),
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
