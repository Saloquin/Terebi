/// Modèles et logique pure de comparaison de versions — pas d'import Flutter.
/// Importable dans les tests `dart test` sans dart:ui.
library;

// ---------------------------------------------------------------------------
// Modèles
// ---------------------------------------------------------------------------

class ReleaseInfo {
  final String version;
  final String? zipUrl;
  final String? apkUrl;
  final String? releaseNotes;
  final String? releaseUrl;

  const ReleaseInfo({
    required this.version,
    required this.zipUrl,
    this.apkUrl,
    this.releaseNotes,
    this.releaseUrl,
  });

  factory ReleaseInfo.fromGitHub(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
    final assets = json['assets'] as List<dynamic>? ?? const [];
    String? zipUrl;
    String? apkUrl;
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.zip')) {
        zipUrl = asset['browser_download_url'] as String?;
      } else if (name.endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String?;
      }
    }
    final releaseNotes = json['body'] as String?;
    final releaseUrl = json['html_url'] as String?;
    return ReleaseInfo(
      version: tag,
      zipUrl: zipUrl,
      apkUrl: apkUrl,
      releaseNotes: releaseNotes,
      releaseUrl: releaseUrl,
    );
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
  final String? apkUrl;
  final String? releaseNotes;
  final String? releaseUrl;

  const UpdateAvailable({
    required this.currentVersion,
    required this.latestVersion,
    required this.zipUrl,
    this.apkUrl,
    this.releaseNotes,
    this.releaseUrl,
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
  final maxLen = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < maxLen; i++) {
    final partA = i < a.length ? a[i] : 0;
    final partB = i < b.length ? b[i] : 0;
    if (partB > partA) return true;
    if (partB < partA) return false;
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
