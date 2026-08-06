/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Résolution de source via **ani-cli** (spike US-00). L'app pilote ani-cli
/// pour obtenir/lancer un épisode ; ani-cli résout la source et joue via mpv.
///
/// ⚠️ Les flags exacts d'ani-cli restent à confirmer une fois le binaire installé
/// (spike US-00). Cette classe isole la CONSTRUCTION de la commande et le
/// PARSING de la sortie pour que ces choix soient testables et faciles à ajuster.
library;

import 'process_runner.dart';

/// Langue de piste demandée à ani-cli.
enum PlaybackLanguage {
  /// Version originale sous-titrée français.
  vostfr,

  /// Version française doublée.
  vf,
}

/// Exception levée quand ani-cli échoue ou ne renvoie pas de résultat exploitable.
class ResolveException implements Exception {
  final String message;
  const ResolveException(this.message);
  @override
  String toString() => 'ResolveException: $message';
}

/// Résout et lance un épisode via ani-cli.
class AniCliResolver {
  /// Chemin (ou nom) de l'exécutable ani-cli.
  final String aniCliPath;

  /// Fonction d'exécution de processus (injectable pour test).
  final ProcessRunner runner;

  const AniCliResolver({
    this.aniCliPath = 'ani-cli',
    required this.runner,
  });

  /// Construit les arguments ani-cli pour lancer [title] à l'épisode [episode]
  /// dans la langue [language]. Non-interactif : `-e` pour l'épisode, `--dub`
  /// pour la VF (VOSTFR = défaut sub d'ani-cli), et le titre en argument de recherche.
  ///
  /// Exposé (et testé) séparément car c'est le point le plus susceptible d'être
  /// ajusté après le spike US-00.
  List<String> buildArgs({
    required String title,
    required int episode,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) {
    return [
      '-e', '$episode',
      if (language == PlaybackLanguage.vf) '--dub',
      title,
    ];
  }

  /// Lance ani-cli sur l'épisode demandé. Retourne `true` si le lancement a réussi
  /// (exit 0). Lève [ResolveException] sinon, avec la sortie d'erreur.
  Future<bool> play({
    required String title,
    required int episode,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final args = buildArgs(title: title, episode: episode, language: language);
    final ProcessResult result;
    try {
      result = await runner(aniCliPath, args);
    } catch (e) {
      throw ResolveException('Impossible de lancer ani-cli ($aniCliPath): $e');
    }
    if (!result.ok) {
      throw ResolveException(
        'ani-cli a échoué (code ${result.exitCode}) : '
        '${result.stderr.isNotEmpty ? result.stderr.trim() : result.stdout.trim()}',
      );
    }
    return true;
  }
}
