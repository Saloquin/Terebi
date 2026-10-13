import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../services/update_models.dart';

/// Affiche la modale de mise à jour si disponible.
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateAvailable update,
) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => UpdateDialog(update: update),
  );
}

class UpdateDialog extends ConsumerStatefulWidget {
  final UpdateAvailable update;

  const UpdateDialog({super.key, required this.update});

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _isDownloading = false;
  double? _progress;
  String? _statusText;
  String? _errorMessage;

  Future<void> _startInstall() async {
    final zipUrl = widget.update.zipUrl;
    if (zipUrl == null) return;

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = 'Téléchargement de la mise à jour…';
    });

    try {
      final service = ref.read(updateServiceProvider);
      final file = await service.downloadZip(
        zipUrl,
        onProgress: (fraction) {
          if (mounted) {
            setState(() {
              _progress = fraction;
              _statusText =
                  'Téléchargement : ${(fraction * 100).toStringAsFixed(0)} %';
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _statusText = 'Installation et redémarrage de l\'application…';
        _progress = null;
      });

      await service.installZip(file);

      // On laisse le message s'afficher brièvement puis l'app quitte pour laisser
      // le script de swap écraser l'exécutable et relancer Terebi.
      await Future.delayed(const Duration(seconds: 2));
      exit(0);
    } on UpdateError catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.message;
          _statusText = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString();
          _statusText = null;
        });
      }
    }
  }

  Future<void> _downloadApk() async {
    final apkUrl = widget.update.apkUrl;
    if (apkUrl == null) return;

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = 'Téléchargement de l\'APK…';
    });

    try {
      final service = ref.read(updateServiceProvider);
      final file = await service.downloadFile(
        apkUrl,
        fileName: 'terebi-${widget.update.latestVersion}.apk',
        onProgress: (fraction) {
          if (mounted) {
            setState(() {
              _progress = fraction;
              _statusText =
                  'Téléchargement : ${(fraction * 100).toStringAsFixed(0)} %';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'APK téléchargé dans : ${file.path}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString();
          _statusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWindows = Platform.isWindows;
    final isAndroid = Platform.isAndroid;
    final hasZip = widget.update.zipUrl != null;
    final hasApk = widget.update.apkUrl != null;

    final notes = widget.update.releaseNotes?.trim();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('Mise à jour disponible')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${widget.update.latestVersion} disponible '
              '(version installée : ${widget.update.currentVersion})',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (notes != null && notes.isNotEmpty) ...[
              Text(
                'Notes de mise à jour :',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: SelectableText(
                    notes,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              if (_statusText != null)
                Text(
                  _statusText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ] else if (_statusText != null) ...[
              Text(
                _statusText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Erreur : $_errorMessage',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
        if (isWindows && hasZip)
          FilledButton.icon(
            onPressed: _isDownloading ? null : _startInstall,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Mettre à jour maintenant'),
          )
        else if (isAndroid && hasApk)
          FilledButton.icon(
            onPressed: _isDownloading ? null : _downloadApk,
            icon: const Icon(Icons.android_rounded, size: 18),
            label: const Text('Télécharger l\'APK'),
          )
        else if (hasZip)
          FilledButton.icon(
            onPressed: _isDownloading ? null : _startInstall,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Télécharger et installer'),
          ),
      ],
    );
  }
}
