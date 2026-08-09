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

import 'dart:convert';

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
  static const _seasonsPrefix = 'SEASONS_JSON:';
  static const _episodesPrefix = 'EPISODES_JSON:';
  static const _cataloguePrefix = 'CATALOGUE_JSON:';
  static const _planningPrefix = 'PLANNING_JSON:';

  /// Args communs (titre nettoyé + langue), pour une [action] donnée.
  List<String> _baseArgs(String action, String title, PlaybackLanguage language) {
    return [
      wrapperScriptPath,
      '--script', animeSamaScriptPath,
      '--action', action,
      '--title', cleanSearchTitle(title),
      if (language == PlaybackLanguage.vf) '--vf',
    ];
  }

  /// Construit les arguments de résolution (action `resolve`).
  /// [season] est l'INDEX 1-based de la saison anime-sama choisie.
  List<String> buildArgs({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) {
    return [
      ..._baseArgs('resolve', title, language),
      '--season', '$season',
      '--episode', '$episode',
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

  /// Parse la ligne `SEASONS_JSON: [...]` en liste de saisons.
  List<AnimeSamaSeason> parseSeasons(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_seasonsPrefix)) {
        final jsonStr = line.substring(_seasonsPrefix.length).trim();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list
            .map((e) => AnimeSamaSeason(
                  index: (e as Map<String, dynamic>)['index'] as int,
                  name: e['name'] as String,
                ))
            .toList();
      }
    }
    return const [];
  }

  /// Parse la ligne `EPISODES_JSON: [...]` en liste de numéros d'épisode.
  List<int> parseEpisodes(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_episodesPrefix)) {
        final jsonStr = line.substring(_episodesPrefix.length).trim();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
      }
    }
    return const [];
  }

  /// Parse la ligne `CATALOGUE_JSON: [...]` en liste d'items catalogue.
  List<AnimeSamaCatalogueItem> parseCatalogue(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_cataloguePrefix)) {
        final jsonStr = line.substring(_cataloguePrefix.length).trim();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list
            .map((e) => AnimeSamaCatalogueItem(
                  title: (e as Map<String, dynamic>)['title'] as String,
                  url: e['url'] as String,
                ))
            .toList();
      }
    }
    return const [];
  }

  /// Parse la ligne `PLANNING_JSON: [...]` en liste d'items de planning.
  /// Déduplique (filet de sécurité) par jour + titre normalisé : anime-sama
  /// liste parfois le même anime en VF ET en VOSTFR.
  List<AnimeSamaPlanningItem> parsePlanning(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_planningPrefix)) {
        final jsonStr = line.substring(_planningPrefix.length).trim();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        final result = <AnimeSamaPlanningItem>[];
        final seen = <String>{};
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final day = m['day'] as String? ?? '';
          final rawTitle = m['title'] as String? ?? '';
          // Retire un éventuel suffixe de version pour la comparaison.
          final title = rawTitle
              .replaceAll(RegExp(r'\s+(VOSTFR|VF)\s*$', caseSensitive: false), '')
              .trim();
          final norm = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final key = '$day|$norm';
          if (seen.contains(key)) continue;
          seen.add(key);
          result.add(AnimeSamaPlanningItem(
            day: day,
            time: m['time'] as String? ?? '',
            title: title,
            url: m['url'] as String? ?? '',
          ));
        }
        return result;
      }
    }
    return const [];
  }

  /// Liste les saisons anime-sama d'un [title]. Lève [ResolveException] si échec.
  Future<List<AnimeSamaSeason>> listSeasons({
    required String title,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final args = _baseArgs('list-seasons', title, language);
    final combined = await _run(args);
    final seasons = parseSeasons(combined);
    if (seasons.isNotEmpty) return seasons;
    throw ResolveException(parseError(combined) ?? 'Aucune saison trouvée.');
  }

  /// Liste les numéros d'épisode d'une saison (par [seasonIndex] 1-based).
  Future<List<int>> listEpisodes({
    required String title,
    required int seasonIndex,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final args = [
      ..._baseArgs('list-episodes', title, language),
      '--season', '$seasonIndex',
    ];
    final combined = await _run(args);
    final eps = parseEpisodes(combined);
    if (eps.isNotEmpty) return eps;
    throw ResolveException(parseError(combined) ?? 'Aucun épisode trouvé.');
  }

  /// Recherche dans le catalogue anime-sama. [query] est utilisé tel quel
  /// (pas de nettoyage de suffixe de saison, contrairement à `resolve`).
  Future<List<AnimeSamaCatalogueItem>> search({
    required String query,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final args = [
      wrapperScriptPath,
      '--script', animeSamaScriptPath,
      '--action', 'search',
      '--title', query,
      if (language == PlaybackLanguage.vf) '--vf',
    ];
    final combined = await _run(args);
    final items = parseCatalogue(combined);
    if (items.isNotEmpty) return items;
    // Une recherche sans résultat n'est pas une erreur : liste vide.
    final err = parseError(combined);
    if (err != null) throw ResolveException(err);
    return const [];
  }

  /// Liste le planning hebdomadaire anime-sama (jour + heure + titre + url).
  Future<List<AnimeSamaPlanningItem>> planning({
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final args = [
      wrapperScriptPath,
      '--script', animeSamaScriptPath,
      '--action', 'planning',
      if (language == PlaybackLanguage.vf) '--vf',
    ];
    final combined = await _run(args);
    final items = parsePlanning(combined);
    if (items.isNotEmpty) return items;
    throw ResolveException(parseError(combined) ?? 'Planning indisponible.');
  }

  /// Lance le wrapper Python et retourne stdout+stderr combinés.
  Future<String> _run(List<String> args) async {
    final ProcessResult result;
    try {
      result = await runner(pythonPath, args);
    } catch (e) {
      throw ResolveException('Impossible de lancer Python ($pythonPath): $e');
    }
    return '${result.stdout}\n${result.stderr}';
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
    final combined = await _run(args);
    final url = parseResolvedUrl(combined);
    if (url != null && url.isNotEmpty) return url;

    throw ResolveException(
      parseError(combined) ?? 'anime-sama n\'a renvoyé aucune URL.',
    );
  }
}
