/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Résolveur VOSTFR/VF via **anime-sama**, en pilotant le wrapper Python
/// `assets/resolver/animesama_resolve.py` (qui réutilise le projet
/// animesama-cli). Le wrapper imprime `RESOLVED_URL: <url>` ou
/// `RESOLVE_ERROR: <msg>` ; on parse la première.
///
/// Le titre reçu est nettoyé de son suffixe de saison (« Dr Stone Saison 2 » →
/// « Dr Stone ») car anime-sama recherche le titre de base ; le numéro de
/// saison est passé séparément.
library;

import 'process_runner.dart';
import 'stream_resolver.dart';
import 'title_utils.dart';

/// Résout un flux VOSTFR/VF via le wrapper Python anime-sama.
class AnimeSamaResolver implements StreamResolver {
  /// Exécutable Python (`python`, `python3`, ou chemin absolu).
  final String pythonPath;

  /// Chemin du wrapper `animesama_resolve.py` (livré avec l'app).
  final String wrapperScriptPath;

  /// Chemin du script `anime_sama.py` du projet animesama-cli installé.
  final String animeSamaScriptPath;

  /// Fonction d'exécution de processus (injectable pour test).
  final ProcessRunner runner;

  const AnimeSamaResolver({
    this.pythonPath = 'python',
    required this.wrapperScriptPath,
    required this.animeSamaScriptPath,
    required this.runner,
  });

  /// Préfixes de sortie du wrapper.
  static const _okPrefix = 'RESOLVED_URL:';
  static const _errPrefix = 'RESOLVE_ERROR:';

  /// Construit les arguments passés à Python.
  /// Le [title] est nettoyé via [cleanSearchTitle] (retire « Saison N »…).
  List<String> buildArgs({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) {
    return [
      wrapperScriptPath,
      '--script', animeSamaScriptPath,
      '--title', cleanSearchTitle(title),
      '--season', '$season',
      '--episode', '$episode',
      if (language == PlaybackLanguage.vf) '--vf',
    ];
  }

  /// Extrait l'URL depuis une sortie contenant `RESOLVED_URL: <url>`, ou `null`.
  String? parseResolvedUrl(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_okPrefix)) {
        return line.substring(_okPrefix.length).trim();
      }
    }
    return null;
  }

  /// Extrait le message d'erreur `RESOLVE_ERROR: <msg>`, ou `null`.
  String? parseError(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_errPrefix)) {
        return line.substring(_errPrefix.length).trim();
      }
    }
    return null;
  }

  @override
  Future<String> resolveStreamUrl({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final args = buildArgs(
      title: title,
      episode: episode,
      season: season,
      language: language,
    );
    final ProcessResult result;
    try {
      result = await runner(pythonPath, args);
    } catch (e) {
      throw ResolveException('Impossible de lancer Python ($pythonPath): $e');
    }

    final combined = '${result.stdout}\n${result.stderr}';
    final url = parseResolvedUrl(combined);
    if (url != null && url.isNotEmpty) return url;

    final err = parseError(combined);
    throw ResolveException(
      err ?? 'anime-sama n\'a renvoyé aucune URL (code ${result.exitCode}).',
    );
  }
}
