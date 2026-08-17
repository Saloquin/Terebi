/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Matching de titre et parsing du catalogue anime-sama. Port fidèle de :
///   - `get_catalogue` (anime_sama.py:1043) — parsing des cartes de recherche
///   - `_norm_title`, `_title_tokens`, `_best_catalogue_index`,
///     `_search_catalogue` (animesama_resolve.py:68-144) — matching robuste
///
/// Les titres de la source (AniList historique) étant souvent plus longs que
/// ceux d'anime-sama (« Season 3 », « Part 2 », sous-titre après « : »), le
/// matching dégrade la requête mot par mot jusqu'au 1er résultat fiable, et
/// exige une correspondance FORTE (exacte > inclusion > chevauchement >= moitié
/// des jetons utiles) pour éviter de tomber sur une franchise sans rapport.
library;

import 'package:html/parser.dart' as html_parser;

import 'animesama_http_client.dart';
import 'animesama_domain.dart';

/// Mots vides ignorés dans le calcul de chevauchement de jetons.
/// IDENTIQUE au Python `_STOPWORDS`.
const Set<String> _stopwords = {
  'the', 'a', 'an', 'of', 'to', 'in', 'and', 'le', 'la', 'les', 'un', 'une',
  'de', 'des', 'du', 'et', 'no', 'wa', 'ga', 'season', 'saison', 'part',
};

/// Une entrée brute du catalogue (titre + URL de la page), avant enrichissement.
class CatalogueEntry {
  final String title;
  final String url;
  const CatalogueEntry(this.title, this.url);
}

/// Normalise un titre : minuscule, alphanumérique uniquement (`_norm_title`).
String normTitle(String? s) =>
    (s ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Jetons significatifs d'un titre (>=2 caractères, hors mots vides).
/// Port de `_title_tokens`.
Set<String> titleTokens(String? s) {
  return (s ?? '')
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length >= 2 && !_stopwords.contains(t))
      .toSet();
}

/// Index du meilleur résultat catalogue pour [query] parmi [names], ou `null`
/// si aucun n'est fiable. Port EXACT de `_best_catalogue_index` :
/// exacte > inclusion > chevauchement significatif (>= moitié des jetons utiles).
int? bestCatalogueIndex(String query, List<String> names) {
  if (names.isEmpty) return null;
  final qn = normTitle(query);
  final qt = titleTokens(query);
  int? bestI;
  int bestOverlap = 0;
  for (var i = 0; i < names.length; i++) {
    final nn = normTitle(names[i]);
    if (nn == qn) return i; // correspondance exacte
    if (qn.isNotEmpty && nn.isNotEmpty && (nn.contains(qn) || qn.contains(nn))) {
      return i; // inclusion (sous-titre / suffixe)
    }
    final overlap = qt.intersection(titleTokens(names[i])).length;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      bestI = i;
    }
  }
  // Chevauchement significatif requis : >= la moitié des jetons utiles (et >= 1).
  if (qt.isNotEmpty && bestOverlap >= 1 && bestOverlap * 2 >= qt.length) {
    return bestI;
  }
  return null;
}

/// Génère les requêtes dégradées pour [title] : titre complet, puis on retire
/// le dernier mot à chaque tour, jusqu'au 1er mot. Dédupliqué, ordre conservé.
/// Port de la construction de `queries` dans `_search_catalogue`.
List<String> degradedQueries(String title) {
  final tokens =
      title.split(RegExp(r'[^A-Za-z0-9]+')).where((t) => t.isNotEmpty).toList();
  final queries = <String>[];
  for (var n = tokens.length; n >= 1; n--) {
    final q = tokens.sublist(0, n).join(' ');
    if (!queries.contains(q)) queries.add(q);
  }
  return queries;
}

/// Parse le HTML d'une page catalogue en entrées (titre + URL).
/// Port EXACT de la boucle de parsing de `get_catalogue` (BeautifulSoup).
List<CatalogueEntry> parseCatalogueHtml(String htmlContent, {bool vf = false}) {
  final doc = html_parser.parse(htmlContent);
  final entries = <CatalogueEntry>[];
  final seen = <String>{};
  for (final card in doc.querySelectorAll('a[href]')) {
    var href = card.attributes['href'] ?? '';
    if (!href.contains('/catalogue/') || seen.contains(href)) continue;
    if (href == '/catalogue/' || href == '/catalogue') continue;
    var titleTag = card.querySelector('h2.card-title');
    titleTag ??= card.querySelector(
        'h1.text-white.font-bold.uppercase.text-md.line-clamp-2');
    if (titleTag == null) continue;
    final titre = titleTag.text.trim();
    if (titre.isEmpty) continue;
    seen.add(href);
    // En VF, l'URL est réécrite vostfr -> vf (comme le Python).
    final url = vf ? href.replaceAll('vostfr', 'vf') : href;
    entries.add(CatalogueEntry(titre, url));
  }
  return entries;
}

/// Requête catalogue réseau + parsing, pour un [query] et une langue.
/// Port de la partie réseau de `get_catalogue` (GET /catalogue/?search=..).
Future<List<CatalogueEntry>> fetchCatalogue(
  HttpFetcher fetch,
  String domain,
  String query, {
  bool vf = false,
}) async {
  final headers = {
    ...kHeadersBase,
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'referer': 'https://$domain/catalogue/',
  };
  final q = <String, String>{'search': query, 'type[]': 'Anime'};
  if (vf) q['langue[]'] = 'VF';
  try {
    final resp =
        await fetch('https://$domain/catalogue/', headers: headers, query: q);
    if (!resp.ok) return const [];
    return parseCatalogueHtml(resp.body, vf: vf);
  } catch (_) {
    return const [];
  }
}

/// Cherche [title] avec dégradation mot-par-mot ; renvoie le 1er match FIABLE
/// (nom + URL) ou `null`. Port de `_search_catalogue`.
Future<CatalogueEntry?> searchCatalogue(
  HttpFetcher fetch,
  String domain,
  String title, {
  bool vf = false,
}) async {
  final queries = degradedQueries(title);
  if (queries.isEmpty) return null;
  for (final q in queries) {
    final entries = await fetchCatalogue(fetch, domain, q, vf: vf);
    if (entries.isEmpty) continue;
    final idx = bestCatalogueIndex(title, [for (final e in entries) e.title]);
    if (idx != null && idx < entries.length) return entries[idx];
  }
  return null;
}
