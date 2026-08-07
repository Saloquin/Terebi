/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Résolution de source via **ani-cli** (spike US-00 VALIDÉ).
///
/// Deux usages :
/// - [resolveStreamUrl] : lance ani-cli avec `ANI_CLI_PLAYER=debug`, ce qui lui
///   fait IMPRIMER l'URL du flux (HLS .m3u8) au lieu de la jouer. Terebi peut
///   alors la lire dans le lecteur media_kit encastré. ← chemin privilégié.
/// - [play] : laisse ani-cli lancer son lecteur externe (fallback).
library;

import 'process_runner.dart';
import 'stream_resolver.dart';
import 'title_utils.dart';

/// Résout et lance un épisode via ani-cli.
class AniCliResolver implements StreamResolver {
  /// Chemin (ou nom) de l'exécutable/script ani-cli.
  final String aniCliPath;

  /// Chemin d'un shell POSIX (`sh`) pour exécuter le script ani-cli.
  ///
  /// Sous **Windows**, ani-cli est un script shell (pas un `.exe`) : on doit le
  /// lancer via `sh` (Git Bash : `C:\Program Files\Git\usr\bin\sh.exe`). Le shim
  /// Scoop `ani-cli.cmd` n'est pas fiable (il passe par WSL, souvent absent).
  /// Sous Linux/macOS, laisser `null` : ani-cli s'exécute directement.
  final String? shell;

  /// Fonction d'exécution de processus (injectable pour test).
  final ProcessRunner runner;

  const AniCliResolver({
    this.aniCliPath = 'ani-cli',
    this.shell,
    required this.runner,
  });

  /// Nettoie un titre pour la recherche ani-cli (délègue à [cleanSearchTitle]).
  static String cleanTitle(String title) => cleanSearchTitle(title);

  /// Décompose l'appel effectif en (exécutable, arguments) selon [shell].
  /// Avec un shell défini : `sh <script> <args…>`. Sinon : `<script> <args…>`.
  (String, List<String>) _command(List<String> aniCliArgs) {
    if (shell != null && shell!.isNotEmpty) {
      return (shell!, [aniCliPath, ...aniCliArgs]);
    }
    return (aniCliPath, aniCliArgs);
  }

  /// Construit les arguments ani-cli pour l'épisode [episode] de [title].
  /// Non-interactif : `-S 1` (1er résultat), `-e` (épisode), `--dub` (VF).
  /// Le titre est nettoyé de ses suffixes de saison via [cleanSearchTitle].
  List<String> buildArgs({
    required String title,
    required int episode,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) {
    return [
      '-S', '1',
      '-e', '$episode',
      if (language == PlaybackLanguage.vf) '--dub',
      cleanSearchTitle(title),
    ];
  }

  /// Parse la sortie du mode `debug` d'ani-cli et renvoie les liens par qualité.
  ///
  /// Format attendu (validé au spike US-00) :
  /// ```
  /// All links:
  /// 1080p >https://.../index-f1-v1-a1.m3u8
  /// 720p >https://.../index-f2-v1-a1.m3u8
  /// Selected link:
  /// https://.../index-f1-v1-a1.m3u8
  /// ```
  List<StreamLink> parseQualityLinks(String output) {
    final links = <StreamLink>[];
    for (final rawLine in output.split('\n')) {
      final line = _stripAnsi(rawLine).trim();
      // Format "1080p >https://..." (séparateur ' >').
      final match = RegExp(r'^(\S+?)\s*>\s*(https?://\S+)$').firstMatch(line);
      if (match != null) {
        links.add(StreamLink(quality: match.group(1)!, url: match.group(2)!));
      }
    }
    return links;
  }

  /// Extrait l'URL sélectionnée (ligne après « Selected link: »), ou `null`.
  String? parseSelectedLink(String output) {
    final lines = output.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (_stripAnsi(lines[i]).trim().startsWith('Selected link:')) {
        for (var j = i + 1; j < lines.length; j++) {
          final url = _stripAnsi(lines[j]).trim();
          if (url.startsWith('http')) return url;
        }
      }
    }
    return null;
  }

  /// Résout l'URL du flux **sans lancer de lecteur** (mode `ANI_CLI_PLAYER=debug`).
  /// Retourne l'URL sélectionnée (à jouer dans media_kit encastré).
  ///
  /// [season] est ignoré : ani-cli/allanime utilise une numérotation absolue.
  /// Lève [ResolveException] si ani-cli échoue ou n'imprime aucune URL.
  @override
  Future<String> resolveStreamUrl({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final args = buildArgs(title: title, episode: episode, language: language);
    final (exe, cmdArgs) = _command(args);
    final ProcessResult result;
    try {
      result = await runner(
        exe,
        cmdArgs,
        environment: const {'ANI_CLI_PLAYER': 'debug'},
      );
    } catch (e) {
      throw ResolveException('Impossible de lancer ani-cli ($exe): $e');
    }

    final combined = '${result.stdout}\n${result.stderr}';
    final selected = parseSelectedLink(combined);
    if (selected != null) return selected;

    // Repli : première qualité listée si « Selected link: » absent.
    final links = parseQualityLinks(combined);
    if (links.isNotEmpty) return links.first.url;

    throw ResolveException(
      'ani-cli n\'a renvoyé aucune URL (code ${result.exitCode}). '
      'Sortie : ${combined.trim()}',
    );
  }

  /// Retire les séquences d'échappement ANSI (couleurs terminal d'ani-cli).
  static String _stripAnsi(String s) =>
      s.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');

  /// Lance ani-cli sur l'épisode demandé en laissant ani-cli ouvrir son lecteur
  /// externe (fallback quand l'encastrement n'est pas souhaité).
  Future<bool> play({
    required String title,
    required int episode,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final args = buildArgs(title: title, episode: episode, language: language);
    final (exe, cmdArgs) = _command(args);
    final ProcessResult result;
    try {
      result = await runner(exe, cmdArgs);
    } catch (e) {
      throw ResolveException('Impossible de lancer ani-cli ($exe): $e');
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
