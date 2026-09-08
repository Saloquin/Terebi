/// Modèles et logique pure de comparaison de versions — pas d'import Flutter.
/// Importable dans les tests `dart test` sans dart:ui.
library;

// ---------------------------------------------------------------------------
// Modèles
// ---------------------------------------------------------------------------

class ReleaseInfo {
  final String version;
  final String? zipUrl;
  const ReleaseInfo({required this.version, required this.zipUrl});

  factory ReleaseInfo.fromGitHub(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
    final assets = json['assets'] as List<dynamic>? ?? const [];
    String? zipUrl;
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.zip')) {
        zipUrl = asset['browser_download_url'] as String?;
        break;
      }
    }
    return ReleaseInfo(version: tag, zipUrl: zipUrl);
  }
}

sealed class UpdateStatus {
  const UpdateStatus();
}

class UpdateUpToDate extends UpdateStatus {
  final String currentVersion;
  const UpdateUpToDate(this.currentVersion);
}

class UpdateAvailable extends UpdateStatus {
  final String currentVersion;
  final String latestVersion;
  final String? zipUrl;
  const UpdateAvailable({
    required this.currentVersion,
    required this.latestVersion,
    required this.zipUrl,
  });
}

class UpdateError extends UpdateStatus {
  final String message;
  const UpdateError(this.message);
}

// ---------------------------------------------------------------------------
// Utilitaire de comparaison de versions (logique pure)
// ---------------------------------------------------------------------------

bool isNewerVersion({required String current, required String latest}) {
  final a = _parseVersion(current);
  final b = _parseVersion(latest);
  for (var i = 0; i < 3; i++) {
    if (b[i] > a[i]) return true;
    if (b[i] < a[i]) return false;
  }
  return false;
}

List<int> _parseVersion(String v) {
  final clean = v.replaceFirst(RegExp(r'^v'), '').split('+').first;
  final parts = clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}
