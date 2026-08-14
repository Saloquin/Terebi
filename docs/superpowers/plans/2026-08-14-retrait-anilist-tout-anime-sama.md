# Retrait complet d'AniList, tout via anime-sama — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer AniList/Jikan par anime-sama comme source unique (identité par slug, enrichissement scrapé, découverte via home/catalogue), avec une DB traitée comme cache (cache-first + revalidation background) et une UI temps réel via streams Drift.

**Architecture:** Le wrapper Python `animesama_resolve.py` gagne des actions d'enrichissement (`catalogue-detail`, `home`, `catalogue-filter`) et expose le `slug` d'URL. Côté Dart, l'identité technique devient un `int` positif déterministe dérivé du slug (`animeSamaIdForSlug`), le slug est stocké en clair (colonne `animeSamaSlug`). Les providers de données de catalogue passent en `StreamProvider` branchés sur `watch*()` Drift : toute écriture DB se propage à l'écran. Une migration v2→v3 en deux temps (schéma dans `onUpgrade`, ré-indexation au 1er boot via `SlugMigrationService`) préserve la progression. AniSkip est conservé (malId par titre côté Python).

**Tech Stack:** Flutter/Dart desktop, Riverpod, Drift (SQLite), media_kit, wrapper Python (Process.run) sur anime-sama.to.

## Notes d'exécution transverses (à lire avant de commencer)

- **Tests : PAS de `dart test` direct sur ce poste** (EDR Windows bloque `flutter_tester`). Tous les tests tournent en conteneur via `./scripts/flutter-ci.sh test`. Pour cibler un fichier : `./scripts/flutter-ci.sh test test/chemin/du_test.dart`.
- **Piège `pubspec.lock` (Windows/Docker)** : le conteneur fait `flutter pub get` et réécrit `pubspec.lock`. **Avant chaque commit**, si `pubspec.lock` est modifié sans raison : `git checkout -- pubspec.lock`.
- **Messages de commit** : pas de guillemets français `« »` ni de caractères spéciaux fragiles dans le message ; ASCII simple.
- **Tests Python** : le wrapper `animesama_resolve.py` se teste via un test Dart sur les *parseurs* (`parseCatalogue`, etc.) alimentés par des sorties JSON simulées — on NE lance PAS Python dans les tests (réseau + install). Les nouvelles actions Python sont validées manuellement par l'utilisateur sur son PC (scraping live non reproductible ici).
- **Ordre** : les tâches suivent l'ordre 5d du spec. Chaque tâche est autonome et se termine par un commit vert.

---

## File Structure

**Python (assets/resolver/)**
- `animesama_resolve.py` — MODIFIÉ : `search`/`planning` ajoutent `slug` ; nouvelles actions `catalogue-detail`, `home`, `catalogue-filter`.

**Dart — domaine pur (testable)**
- `lib/src/domain/logic/anime_id.dart` — MODIFIÉ : ajout `slugFromCatalogueUrl`, `animeSamaIdForSlug`.
- `lib/src/domain/models/media.dart` — MODIFIÉ : `fromAnimeSama` enrichi (slug/synopsis/genres/banner), ajout `animeSamaSlug`, retrait `enrichedWith`/`fromAniList`.
- `lib/src/services/stream_resolver.dart` — MODIFIÉ : `AnimeSamaCatalogueItem` gagne `slug`, `cover`, `genres` ; nouvelles data-classes `AnimeSamaDetail`, `AnimeSamaHome`.
- `lib/src/services/animesama_resolver.dart` — MODIFIÉ : parseurs + méthodes `catalogueDetail`, `home`, `catalogueByGenre` ; `parseCatalogue`/`parsePlanning` lisent le slug.

**Dart — données**
- `lib/src/data/local/database.dart` — MODIFIÉ : colonne `animeSamaSlug`, schémaVersion 3, migration.
- `lib/src/data/repositories/media_repository.dart` — MODIFIÉ : `watchMedia(id)`, mapping `animeSamaSlug`.
- `lib/src/data/repositories/list_repository.dart` — MODIFIÉ : `watchEntry(id)`, `watchEntriesByStatus(status)`, `watchAllEntries()`, `reindexMediaId(old,new)`.
- `lib/src/data/repositories/settings_repository.dart` — MODIFIÉ : `watchWithPrefix(prefix)`, `renameKeyPrefix(old,new)`.

**Dart — services (nouveaux)**
- `lib/src/services/animesama_catalog_service.dart` — CRÉÉ : cache-first + revalidation background.
- `lib/src/services/slug_migration_service.dart` — CRÉÉ : ré-indexation titre→slug au 1er boot.

**Dart — UI/câblage**
- `lib/src/app/providers.dart` — MODIFIÉ : StreamProviders, suppression AniList/Jikan, health-check anime-sama.
- `lib/src/ui/pages/home_page.dart` — MODIFIÉ : rangées classiques/derniers/par genre, suppression rangées AniList.
- `lib/src/ui/pages/media_detail_page.dart` — MODIFIÉ : enrichissement via catalogue-detail, purge sans invalidate.

**Dart — supprimés**
- `lib/src/data/remote/anilist_client.dart`, `cached_anilist_client.dart`, `jikan_client.dart`, `request_queue.dart`, `lib/src/services/title_matcher.dart` + tests associés.

---
## Task 1 : Identité par slug (`slugFromCatalogueUrl`, `animeSamaIdForSlug`)

**Files:**
- Modify: `lib/src/domain/logic/anime_id.dart` (ajout en fin de fichier, après `titleMatchScore` ligne 106+)
- Test: `test/domain/anime_id_test.dart` (nouveau groupe)

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter à la fin de `test/domain/anime_id_test.dart`, à l'intérieur du `main()` existant (avant la dernière `}`) :

```dart
  group('slugFromCatalogueUrl', () {
    test('extrait le slug depuis /catalogue/<slug>/', () {
      expect(slugFromCatalogueUrl('/catalogue/one-piece/'), 'one-piece');
      expect(slugFromCatalogueUrl('/catalogue/dr-stone'), 'dr-stone');
      expect(slugFromCatalogueUrl('https://anime-sama.to/catalogue/naruto/'),
          'naruto');
    });

    test('ignore les segments de langue/saison apres le slug', () {
      // anime-sama : /catalogue/<slug>/saison1/vostfr/ -> on ne garde que le slug.
      expect(slugFromCatalogueUrl('/catalogue/bleach/saison1/vostfr/'), 'bleach');
    });

    test('URL sans /catalogue/ -> chaine vide', () {
      expect(slugFromCatalogueUrl('/planning/'), '');
      expect(slugFromCatalogueUrl(''), '');
    });
  });

  group('animeSamaIdForSlug', () {
    test('est deterministe (meme slug -> meme id)', () {
      expect(animeSamaIdForSlug('one-piece'), animeSamaIdForSlug('one-piece'));
    });

    test('est toujours strictement positif (jamais 0, jamais negatif)', () {
      for (final s in ['one-piece', 'naruto', 'a', 'dr-stone', 'x-2024']) {
        expect(animeSamaIdForSlug(s), greaterThan(0), reason: 'slug=$s');
      }
    });

    test('slugs differents -> ids differents (pas de collision triviale)', () {
      final ids = {
        animeSamaIdForSlug('one-piece'),
        animeSamaIdForSlug('naruto'),
        animeSamaIdForSlug('bleach'),
        animeSamaIdForSlug('dr-stone'),
        animeSamaIdForSlug('fate'),
      };
      expect(ids.length, 5);
    });
  });
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/domain/anime_id_test.dart`
Expected: FAIL — `slugFromCatalogueUrl` et `animeSamaIdForSlug` non définis.

- [ ] **Step 3: Implémenter**

Ajouter à la fin de `lib/src/domain/logic/anime_id.dart` :

```dart
/// Extrait le slug d'une URL catalogue anime-sama.
///
/// `/catalogue/one-piece/` donne `one-piece`. Tolère l'URL absolue
/// (`https://anime-sama.to/catalogue/...`) et les segments qui suivent le slug
/// (`/catalogue/bleach/saison1/vostfr/` donne `bleach`). Retourne '' si l'URL
/// ne contient pas de segment `/catalogue/<slug>`.
String slugFromCatalogueUrl(String url) {
  final match = RegExp(r'/catalogue/([^/]+)').firstMatch(url);
  return match?.group(1)?.trim() ?? '';
}

/// Identifiant technique positif et stable derive du slug anime-sama.
///
/// Le slug d'URL est l'identite logique (unique par construction) ; cet entier
/// en est l'identite technique, pour garder les cles etrangeres entieres des
/// tables de progression. Deterministe (meme slug -> meme id), toujours > 0.
int animeSamaIdForSlug(String slug) {
  final norm = slug.toLowerCase().trim();
  // FNV-1a 32 bits, deterministe et independant de la plateforme.
  var hash = 0x811c9dc5;
  for (final unit in norm.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  // Reduit a un positif non nul (31 bits) : jamais 0, jamais negatif.
  final positive = hash & 0x7fffffff;
  return positive == 0 ? 1 : positive;
}
```

- [ ] **Step 4: Lancer le test pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/domain/anime_id_test.dart`
Expected: PASS (tous les groupes, dont les anciens).

- [ ] **Step 5: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/domain/logic/anime_id.dart test/domain/anime_id_test.dart
git commit -m "feat(id): identite par slug (slugFromCatalogueUrl + animeSamaIdForSlug)"
```

---

## Task 2 : Data-classes enrichies du resolver

**Files:**
- Modify: `lib/src/services/stream_resolver.dart` (classe `AnimeSamaCatalogueItem` lignes 82-100 ; `AnimeSamaPlanningItem` lignes 105-131 ; ajout de classes)
- Test: `test/services/animesama_resolver_test.dart` (existant)

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter dans `test/services/animesama_resolver_test.dart`, dans le `main()` existant :

```dart
  group('AnimeSamaCatalogueItem enrichi', () {
    test('porte slug, cover et genres', () {
      const it = AnimeSamaCatalogueItem(
        title: 'One Piece',
        url: '/catalogue/one-piece/',
        slug: 'one-piece',
        cover: 'https://cdn/one-piece.jpg',
        genres: ['Action', 'Aventure'],
      );
      expect(it.slug, 'one-piece');
      expect(it.cover, 'https://cdn/one-piece.jpg');
      expect(it.genres, ['Action', 'Aventure']);
    });

    test('slug/cover/genres ont des valeurs par defaut', () {
      const it = AnimeSamaCatalogueItem(title: 'X', url: '/catalogue/x/');
      expect(it.slug, '');
      expect(it.cover, isNull);
      expect(it.genres, isEmpty);
    });
  });

  group('AnimeSamaDetail', () {
    test('porte les champs enrichis', () {
      const d = AnimeSamaDetail(
        slug: 'one-piece',
        title: 'One Piece',
        synopsis: 'Un pirate...',
        genres: ['Action'],
        cover: 'https://cdn/c.jpg',
        banner: 'https://cdn/b.jpg',
      );
      expect(d.slug, 'one-piece');
      expect(d.synopsis, 'Un pirate...');
      expect(d.genres, ['Action']);
      expect(d.cover, 'https://cdn/c.jpg');
      expect(d.banner, 'https://cdn/b.jpg');
    });
  });
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/services/animesama_resolver_test.dart`
Expected: FAIL — paramètres `slug`/`cover`/`genres` inconnus, `AnimeSamaDetail` absente.

- [ ] **Step 3: Implémenter**

Dans `lib/src/services/stream_resolver.dart`, remplacer la classe `AnimeSamaCatalogueItem` (lignes 82-100) par :

```dart
/// Un anime du catalogue anime-sama (resultat de recherche / home / genre).
/// [url] est le path catalogue (ex. `/catalogue/dr-stone/`), [slug] son
/// identite (`dr-stone`). [cover]/[genres] sont fournis par les actions
/// enrichies (home, catalogue-filter) ; vides pour une simple recherche.
class AnimeSamaCatalogueItem {
  final String title;
  final String url;
  final String slug;
  final String? cover;
  final List<String> genres;

  const AnimeSamaCatalogueItem({
    required this.title,
    required this.url,
    this.slug = '',
    this.cover,
    this.genres = const [],
  });

  @override
  bool operator ==(Object other) =>
      other is AnimeSamaCatalogueItem &&
      other.title == title &&
      other.url == url &&
      other.slug == slug;

  @override
  int get hashCode => Object.hash(title, url, slug);

  @override
  String toString() => '$title ($url)';
}

/// Detail enrichi d'une page catalogue anime-sama (`/catalogue/<slug>/`).
/// Remplace l'enrichissement AniList (synopsis/genres/image).
class AnimeSamaDetail {
  final String slug;
  final String title;
  final String? synopsis;
  final List<String> genres;
  final String? cover;
  final String? banner;

  const AnimeSamaDetail({
    required this.slug,
    required this.title,
    this.synopsis,
    this.genres = const [],
    this.cover,
    this.banner,
  });
}

/// Sections de decouverte de l'accueil anime-sama.
class AnimeSamaHome {
  final List<AnimeSamaCatalogueItem> classics;
  final List<AnimeSamaCatalogueItem> latestEpisodes;

  const AnimeSamaHome({
    this.classics = const [],
    this.latestEpisodes = const [],
  });
}
```

Dans `AnimeSamaPlanningItem` (lignes 105-131), ajouter le champ `slug` :
- après `final String url;` ajouter `final String slug;`
- au constructeur, ajouter `this.slug = ''`
- dans `operator ==`, ajouter `&& other.slug == slug`
- dans `hashCode`, passer à `Object.hash(day, time, title, url, slug)`

- [ ] **Step 4: Lancer le test pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/services/animesama_resolver_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/services/stream_resolver.dart test/services/animesama_resolver_test.dart
git commit -m "feat(resolver): data-classes enrichies (slug/cover/genres, AnimeSamaDetail, AnimeSamaHome)"
```

---
## Task 3 : Parseurs enrichis dans `AnimeSamaResolver` + méthodes catalogue-detail/home/genre

**Files:**
- Modify: `lib/src/services/animesama_resolver.dart` (préfixes ligne 42-46 ; `parseCatalogue` 137-152 ; `parsePlanning` 157-188 ; ajout parseurs + méthodes)
- Test: `test/services/animesama_resolver_test.dart`

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter dans `test/services/animesama_resolver_test.dart` (le fichier construit déjà un `AnimeSamaResolver` avec un `ProcessRunner` mocké — réutiliser le même style ; ici on teste les parseurs purs qui prennent une string) :

```dart
  group('parseurs enrichis', () {
    // Resolver minimal : les parseurs n'utilisent pas le runner.
    final r = AnimeSamaResolver(
      wrapperScriptPath: 'w.py',
      animeSamaScriptPath: 'a.py',
      runner: (exe, args) async => throw UnimplementedError(),
    );

    test('parseCatalogue lit le slug', () {
      const out = 'CATALOGUE_JSON: '
          '[{"title":"One Piece","url":"/catalogue/one-piece/","slug":"one-piece"}]';
      final items = r.parseCatalogue(out);
      expect(items, hasLength(1));
      expect(items.first.slug, 'one-piece');
      expect(items.first.title, 'One Piece');
    });

    test('parseCatalogue derive le slug de l URL si absent', () {
      const out =
          'CATALOGUE_JSON: [{"title":"Bleach","url":"/catalogue/bleach/"}]';
      expect(r.parseCatalogue(out).first.slug, 'bleach');
    });

    test('parseDetail lit synopsis/genres/cover/banner', () {
      const out = 'DETAIL_JSON: {"slug":"one-piece","title":"One Piece",'
          '"synopsis":"Un pirate","genres":["Action","Aventure"],'
          '"cover_url":"https://cdn/c.jpg","banner_url":"https://cdn/b.jpg"}';
      final d = r.parseDetail(out);
      expect(d, isNotNull);
      expect(d!.slug, 'one-piece');
      expect(d.synopsis, 'Un pirate');
      expect(d.genres, ['Action', 'Aventure']);
      expect(d.cover, 'https://cdn/c.jpg');
      expect(d.banner, 'https://cdn/b.jpg');
    });

    test('parseDetail tolere les champs manquants', () {
      const out = 'DETAIL_JSON: {"slug":"x","title":"X"}';
      final d = r.parseDetail(out);
      expect(d!.synopsis, isNull);
      expect(d.genres, isEmpty);
      expect(d.cover, isNull);
    });

    test('parseHome lit classics et latest_episodes', () {
      const out = 'HOME_JSON: {'
          '"classics":[{"title":"Naruto","url":"/catalogue/naruto/","slug":"naruto","cover_url":"https://cdn/n.jpg","genres":["Action"]}],'
          '"latest_episodes":[{"title":"One Piece","url":"/catalogue/one-piece/","slug":"one-piece"}]}';
      final h = r.parseHome(out);
      expect(h.classics, hasLength(1));
      expect(h.classics.first.title, 'Naruto');
      expect(h.classics.first.cover, 'https://cdn/n.jpg');
      expect(h.classics.first.genres, ['Action']);
      expect(h.latestEpisodes, hasLength(1));
      expect(h.latestEpisodes.first.slug, 'one-piece');
    });

    test('parsePlanning lit le slug', () {
      const out = 'PLANNING_JSON: '
          '[{"day":"Lundi","time":"18h00","title":"One Piece","url":"/catalogue/one-piece/","slug":"one-piece"}]';
      final items = r.parsePlanning(out);
      expect(items.first.slug, 'one-piece');
      expect(items.first.time, '18h00');
    });
  });
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/services/animesama_resolver_test.dart`
Expected: FAIL — `parseDetail`/`parseHome` absents, `slug` non lu.

- [ ] **Step 3: Implémenter**

Dans `lib/src/services/animesama_resolver.dart` :

a) Ajouter les préfixes après la ligne 46 (`_skipPrefix`) :

```dart
  static const _detailPrefix = 'DETAIL_JSON:';
  static const _homePrefix = 'HOME_JSON:';
```

b) Remplacer `parseCatalogue` (lignes 137-152) par une version qui lit slug/cover/genres et dérive le slug de l'URL en repli :

```dart
  /// Parse la ligne `CATALOGUE_JSON: [...]` en items catalogue (slug/cover/genres
  /// optionnels ; slug derive de l'URL si absent).
  List<AnimeSamaCatalogueItem> parseCatalogue(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_cataloguePrefix)) {
        final jsonStr = line.substring(_cataloguePrefix.length).trim();
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map(_catalogueItemFromJson).toList();
      }
    }
    return const [];
  }

  /// Construit un [AnimeSamaCatalogueItem] depuis un objet JSON du wrapper.
  AnimeSamaCatalogueItem _catalogueItemFromJson(dynamic e) {
    final m = e as Map<String, dynamic>;
    final url = m['url'] as String? ?? '';
    final slug = (m['slug'] as String?)?.trim();
    return AnimeSamaCatalogueItem(
      title: m['title'] as String? ?? '',
      url: url,
      slug: (slug != null && slug.isNotEmpty) ? slug : slugFromCatalogueUrl(url),
      cover: m['cover_url'] as String?,
      genres: (m['genres'] as List<dynamic>?)
              ?.map((g) => g.toString())
              .toList() ??
          const [],
    );
  }
```

c) Ajouter l'import du slug en tête de fichier (après les imports existants) :

```dart
import '../domain/logic/anime_id.dart';
```

d) Ajouter les parseurs `parseDetail` et `parseHome` (par ex. après `parseCatalogue`) :

```dart
  /// Parse la ligne `DETAIL_JSON: {...}` en [AnimeSamaDetail], ou null si absent.
  AnimeSamaDetail? parseDetail(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_detailPrefix)) {
        final jsonStr = line.substring(_detailPrefix.length).trim();
        final m = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AnimeSamaDetail(
          slug: m['slug'] as String? ?? '',
          title: m['title'] as String? ?? '',
          synopsis: m['synopsis'] as String?,
          genres: (m['genres'] as List<dynamic>?)
                  ?.map((g) => g.toString())
                  .toList() ??
              const [],
          cover: m['cover_url'] as String?,
          banner: m['banner_url'] as String?,
        );
      }
    }
    return null;
  }

  /// Parse la ligne `HOME_JSON: {...}` en [AnimeSamaHome] (sections vides si absent).
  AnimeSamaHome parseHome(String output) {
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(_homePrefix)) {
        final jsonStr = line.substring(_homePrefix.length).trim();
        final m = jsonDecode(jsonStr) as Map<String, dynamic>;
        List<AnimeSamaCatalogueItem> section(String key) =>
            (m[key] as List<dynamic>?)?.map(_catalogueItemFromJson).toList() ??
            const [];
        return AnimeSamaHome(
          classics: section('classics'),
          latestEpisodes: section('latest_episodes'),
        );
      }
    }
    return const AnimeSamaHome();
  }
```

e) Dans `parsePlanning` (lignes 157-188), lire le slug : dans la construction de `AnimeSamaPlanningItem`, ajouter après `url: m['url'] as String? ?? '',` la ligne :

```dart
            slug: (m['slug'] as String?)?.trim().isNotEmpty == true
                ? (m['slug'] as String).trim()
                : slugFromCatalogueUrl(m['url'] as String? ?? ''),
```

f) Ajouter les méthodes réseau (après `search`, vers la ligne 279) :

```dart
  /// Detail enrichi d'une page catalogue (`catalogue-detail --slug`).
  /// Retourne null si le wrapper ne renvoie pas de DETAIL_JSON.
  Future<AnimeSamaDetail?> catalogueDetail({required String slug}) async {
    final args = [
      wrapperScriptPath,
      '--script', animeSamaScriptPath,
      '--action', 'catalogue-detail',
      '--slug', slug,
    ];
    final combined = await _run(args);
    return parseDetail(combined);
  }

  /// Sections de decouverte de l'accueil (`home`).
  Future<AnimeSamaHome> home() async {
    final args = [
      wrapperScriptPath,
      '--script', animeSamaScriptPath,
      '--action', 'home',
    ];
    final combined = await _run(args);
    return parseHome(combined);
  }

  /// Catalogue filtre par genre (`catalogue-filter --genre`).
  Future<List<AnimeSamaCatalogueItem>> catalogueByGenre({
    required String genre,
  }) async {
    final args = [
      wrapperScriptPath,
      '--script', animeSamaScriptPath,
      '--action', 'catalogue-filter',
      '--genre', genre,
    ];
    final combined = await _run(args);
    return parseCatalogue(combined);
  }
```

- [ ] **Step 4: Lancer le test pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/services/animesama_resolver_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/services/animesama_resolver.dart test/services/animesama_resolver_test.dart
git commit -m "feat(resolver): parseurs+methodes catalogue-detail/home/catalogue-filter, slug dans catalogue/planning"
```

---

## Task 4 : Scraper Python — slug + actions catalogue-detail/home/catalogue-filter

> Non testable ici (scraping live). Validation manuelle par l'utilisateur sur son PC après implémentation. Le contrat JSON est figé par les parseurs Dart de la Task 3 — s'y conformer EXACTEMENT.

**Files:**
- Modify: `assets/resolver/animesama_resolve.py`

- [ ] **Step 1: `search` renvoie le slug**

Dans `action_search` (lignes 336-344), remplacer la construction du payload par :

```python
def action_search(mod, dl, args):
    """Recherche catalogue : renvoie la liste des animes (titre, url, slug)."""
    animes, urls = dl.get_catalogue(args.title, vf=args.vf)
    payload = [
        {"title": t, "url": u, "slug": _slug_from_url(u)}
        for t, u in zip(animes, urls)
    ]
    print(f"CATALOGUE_JSON: {json.dumps(payload, ensure_ascii=False)}")
    sys.exit(0)
```

- [ ] **Step 2: Helper slug + argument `--slug`/`--genre`**

Ajouter près de `_norm` (ligne 415) :

```python
def _slug_from_url(url):
    """Extrait le slug d'une URL /catalogue/<slug>/ (ex. one-piece). '' sinon."""
    m = re.search(r'/catalogue/([^/]+)', url or '')
    return m.group(1).strip() if m else ''
```

Dans `main()`, étendre les choices de `--action` et ajouter deux arguments :

```python
    parser.add_argument("--action", default="resolve",
                        choices=["resolve", "list-seasons", "list-episodes",
                                 "search", "planning", "skip-times",
                                 "catalogue-detail", "home", "catalogue-filter"])
    parser.add_argument("--slug", default="", help="Slug catalogue (catalogue-detail)")
    parser.add_argument("--genre", default="", help="Genre (catalogue-filter)")
```

Et le dispatch (après `elif args.action == "skip-times":`) :

```python
        elif args.action == "catalogue-detail":
            action_catalogue_detail(mod, dl, args)
        elif args.action == "home":
            action_home(mod, dl, args)
        elif args.action == "catalogue-filter":
            action_catalogue_filter(mod, dl, args)
```

- [ ] **Step 3: `planning` renvoie le slug**

Dans `action_planning`, à chaque `items.append({...})` et au remplacement de doublon, ajouter la clé `"slug": _slug_from_url(url)`. (Deux endroits : le remplacement VOSTFR et l'append principal.)

- [ ] **Step 4: Action `catalogue-detail`**

Ajouter (contrat : `DETAIL_JSON: {slug,title,synopsis,genres[],cover_url,banner_url}`) :

```python
def action_catalogue_detail(mod, dl, args):
    """Scrape /catalogue/<slug>/ : titre, synopsis, genres, image de couverture.

    Tolerant : tout champ absent -> null/[] ; ne leve jamais d'exception qui
    casse la sortie JSON (au pire DETAIL_JSON minimal {slug,title}).
    """
    import requests
    slug = args.slug.strip()
    if not slug:
        _fail("catalogue-detail requiert --slug")
    domain = mod.DOMAIN
    url = f"https://{domain}/catalogue/{slug}/"
    detail = {"slug": slug, "title": slug, "synopsis": None,
              "genres": [], "cover_url": None, "banner_url": None}
    try:
        html = requests.get(url, headers=mod.HEADERS_BASE, timeout=15).text
        # Titre : <h1 ...>Titre</h1>
        mt = re.search(r'<h1[^>]*>([^<]+)</h1>', html)
        if mt:
            detail["title"] = mt.group(1).strip()
        # Synopsis : bloc apres un intitule Synopsis (souple).
        ms = re.search(
            r'Synopsis\s*</[^>]+>\s*<p[^>]*>(.*?)</p>', html, re.DOTALL | re.I)
        if ms:
            detail["synopsis"] = re.sub(r'<[^>]+>', '', ms.group(1)).strip()
        # Genres : liste apres un intitule Genres.
        mg = re.search(r'Genres?\s*</[^>]+>\s*<[^>]*>(.*?)</', html,
                       re.DOTALL | re.I)
        if mg:
            detail["genres"] = [g.strip() for g in re.split(r'[,\n]', mg.group(1))
                                if g.strip() and '<' not in g]
        # Image de couverture : le CDN anime-sama en priorite.
        detail["cover_url"] = (
            f"https://cdn.jsdelivr.net/gh/Anime-Sama/IMG/img/contenu/{slug}.jpg")
        mb = re.search(r'<img[^>]+id="coverOeuvre"[^>]+src="([^"]+)"', html)
        if mb:
            detail["banner_url"] = mb.group(1)
    except requests.RequestException:
        pass
    print(f"DETAIL_JSON: {json.dumps(detail, ensure_ascii=False)}")
    sys.exit(0)
```

- [ ] **Step 5: Actions `home` et `catalogue-filter`**

```python
def _cards_from_html(mod, html):
    """Extrait des cartes (title,url,slug,cover_url,genres) d'un fragment HTML."""
    items = []
    for m in re.finditer(
            r'<a href="(/catalogue/[^"]+)"[^>]*>.*?(?:<img[^>]*src="([^"]*)"[^>]*>)?'
            r'.*?<h[13][^>]*>([^<]+)</h[13]>', html, re.DOTALL):
        url, cover, title = m.group(1), m.group(2), m.group(3)
        if hasattr(mod, '_is_scan_url') and mod._is_scan_url(url):
            continue
        slug = _slug_from_url(url)
        items.append({
            "title": title.strip(),
            "url": url.strip(),
            "slug": slug,
            "cover_url": cover or
            f"https://cdn.jsdelivr.net/gh/Anime-Sama/IMG/img/contenu/{slug}.jpg",
            "genres": [],
        })
    return items


def action_home(mod, dl, args):
    """Sections de l'accueil : classiques + derniers episodes ajoutes."""
    import requests
    domain = mod.DOMAIN
    home = {"classics": [], "latest_episodes": []}
    try:
        html = requests.get(f"https://{domain}/", headers=mod.HEADERS_BASE,
                            timeout=15).text
        # Section "Classiques" : on isole le bloc entre l'intitule et le suivant.
        def section(label):
            m = re.search(label + r'(.*?)(?:<h2|<footer|\Z)', html,
                          re.DOTALL | re.I)
            return _cards_from_html(mod, m.group(1)) if m else []
        home["classics"] = section(r'Classiques?')
        home["latest_episodes"] = section(r'Derniers?\s+[eé]pisodes?')
    except requests.RequestException:
        pass
    print(f"HOME_JSON: {json.dumps(home, ensure_ascii=False)}")
    sys.exit(0)


def action_catalogue_filter(mod, dl, args):
    """Catalogue filtre par genre (page /catalogue/ avec parametre de genre)."""
    import requests
    domain = mod.DOMAIN
    genre = args.genre.strip()
    if not genre:
        _fail("catalogue-filter requiert --genre")
    items = []
    try:
        url = f"https://{domain}/catalogue/?genre[]={requests.utils.quote(genre)}"
        html = requests.get(url, headers=mod.HEADERS_BASE, timeout=15).text
        items = _cards_from_html(mod, html)
    except requests.RequestException:
        pass
    print(f"CATALOGUE_JSON: {json.dumps(items, ensure_ascii=False)}")
    sys.exit(0)
```

- [ ] **Step 6: Vérifier que le fichier parse (syntaxe Python)**

Run: `python -c "import ast; ast.parse(open('assets/resolver/animesama_resolve.py', encoding='utf-8').read()); print('OK syntaxe')"`
Expected: `OK syntaxe` (si `python` absent du conteneur, sauter — validation manuelle utilisateur).

- [ ] **Step 7: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add assets/resolver/animesama_resolve.py
git commit -m "feat(scraper): slug dans search/planning + actions catalogue-detail/home/catalogue-filter"
```

> **Validation manuelle utilisateur** (à faire sur PC, hors CI) : lancer chaque action et vérifier la sortie JSON, ex. :
> `python assets/resolver/animesama_resolve.py --script <anime_sama.py> --action catalogue-detail --slug one-piece`
> `... --action home` / `... --action catalogue-filter --genre Action`. Ajuster les regex si le HTML diffère.

---
## Task 5 : Modèle `Media` — identité slug, enrichissement anime-sama, retrait AniList

**Files:**
- Modify: `lib/src/domain/models/media.dart`
- Test: `test/domain/media_test.dart`, `test/domain/anime_id_test.dart` (groupes `enrichedWith`/`fromAnimeSama`)

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter dans `test/domain/media_test.dart` (dans `main()`) :

```dart
  group('Media.fromAnimeSama enrichi (identite slug)', () {
    test('id derive du slug, porte slug/synopsis/genres/cover', () {
      final m = Media.fromAnimeSama(
        slug: 'one-piece',
        title: 'One Piece',
        synopsis: 'Un pirate',
        genres: ['Action', 'Aventure'],
        coverUrl: 'https://cdn/c.jpg',
      );
      expect(m.anilistId, animeSamaIdForSlug('one-piece'));
      expect(m.anilistId, greaterThan(0));
      expect(m.animeSamaSlug, 'one-piece');
      expect(m.animeSamaTitle, 'One Piece');
      expect(m.title.preferred, 'One Piece');
      expect(m.description, 'Un pirate');
      expect(m.genres, ['Action', 'Aventure']);
      expect(m.coverUrl, 'https://cdn/c.jpg');
    });

    test('round-trip JSON conserve slug et enrichissement', () {
      final m = Media.fromAnimeSama(
        slug: 'naruto', title: 'Naruto', genres: ['Action']);
      final back = Media.fromJson(m.toJson());
      expect(back.anilistId, m.anilistId);
      expect(back.animeSamaSlug, 'naruto');
      expect(back.genres, ['Action']);
    });
  });
```

Dans `test/domain/anime_id_test.dart`, SUPPRIMER les groupes devenus obsolètes : `Media.fromAnimeSama` (lignes ~41-57, ancien constructeur par titre) et `enrichedWith` (lignes ~99-130). Le groupe `titlesSimilar` peut rester (helper toujours présent).

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/domain/media_test.dart`
Expected: FAIL — `Media.fromAnimeSama` n'accepte pas `slug`, `Media.animeSamaSlug` absent.

- [ ] **Step 3: Implémenter**

Dans `lib/src/domain/models/media.dart` :

a) Ajouter le champ après `animeSamaTitle` (ligne 72) :

```dart
  /// Slug d'URL anime-sama (identite logique). `null` pour un media legacy non
  /// encore migre.
  final String? animeSamaSlug;
```

b) L'ajouter au constructeur (`const Media({...})`) : `this.animeSamaSlug,` après `this.animeSamaTitle,`.

c) Remplacer `factory Media.fromAnimeSama` (lignes 97-106) par :

```dart
  /// Construit un [Media] enrichi depuis une page catalogue **anime-sama**.
  /// L'identite ([anilistId]) est un entier positif stable derive du [slug]
  /// (cf. [animeSamaIdForSlug]).
  factory Media.fromAnimeSama({
    required String slug,
    required String title,
    String? synopsis,
    List<String> genres = const [],
    String? coverUrl,
    String? bannerUrl,
  }) =>
      Media(
        anilistId: animeSamaIdForSlug(slug),
        title: MediaTitle(romaji: title, english: title),
        description: synopsis,
        genres: genres,
        coverUrl: coverUrl,
        bannerUrl: bannerUrl,
        animeSamaTitle: title,
        animeSamaSlug: slug,
      );
```

d) SUPPRIMER `factory Media.fromAniList` (lignes 112-137) et le helper `_airingAtFromAniList` (lignes 141-145) et `factory Media.enrichedWith`... — précisément : supprimer `enrichedWith` (lignes 168-190) et `fromAniList` + `_airingAtFromAniList`.

e) Mettre à jour `withAnimeSamaTitle` (lignes 148-166) pour propager `animeSamaSlug` : ajouter `animeSamaSlug: animeSamaSlug,` dans le `Media(...)` retourné.

f) Dans `toJson` (lignes 193-211), ajouter `'animeSamaSlug': animeSamaSlug,`.

g) Dans `fromJson` (lignes 213-239), ajouter `animeSamaSlug: json['animeSamaSlug'] as String?,`.

- [ ] **Step 4: Lancer les tests pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/domain/media_test.dart test/domain/anime_id_test.dart`
Expected: PASS. (Si d'autres fichiers référencent `fromAniList`/`enrichedWith`, ils seront corrigés dans les tâches de nettoyage AniList — noter les erreurs éventuelles mais ne pas bloquer ce commit si media_test + anime_id_test passent ; sinon voir Step 5.)

> Note : `title_matcher.dart` et `cached_anilist_client.dart` utilisent `fromAniList`/`enrichedWith`. Ils sont SUPPRIMÉS en Task 12. Si la compilation du test échoue à cause d'eux (imports transitifs), c'est attendu — ces fichiers partent en Task 12. Pour garder ce commit vert de façon isolée, exécuter uniquement les deux fichiers de test ci-dessus qui n'importent pas AniList.

- [ ] **Step 5: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/domain/models/media.dart test/domain/media_test.dart test/domain/anime_id_test.dart
git commit -m "feat(media): identite slug + enrichissement anime-sama, retrait fromAniList/enrichedWith"
```

---

## Task 6 : Schéma DB v3 — colonne `animeSamaSlug` + migration

**Files:**
- Modify: `lib/src/data/local/database.dart` (table `MediaTable` ligne 51 ; `schemaVersion` ligne 174 ; `migration` 177-185)
- Modify: `lib/src/data/repositories/media_repository.dart` (mapping `_toCompanion` 24-43, `_fromRow` 45-69)
- Test: `test/data/database_test.dart`, `test/data/media_repository_test.dart`

- [ ] **Step 1: Écrire le test de migration qui échoue**

Ajouter dans `test/data/media_repository_test.dart` (qui utilise déjà `NativeDatabase.memory()`) :

```dart
  test('upsert/get conserve animeSamaSlug', () async {
    final media = Media.fromAnimeSama(slug: 'one-piece', title: 'One Piece');
    await repo.upsertMedia(media);
    final back = await repo.getMedia(media.anilistId);
    expect(back, isNotNull);
    expect(back!.animeSamaSlug, 'one-piece');
  });

  test('watchMedia emet a chaque ecriture', () async {
    final media = Media.fromAnimeSama(slug: 'bleach', title: 'Bleach');
    final emissions = <Media?>[];
    final sub = repo.watchMedia(media.anilistId).listen(emissions.add);
    await repo.upsertMedia(media);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions.last?.animeSamaSlug, 'bleach');
  });
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/data/media_repository_test.dart`
Expected: FAIL — `watchMedia` absent, `animeSamaSlug` non persisté.

- [ ] **Step 3: Implémenter le schéma**

Dans `lib/src/data/local/database.dart` :

a) Ajouter la colonne dans `MediaTable` après `animeSamaTitle` (ligne 51) :

```dart
  /// Slug d'URL anime-sama (identite logique). NULL pour un media legacy non
  /// encore migre. Ajoute en v3.
  TextColumn get animeSamaSlug => text().nullable()();
```

b) Passer `schemaVersion` à `3` (ligne 174).

c) Étendre `onUpgrade` (dans le `MigrationStrategy`) :

```dart
        onUpgrade: (m, from, to) async {
          // v1 -> v2 : ajout de la colonne animeSamaTitle sur media_table.
          if (from < 2) {
            await m.addColumn(mediaTable, mediaTable.animeSamaTitle);
          }
          // v2 -> v3 : ajout de la colonne animeSamaSlug (la re-indexation
          // titre->slug est faite hors migration par SlugMigrationService au
          // 1er boot, cf. Task 8).
          if (from < 3) {
            await m.addColumn(mediaTable, mediaTable.animeSamaSlug);
          }
        },
```

d) Dans `lib/src/data/repositories/media_repository.dart`, ajouter au `_toCompanion` (avant `updatedAt`) : `animeSamaSlug: Value(m.animeSamaSlug),` et au `_fromRow` : `animeSamaSlug: row.animeSamaSlug,`. Ajouter la méthode `watchMedia` après `watchAllMedia` (ligne 93) :

```dart
  /// Stream du media [anilistId] (emet a chaque ecriture le concernant).
  Stream<Media?> watchMedia(int anilistId) {
    return (_db.select(_db.mediaTable)
          ..where((t) => t.anilistId.equals(anilistId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }
```

- [ ] **Step 4: Régénérer le code drift**

Le fichier `database.g.dart` doit être régénéré (nouvelle colonne). Dans le conteneur CI :

Run: `./scripts/flutter-ci.sh pub run build_runner build --delete-conflicting-outputs`
Expected: régénère `lib/src/data/local/database.g.dart` sans erreur.

> Si le script CI ne relaie pas `pub run`, utiliser : `./scripts/flutter-ci.sh "pub get && dart run build_runner build --delete-conflicting-outputs"` — sinon régénérer sur PC (validation utilisateur).

- [ ] **Step 5: Lancer les tests pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/data/media_repository_test.dart test/data/database_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/data/local/database.dart lib/src/data/local/database.g.dart lib/src/data/repositories/media_repository.dart test/data/media_repository_test.dart
git commit -m "feat(db): schema v3 colonne animeSamaSlug + watchMedia + mapping"
```

---
## Task 7 : Streams et ré-indexation dans list/settings repositories

**Files:**
- Modify: `lib/src/data/repositories/list_repository.dart`
- Modify: `lib/src/data/repositories/settings_repository.dart`
- Test: `test/data/list_repository_test.dart`, `test/data/settings_repository_test.dart`

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/data/list_repository_test.dart` (utilise `NativeDatabase.memory()`) :

```dart
  test('watchEntry emet a chaque ecriture', () async {
    final emissions = <ListEntry?>[];
    final sub = repo.watchEntry(42).listen(emissions.add);
    await repo.upsertEntry(ListEntry(
        mediaId: 42, status: ListStatus.current, updatedAt: DateTime.utc(2026)));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions.last?.mediaId, 42);
    expect(emissions.last?.status, ListStatus.current);
  });

  test('reindexMediaId deplace l entree de old vers new', () async {
    await repo.upsertEntry(ListEntry(
        mediaId: -111, status: ListStatus.completed, progress: 5,
        updatedAt: DateTime.utc(2026)));
    await repo.reindexMediaId(-111, 777);
    expect(await repo.getEntry(-111), isNull);
    final moved = await repo.getEntry(777);
    expect(moved, isNotNull);
    expect(moved!.progress, 5);
    expect(moved.status, ListStatus.completed);
  });
```

Dans `test/data/settings_repository_test.dart` :

```dart
  test('watchWithPrefix emet a chaque ecriture de cle prefixee', () async {
    final emissions = <Map<String, String>>[];
    final sub = repo.watchWithPrefix('anime_sama_watched:5:').listen(emissions.add);
    await repo.set('anime_sama_watched:5:1', '3');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions.last['anime_sama_watched:5:1'], '3');
  });

  test('renameKeyPrefix renomme les cles old->new en conservant la valeur', () async {
    await repo.set('anime_sama_watched:-9:1', '4');
    await repo.set('anime_sama_watched:-9:2', '7');
    await repo.renameKeyPrefix('anime_sama_watched:-9:', 'anime_sama_watched:123:');
    expect(await repo.get('anime_sama_watched:-9:1'), isNull);
    expect(await repo.get('anime_sama_watched:123:1'), '4');
    expect(await repo.get('anime_sama_watched:123:2'), '7');
  });
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/data/list_repository_test.dart test/data/settings_repository_test.dart`
Expected: FAIL — méthodes absentes.

- [ ] **Step 3: Implémenter (list_repository)**

Dans `lib/src/data/repositories/list_repository.dart`, ajouter après `getEntry` (ligne 65) :

```dart
  /// Stream de l'entree [mediaId] (emet a chaque ecriture la concernant).
  Stream<ListEntry?> watchEntry(int mediaId) {
    return (_db.select(_db.listEntries)
          ..where((t) => t.mediaId.equals(mediaId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }

  /// Stream des entrees d'un [status] donne.
  Stream<List<ListEntry>> watchEntriesByStatus(ListStatus status) {
    return (_db.select(_db.listEntries)
          ..where((t) => t.status.equals(status.name)))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  /// Stream de toutes les entrees de la bibliotheque.
  Stream<List<ListEntry>> watchAllEntries() {
    return _db.select(_db.listEntries).watch().map(
          (rows) => rows.map(_fromRow).toList(),
        );
  }

  /// Deplace l'entree de liste de [oldId] vers [newId] (migration slug).
  /// Conserve toutes les colonnes ; ne fait rien si aucune entree pour oldId.
  Future<void> reindexMediaId(int oldId, int newId) async {
    final row = await (_db.select(_db.listEntries)
          ..where((t) => t.mediaId.equals(oldId)))
        .getSingleOrNull();
    if (row == null) return;
    await _db.into(_db.listEntries).insertOnConflictUpdate(
          _toCompanion(_fromRow(row).copyWithMediaId(newId)),
        );
    await deleteEntry(oldId);
  }
```

Si `ListEntry` n'a pas de `copyWithMediaId`, l'ajouter dans `lib/src/domain/models/list_entry.dart` :

```dart
  /// Copie de l'entree avec un autre [mediaId] (re-indexation migration slug).
  ListEntry copyWithMediaId(int newMediaId) => ListEntry(
        mediaId: newMediaId,
        status: status,
        progress: progress,
        score: score,
        favorite: favorite,
        notes: notes,
        hiddenFromPlanning: hiddenFromPlanning,
        anilistEntryId: anilistEntryId,
        updatedAt: updatedAt,
        syncedAt: syncedAt,
      );
```

- [ ] **Step 4: Implémenter (settings_repository)**

Dans `lib/src/data/repositories/settings_repository.dart`, ajouter après `entriesWithPrefix` (ligne 99) :

```dart
  /// Stream des paires (cle, valeur) dont la cle commence par [prefix]. Emet a
  /// chaque ecriture dans AppSettings (filtrage cote Dart). Sert a la reactivite
  /// temps reel de la progression par saison (`anime_sama_watched:<id>:*`).
  Stream<Map<String, String>> watchWithPrefix(String prefix) {
    return _db.select(_db.appSettings).watch().map((rows) => {
          for (final r in rows)
            if (r.key.startsWith(prefix)) r.key: r.value,
        });
  }

  /// Renomme toutes les cles commencant par [oldPrefix] en remplacant ce prefixe
  /// par [newPrefix], en conservant la valeur. Sert a la migration slug
  /// (`anime_sama_watched:<old>:*` -> `:<new>:*`). Idempotent.
  Future<void> renameKeyPrefix(String oldPrefix, String newPrefix) async {
    final rows = await _db.select(_db.appSettings).get();
    for (final r in rows) {
      if (r.key.startsWith(oldPrefix)) {
        final newKey = newPrefix + r.key.substring(oldPrefix.length);
        await set(newKey, r.value);
        await delete(r.key);
      }
    }
  }
```

- [ ] **Step 5: Lancer les tests pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/data/list_repository_test.dart test/data/settings_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/data/repositories/list_repository.dart lib/src/data/repositories/settings_repository.dart lib/src/domain/models/list_entry.dart test/data/list_repository_test.dart test/data/settings_repository_test.dart
git commit -m "feat(repo): streams watchEntry/watchEntriesByStatus/watchWithPrefix + reindexMediaId/renameKeyPrefix"
```

---

## Task 8 : `SlugMigrationService` — ré-indexation titre→slug au 1er boot

**Files:**
- Create: `lib/src/services/slug_migration_service.dart`
- Test: `test/services/slug_migration_service_test.dart` (nouveau)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/services/slug_migration_service_test.dart`. Le service prend une fonction de résolution de slug injectable (pour ne PAS toucher au réseau en test) :

```dart
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/domain/logic/anime_id.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/services/slug_migration_service.dart';

void main() {
  late TerebiDatabase db;
  late MediaRepository mediaRepo;
  late ListRepository listRepo;
  late SettingsRepository settings;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    mediaRepo = MediaRepository(db);
    listRepo = ListRepository(db);
    settings = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('reindexe media + entree + progression de old vers slug', () async {
    // Legacy : un media SANS slug (id negatif facon hash titre), suivi, avec
    // progression par saison.
    const oldId = -555;
    await mediaRepo.upsertMedia(Media(
      anilistId: oldId,
      title: const MediaTitle(english: 'One Piece'),
      animeSamaTitle: 'One Piece',
    ));
    await listRepo.upsertEntry(ListEntry(
        mediaId: oldId, status: ListStatus.current, progress: 12,
        updatedAt: DateTime.utc(2026)));
    await settings.set('anime_sama_watched:$oldId:1', '12');

    final service = SlugMigrationService(
      mediaRepo: mediaRepo,
      listRepo: listRepo,
      settings: settings,
      resolveSlug: (title) async => 'one-piece', // stub reseau
    );
    await service.runOnce();

    final newId = animeSamaIdForSlug('one-piece');
    // Ancienne identite videe, nouvelle peuplee avec la progression preservee.
    expect(await mediaRepo.getMedia(oldId), isNull);
    final migrated = await mediaRepo.getMedia(newId);
    expect(migrated, isNotNull);
    expect(migrated!.animeSamaSlug, 'one-piece');
    final entry = await listRepo.getEntry(newId);
    expect(entry?.progress, 12);
    expect(await settings.get('anime_sama_watched:$newId:1'), '12');
    expect(await settings.get('anime_sama_watched:$oldId:1'), isNull);
    // Drapeau pose.
    expect(await settings.get('slug_migration_done'), '1');
  });

  test('runOnce est idempotent (ne rejoue pas si drapeau pose)', () async {
    await settings.set('slug_migration_done', '1');
    var called = 0;
    final service = SlugMigrationService(
      mediaRepo: mediaRepo, listRepo: listRepo, settings: settings,
      resolveSlug: (title) async { called++; return 'x'; },
    );
    await service.runOnce();
    expect(called, 0);
  });

  test('media non resolu -> logue dans le rapport, jamais supprime', () async {
    const oldId = -9;
    await mediaRepo.upsertMedia(Media(
      anilistId: oldId, title: const MediaTitle(english: 'Introuvable'),
      animeSamaTitle: 'Introuvable'));
    final service = SlugMigrationService(
      mediaRepo: mediaRepo, listRepo: listRepo, settings: settings,
      resolveSlug: (title) async => '', // echec de resolution
    );
    await service.runOnce();
    expect(await mediaRepo.getMedia(oldId), isNotNull); // conserve
    final report = await settings.get('slug_migration_report');
    expect(report, contains('Introuvable'));
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/services/slug_migration_service_test.dart`
Expected: FAIL — `SlugMigrationService` inexistant.

- [ ] **Step 3: Implémenter**

Créer `lib/src/services/slug_migration_service.dart` :

```dart
/// Domaine applicatif — re-indexation de la BDD legacy vers l'identite par slug.
///
/// Au 1er boot post-migration v3, chaque media SANS slug est re-resolu vers son
/// slug anime-sama, et son identite (media + entree de liste + progression par
/// saison dans AppSettings) est deplacee de l'ancien id entier vers le nouvel id
/// derive du slug. Best-effort : un media non resolu est LOGUE (jamais
/// supprime). Idempotent via le drapeau `slug_migration_done`.
library;

import '../data/repositories/list_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/logic/anime_id.dart';

/// Resout le slug anime-sama d'un titre (injecte : reseau en prod, stub en test).
/// Retourne '' si non resolu.
typedef SlugResolver = Future<String> Function(String title);

class SlugMigrationService {
  static const _doneKey = 'slug_migration_done';
  static const _reportKey = 'slug_migration_report';

  final MediaRepository mediaRepo;
  final ListRepository listRepo;
  final SettingsRepository settings;
  final SlugResolver resolveSlug;

  const SlugMigrationService({
    required this.mediaRepo,
    required this.listRepo,
    required this.settings,
    required this.resolveSlug,
  });

  /// Lance la re-indexation une seule fois (no-op si deja faite).
  Future<void> runOnce() async {
    if (await settings.get(_doneKey) == '1') return;

    final all = await mediaRepo.getAllMedia();
    final failures = <String>[];

    for (final media in all) {
      // Deja migre (slug present) : rien a faire.
      if (media.animeSamaSlug != null && media.animeSamaSlug!.isNotEmpty) {
        continue;
      }
      final title = media.animeSamaTitle ?? media.title.preferred;
      String slug = '';
      try {
        slug = await resolveSlug(title);
      } catch (_) {
        slug = '';
      }
      if (slug.isEmpty) {
        failures.add(title);
        continue; // conserve tel quel, jamais supprime
      }
      await _reindexOne(media, slug);
    }

    if (failures.isNotEmpty) {
      await settings.set(_reportKey, failures.join('\n'));
    }
    await settings.set(_doneKey, '1');
  }

  /// Deplace un media et sa progression de son ancien id vers l'id derive du slug.
  Future<void> _reindexOne(media, String slug) async {
    final oldId = media.anilistId as int;
    final newId = animeSamaIdForSlug(slug);
    if (oldId == newId) {
      // Meme id : on renseigne juste le slug.
      await mediaRepo.upsertMedia(media.withSlug(slug));
      return;
    }
    // 1) Media : ecrire la nouvelle identite (slug renseigne), effacer l'ancienne.
    await mediaRepo.upsertMedia(media.withSlug(slug).withId(newId));
    await mediaRepo.deleteMedia(oldId);
    // 2) Entree de liste.
    await listRepo.reindexMediaId(oldId, newId);
    // 3) Progression par saison + reglages par media.
    await settings.renameKeyPrefix(
        'anime_sama_watched:$oldId:', 'anime_sama_watched:$newId:');
    await settings.renameKeyPrefix(
        'anime_sama_season:$oldId', 'anime_sama_season:$newId');
    await settings.renameKeyPrefix(
        'anime_sama_lang:$oldId', 'anime_sama_lang:$newId');
    await settings.renameKeyPrefix(
        'new_episode:$oldId', 'new_episode:$newId');
  }
}
```

Ce service requiert deux helpers sur `Media`. Les ajouter dans `lib/src/domain/models/media.dart` (à côté de `withAnimeSamaTitle`) :

```dart
  /// Copie avec le slug anime-sama renseigne (migration).
  Media withSlug(String slug) => _copy(animeSamaSlug: slug);

  /// Copie avec un autre [anilistId] (re-indexation migration slug).
  Media withId(int newId) => _copy(anilistId: newId);
```

Et un `_copy` interne complet (remplace le boilerplate répété de `withAnimeSamaTitle`) :

```dart
  Media _copy({
    int? anilistId,
    String? animeSamaSlug,
    String? animeSamaTitle,
  }) =>
      Media(
        anilistId: anilistId ?? this.anilistId,
        malId: malId,
        title: title,
        format: format,
        status: status,
        episodes: episodes,
        durationMinutes: durationMinutes,
        season: season,
        seasonYear: seasonYear,
        coverUrl: coverUrl,
        bannerUrl: bannerUrl,
        description: description,
        genres: genres,
        averageScore: averageScore,
        nextAiringAt: nextAiringAt,
        nextAiringEpisode: nextAiringEpisode,
        animeSamaTitle: animeSamaTitle ?? this.animeSamaTitle,
        animeSamaSlug: animeSamaSlug ?? this.animeSamaSlug,
      );
```

> Retirer le type dynamique : dans `_reindexOne`, typer le paramètre `Media media`. Import `../domain/models/media.dart` en tête de fichier.

- [ ] **Step 4: Lancer le test pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/services/slug_migration_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/services/slug_migration_service.dart lib/src/domain/models/media.dart test/services/slug_migration_service_test.dart
git commit -m "feat(migration): SlugMigrationService re-indexe titre->slug en preservant la progression"
```

---
## Task 9 : `AnimeSamaCatalogService` — cache-first + revalidation background

**Files:**
- Create: `lib/src/services/animesama_catalog_service.dart`
- Test: `test/services/animesama_catalog_service_test.dart` (nouveau)

Rôle : pour un slug donné, renvoyer immédiatement le `Media` en DB (cache), et si le TTL est expiré, déclencher en tâche de fond un `catalogueDetail(slug)` qui `upsertMedia` — le stream `watchMedia` propage la mise à jour. La fraîcheur est jugée sur `MediaTable.updatedAt` (déjà maintenu par `upsertMedia`).

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/services/animesama_catalog_service_test.dart` :

```dart
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/media_repository.dart';
import 'package:terebi/src/domain/logic/anime_id.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/services/animesama_catalog_service.dart';
import 'package:terebi/src/services/stream_resolver.dart';

void main() {
  late TerebiDatabase db;
  late MediaRepository mediaRepo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    mediaRepo = MediaRepository(db);
  });
  tearDown(() => db.close());

  test('revalidate ecrit le detail scrappe en DB', () async {
    final service = AnimeSamaCatalogService(
      mediaRepo: mediaRepo,
      fetchDetail: (slug) async => const AnimeSamaDetail(
        slug: 'one-piece', title: 'One Piece',
        synopsis: 'Un pirate', genres: ['Action'],
        cover: 'https://cdn/c.jpg'),
    );
    await service.revalidate('one-piece');
    final id = animeSamaIdForSlug('one-piece');
    final m = await mediaRepo.getMedia(id);
    expect(m, isNotNull);
    expect(m!.description, 'Un pirate');
    expect(m.genres, ['Action']);
    expect(m.animeSamaSlug, 'one-piece');
  });

  test('watchDetail emet l etat DB puis la revalidation', () async {
    // Pre-remplit un cache perime (updatedAt ancien).
    final id = animeSamaIdForSlug('bleach');
    await mediaRepo.upsertMedia(
        Media.fromAnimeSama(slug: 'bleach', title: 'Bleach (cache)'));
    var fetchCount = 0;
    final service = AnimeSamaCatalogService(
      mediaRepo: mediaRepo,
      fetchDetail: (slug) async {
        fetchCount++;
        return const AnimeSamaDetail(
            slug: 'bleach', title: 'Bleach', synopsis: 'frais');
      },
      ttl: Duration.zero, // toujours perime -> revalide
    );
    final emissions = <Media?>[];
    final sub = service.watchDetail('bleach').listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await sub.cancel();
    expect(fetchCount, greaterThanOrEqualTo(1));
    // La derniere emission reflete la revalidation.
    expect(emissions.last?.description, 'frais');
    expect(emissions.first?.anilistId, id); // cache d'abord
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/services/animesama_catalog_service_test.dart`
Expected: FAIL — `AnimeSamaCatalogService` inexistant.

- [ ] **Step 3: Implémenter**

Créer `lib/src/services/animesama_catalog_service.dart` :

```dart
/// Domaine applicatif — catalogue anime-sama en cache-first.
///
/// La DB est un CACHE : [watchDetail] emet immediatement l'etat DB (meme
/// perime) et declenche, si le TTL est depasse, une revalidation en tache de
/// fond (scrape `catalogue-detail`) qui reecrit la DB. Le stream Drift
/// [MediaRepository.watchMedia] propage alors la mise a jour a l'UI.
library;

import '../data/repositories/media_repository.dart';
import '../domain/logic/anime_id.dart';
import '../domain/models/media.dart';
import 'stream_resolver.dart';

/// Recupere le detail enrichi d'un slug (reseau en prod, stub en test).
typedef DetailFetcher = Future<AnimeSamaDetail?> Function(String slug);

class AnimeSamaCatalogService {
  final MediaRepository mediaRepo;
  final DetailFetcher fetchDetail;

  /// Duree de fraicheur du cache : au-dela, [watchDetail] revalide en fond.
  final Duration ttl;

  const AnimeSamaCatalogService({
    required this.mediaRepo,
    required this.fetchDetail,
    this.ttl = const Duration(hours: 12),
  });

  /// Stream du media pour [slug] : etat DB immediat + revalidation background
  /// si le cache est absent ou perime.
  Stream<Media?> watchDetail(String slug) {
    final id = animeSamaIdForSlug(slug);
    // Revalidation background lancee au moment de l'abonnement (non bloquante).
    _maybeRevalidate(slug, id);
    return mediaRepo.watchMedia(id);
  }

  /// Force un scrape `catalogue-detail` et ecrit le resultat en DB.
  Future<void> revalidate(String slug) async {
    final detail = await fetchDetail(slug);
    if (detail == null) return;
    final existing = await mediaRepo.getMedia(animeSamaIdForSlug(slug));
    // Conserve le titre affichable existant si le detail n'en fournit pas.
    final media = Media.fromAnimeSama(
      slug: slug,
      title: detail.title.isNotEmpty
          ? detail.title
          : (existing?.animeSamaTitle ?? slug),
      synopsis: detail.synopsis ?? existing?.description,
      genres: detail.genres.isNotEmpty ? detail.genres : (existing?.genres ?? const []),
      coverUrl: detail.cover ?? existing?.coverUrl,
      bannerUrl: detail.banner ?? existing?.bannerUrl,
    );
    await mediaRepo.upsertMedia(media);
  }

  /// Revalide si le cache est absent ou plus vieux que [ttl].
  Future<void> _maybeRevalidate(String slug, int id) async {
    final existing = await mediaRepo.getMedia(id);
    final stale = existing == null ||
        ttl == Duration.zero ||
        DateTime.now().toUtc().difference(await _updatedAt(id)) > ttl;
    if (stale) {
      // Fire-and-forget : ne bloque pas l'abonnement au stream.
      // ignore: unawaited_futures
      revalidate(slug);
    }
  }

  /// updatedAt du media en DB (epoch 0 si absent -> force la revalidation).
  Future<DateTime> _updatedAt(int id) async {
    final m = await mediaRepo.getMedia(id);
    if (m == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return mediaRepo.updatedAtOf(id);
  }
}
```

Cela requiert un accès à `updatedAt`. Ajouter dans `lib/src/data/repositories/media_repository.dart` :

```dart
  /// Date de derniere ecriture du media [anilistId] (epoch 0 si absent). Sert au
  /// calcul de fraicheur du cache (revalidation).
  Future<DateTime> updatedAtOf(int anilistId) async {
    final row = await (_db.select(_db.mediaTable)
          ..where((t) => t.anilistId.equals(anilistId)))
        .getSingleOrNull();
    return row?.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
```

> Simplification : dans `_maybeRevalidate`, remplacer le double `getMedia`/`_updatedAt` par un seul appel — récupérer `updatedAtOf(id)` et tester `existing == null` via `getMedia` une seule fois. L'implémenteur peut factoriser tant que le comportement (revalide si absent OU périmé OU ttl zéro) est conservé et que les tests passent.

- [ ] **Step 4: Lancer le test pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/services/animesama_catalog_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/services/animesama_catalog_service.dart lib/src/data/repositories/media_repository.dart test/services/animesama_catalog_service_test.dart
git commit -m "feat(cache): AnimeSamaCatalogService cache-first + revalidation background"
```

---
## Task 10 : Câblage providers — StreamProviders, catalogue service, migration au boot

**Files:**
- Modify: `lib/src/app/providers.dart`
- Modify: `lib/main.dart` (lancement de la migration au boot — repérer `bootstrap`/`runApp`)
- Test: manuel (câblage) + `./scripts/flutter-ci.sh test` global à la fin.

Cette tâche ne suit pas un cycle TDD unitaire (câblage d'injection) ; elle est validée par la compilation + la suite de tests globale et la validation runtime utilisateur.

- [ ] **Step 1: Ajouter les providers du catalogue anime-sama**

Dans `lib/src/app/providers.dart`, ajouter (après `animeSamaResolverProvider`) :

```dart
/// Service catalogue anime-sama (cache-first + revalidation background).
final animeSamaCatalogServiceProvider =
    FutureProvider<AnimeSamaCatalogService>((ref) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  return AnimeSamaCatalogService(
    mediaRepo: ref.watch(mediaRepositoryProvider),
    fetchDetail: (slug) => resolver.catalogueDetail(slug: slug),
  );
});

/// Stream cache-first du media enrichi pour un slug anime-sama.
final animeSamaDetailProvider =
    StreamProvider.family<Media?, String>((ref, slug) async* {
  final service = await ref.watch(animeSamaCatalogServiceProvider.future);
  yield* service.watchDetail(slug);
});

/// Sections de l'accueil anime-sama (classiques + derniers episodes).
final animeSamaHomeProvider = FutureProvider<AnimeSamaHome>((ref) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  try {
    return await resolver.home();
  } catch (_) {
    return const AnimeSamaHome();
  }
});

/// Catalogue filtre par genre.
final animeSamaByGenreProvider =
    FutureProvider.family<List<AnimeSamaCatalogueItem>, String>((ref, genre) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  try {
    return await resolver.catalogueByGenre(genre: genre);
  } catch (_) {
    return const [];
  }
});
```

Ajouter les imports nécessaires en tête :

```dart
import '../services/animesama_catalog_service.dart';
import '../services/slug_migration_service.dart';
import '../domain/models/media.dart';
```

- [ ] **Step 2: Convertir les providers de données en streams**

Remplacer `hasProgressProvider` (lignes 72-77) par une version stream branchée sur les entrées + la progression par saison :

```dart
/// `true` si l'anime [mediaId] a une progression locale. Reactif : re-emet des
/// qu'une entree de liste ou une cle `anime_sama_watched:<id>:*` change.
final hasProgressProvider = StreamProvider.family<bool, int>((ref, mediaId) {
  final listRepo = ref.watch(listRepositoryProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  return Rx.combineLatest2(
    listRepo.watchEntry(mediaId),
    settings.watchWithPrefix('anime_sama_watched:$mediaId:'),
    (ListEntry? entry, Map<String, String> watched) {
      if ((entry?.progress ?? 0) > 0) return true;
      return watched.values.any((v) => (int.tryParse(v) ?? 0) > 0);
    },
  );
});
```

> `Rx.combineLatest2` vient de `rxdart`. Si `rxdart` n'est pas déjà une dépendance, l'ajouter : `./scripts/flutter-ci.sh pub add rxdart`. Alternative sans dépendance : implémenter la combinaison via un `StreamController` maison, mais `rxdart` est le plus simple et idiomatique avec Drift.

Ajouter l'import `import 'package:rxdart/rxdart.dart';` et `import '../domain/models/list_entry.dart';`.

- [ ] **Step 3: Lancer la migration slug au boot**

Dans `lib/main.dart`, après l'ouverture de la base et la création du `ProviderContainer`/`ProviderScope` (repérer où `databaseProvider` est surchargé), lancer la migration une fois, en tâche de fond (non bloquant pour l'UI) :

```dart
  // Re-indexation legacy titre->slug (idempotente, 1 seule fois). Non bloquant.
  Future<void> _runSlugMigration(ProviderContainer container) async {
    final resolver = await container.read(animeSamaResolverProvider.future);
    final service = SlugMigrationService(
      mediaRepo: container.read(mediaRepositoryProvider),
      listRepo: container.read(listRepositoryProvider),
      settings: container.read(settingsRepositoryProvider),
      resolveSlug: (title) async {
        try {
          final items = await resolver.search(query: title);
          if (items.isEmpty) return '';
          // Choisit le meilleur resultat (titleMatchScore) et prend son slug.
          var best = items.first;
          var bestScore = -1;
          for (final it in items) {
            final s = titleMatchScore(title, it.title);
            if (s > bestScore) { bestScore = s; best = it; }
          }
          return best.slug;
        } catch (_) {
          return '';
        }
      },
    );
    await service.runOnce();
  }
```

Et l'appeler après `runApp` (fire-and-forget) avec le container de la `ProviderScope`. Import : `import 'src/services/slug_migration_service.dart';` et `import 'src/domain/logic/anime_id.dart';`.

> Détail d'accès au container : si `main.dart` utilise `ProviderScope` sans container explicite, créer un `ProviderContainer()` partagé passé en `parent`/`overrides`, OU déclencher la migration depuis un provider `ref` au premier build de l'AppShell. L'implémenteur choisit selon la structure réelle de `main.dart` (à lire) ; l'objectif est : migration lancée une fois, non bloquante, après l'ouverture DB.

- [ ] **Step 4: Compilation + suite globale**

Run: `./scripts/flutter-ci.sh test`
Expected: la suite compile ; les tests hors AniList passent. (Les tests/fichiers AniList sont supprimés en Task 13 — s'ils cassent la compilation ici, faire la Task 13 AVANT de committer cette tâche, ou committer 10+13 ensemble.)

- [ ] **Step 5: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/app/providers.dart lib/main.dart pubspec.yaml
git commit -m "feat(providers): stream catalogue anime-sama, hasProgress reactif, migration slug au boot"
```

---

## Task 11 : Dashboard — rangées anime-sama, suppression rangées AniList

**Files:**
- Modify: `lib/src/ui/pages/home_page.dart`
- Test: `test/ui/widget_test.dart` (monte HomePage avec providers surchargés)

- [ ] **Step 1: Écrire/adapter le test widget**

Dans `test/ui/widget_test.dart`, ajouter un test qui monte `HomePage` dans un `ProviderScope` surchargeant `animeSamaHomeProvider` avec des classiques/derniers factices et vérifie que les titres de rangées « Les classiques » et « Derniers épisodes ajoutés » apparaissent :

```dart
  testWidgets('HomePage affiche les rangees anime-sama', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        animeSamaHomeProvider.overrideWith((ref) async => const AnimeSamaHome(
              classics: [
                AnimeSamaCatalogueItem(
                    title: 'Naruto', url: '/catalogue/naruto/', slug: 'naruto'),
              ],
              latestEpisodes: [
                AnimeSamaCatalogueItem(
                    title: 'One Piece', url: '/catalogue/one-piece/',
                    slug: 'one-piece'),
              ],
            )),
        // Rangees locales vides pour isoler le test.
      ],
      child: const MaterialApp(home: Scaffold(body: HomePage())),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Les classiques'), findsOneWidget);
    expect(find.text('Derniers episodes ajoutes'), findsOneWidget);
  });
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/ui/widget_test.dart`
Expected: FAIL — rangées inexistantes / providers AniList référencés.

- [ ] **Step 3: Implémenter**

Dans `lib/src/ui/pages/home_page.dart` :

a) SUPPRIMER les providers `_trendingProvider` (83-90), `_popularProvider` (92-99), `_byGenreProvider` (122-130), `_seasonPreviewProvider` (244-254) et l'import/usage de `aniListClientProvider`.

b) Remplacer `_recentlyReleasedProvider` (64-81) — il utilisait `titleMatcherProvider`. Nouvelle version basée sur le planning + slug + catalogue service :

```dart
/// « Sortis du moment » : planning anime-sama de la semaine, resolu en Media via
/// le slug (cache DB + enrichissement). Best-effort, borne.
final _recentlyReleasedProvider = FutureProvider<List<Media>>((ref) async {
  try {
    final items = await ref.watch(animeSamaPlanningProvider.future);
    final result = <Media>[];
    final seen = <int>{};
    for (final it in items.take(15)) {
      final slug = it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);
      if (slug.isEmpty) continue;
      final id = animeSamaIdForSlug(slug);
      if (!seen.add(id)) continue;
      // Cache DB si dispo, sinon carte minimale (revalidation en fond via fiche).
      final cached = await ref.watch(mediaRepositoryProvider).getMedia(id);
      result.add(cached ??
          Media.fromAnimeSama(slug: slug, title: it.title));
      if (result.length >= 12) break;
    }
    return result;
  } catch (_) {
    return const [];
  }
});

/// Convertit une liste d'items catalogue anime-sama en Media (cache-first).
Future<List<Media>> _itemsToMedia(
    Ref ref, List<AnimeSamaCatalogueItem> items) async {
  final repo = ref.watch(mediaRepositoryProvider);
  final result = <Media>[];
  final seen = <int>{};
  for (final it in items) {
    final slug = it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);
    if (slug.isEmpty) continue;
    final id = animeSamaIdForSlug(slug);
    if (!seen.add(id)) continue;
    final cached = await repo.getMedia(id);
    result.add(cached ??
        Media.fromAnimeSama(
            slug: slug, title: it.title, coverUrl: it.cover, genres: it.genres));
  }
  return result;
}

/// « Les classiques » (home anime-sama).
final _classicsProvider = FutureProvider<List<Media>>((ref) async {
  final home = await ref.watch(animeSamaHomeProvider.future);
  return _itemsToMedia(ref, home.classics);
});

/// « Derniers episodes ajoutes » (home anime-sama).
final _latestProvider = FutureProvider<List<Media>>((ref) async {
  final home = await ref.watch(animeSamaHomeProvider.future);
  return _itemsToMedia(ref, home.latestEpisodes);
});
```

c) Adapter `_byGenreProvider` (découverte) pour utiliser `animeSamaByGenreProvider` :

```dart
final _byGenreProvider =
    FutureProvider.family<List<Media>, String>((ref, genre) async {
  final items = await ref.watch(animeSamaByGenreProvider(genre).future);
  return _itemsToMedia(ref, items);
});
```

d) Dans `build`, remplacer les rangées : garder « En ce moment », « Continuer à regarder », « Sortis du moment » ; remplacer Tendances/Populaires/Saison courante par :

```dart
        _MediaRow(title: 'Les classiques', provider: _classicsProvider,
            excludeLibrary: true),
        _MediaRow(title: 'Derniers episodes ajoutes', provider: _latestProvider,
            excludeLibrary: true),
```

et conserver la boucle `_GenreRow` (qui utilise désormais le `_byGenreProvider` anime-sama).

e) Simplifier `_libraryFilterProvider` : l'identité étant unifiée par slug, l'exclusion peut se limiter au `Set<int>` d'ids (retirer la partie titre normalisé). Garder la signature pour compat, mais `titles` peut rester (inoffensif) — l'implémenteur peut simplifier si trivial.

f) Ajouter les imports : `import '../../domain/logic/anime_id.dart';` et `import '../../services/stream_resolver.dart';` (pour `AnimeSamaCatalogueItem`). Retirer les imports AniList devenus inutiles.

- [ ] **Step 4: Lancer le test pour vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/ui/widget_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/ui/pages/home_page.dart test/ui/widget_test.dart
git commit -m "feat(accueil): rangees anime-sama (classiques/derniers/par genre), suppression rangees AniList"
```

---
## Task 12 : Fiche détail — enrichissement via catalogue-detail, purge sans `invalidate`

**Files:**
- Modify: `lib/src/ui/pages/media_detail_page.dart`
- Test: manuel (page complexe) + suite globale.

- [ ] **Step 1: Rebrancher le média détail sur le stream slug**

Dans `media_detail_page.dart`, `_mediaDetailProvider` (lignes 29-70) appelle aujourd'hui `titleMatcherProvider.resolve` et `aniListClientProvider.mediaDetail`. Le remplacer par une résolution basée slug :

```dart
/// Media affiche par la fiche. Cache-first via le slug quand il est connu ;
/// sinon on lit le cache DB par id. Reactif (StreamProvider).
final _mediaDetailProvider =
    StreamProvider.family<Media?, ({int id, String? title})>((ref, arg) async* {
  final repo = ref.watch(mediaRepositoryProvider);
  // 1) Le media est-il deja en cache (par id) ? On a alors son slug.
  final cached = await repo.getMedia(arg.id);
  final slug = cached?.animeSamaSlug;
  if (slug != null && slug.isNotEmpty) {
    // Cache-first + revalidation background via le service catalogue.
    final service = await ref.watch(animeSamaCatalogServiceProvider.future);
    yield* service.watchDetail(slug);
    return;
  }
  // 2) Pas de slug connu : on suit simplement le cache par id (peut etre null).
  yield* repo.watchMedia(arg.id);
});
```

- [ ] **Step 2: Rebrancher les saisons sur le titre anime-sama du média**

Là où la page watch `animeSamaResolvedTitleProvider` (ligne ~798) pour obtenir le titre à passer à `animeSamaSeasonsProvider`, utiliser directement `media.animeSamaTitle` (désormais toujours présent pour un média anime-sama). Remplacer la résolution AniList→titre par :

```dart
    final searchTitle = media.animeSamaTitle ?? media.title.preferred;
    // puis : ref.watch(animeSamaSeasonsProvider(searchTitle))
```

Supprimer l'usage de `animeSamaResolvedTitleProvider` dans cette page.

- [ ] **Step 3: Purge sans cascade d'`invalidate`**

Remplacer la méthode `_purge` (lignes 507-566) : conserver les suppressions DB, RETIRER tous les `ref.invalidate(...)` (les streams propagent). Version cible :

```dart
  Future<void> _purge(BuildContext context, WidgetRef ref, int id, String? t) async {
    final settings = ref.read(settingsRepositoryProvider);
    // Ecritures DB : les StreamProviders (media/entree/progression) re-emettent
    // automatiquement. Aucune invalidation manuelle necessaire.
    await ref.read(listRepositoryProvider).deleteEntry(id);
    await ref.read(mediaRepositoryProvider).deleteMedia(id);
    await settings.deleteWithPrefix('anime_sama_watched:$id:');
    await settings.delete('anime_sama_season:$id');
    await settings.delete('anime_sama_lang:$id');
    await settings.delete('new_episode:$id');
    if (t != null) {
      await settings.delete('anime_sama_nomatch:${normalizeAnimeTitle(t)}');
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
```

> Retirer les imports/refs devenus inutiles (`entriesByStatusProvider`, `countByStatusProvider`, `animeSamaResolvedTitleProvider`, `animeSamaTotalEpisodesProvider`) SI plus référencés ailleurs dans le fichier. `entriesByStatusProvider`/`countByStatusProvider` sont définis dans `library_page.dart` : leur réactivité est traitée dans la Task 13 (conversion en stream). Ici, seulement retirer les `invalidate`.

- [ ] **Step 4: Retirer l'usage de `aniListClientProvider` (ligne 53)**

La fiche n'appelle plus AniList. Supprimer l'import et toute référence résiduelle à `aniListClientProvider`/`titleMatcherProvider` dans ce fichier.

- [ ] **Step 5: Compilation + suite globale**

Run: `./scripts/flutter-ci.sh test`
Expected: compile ; tests passent (après Task 13 pour la suppression complète AniList).

- [ ] **Step 6: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add lib/src/ui/pages/media_detail_page.dart
git commit -m "feat(fiche): enrichissement via catalogue-detail (slug), purge reactive sans invalidate"
```

---

## Task 13 : Suppression du code AniList/Jikan + conversions stream restantes + health-check

**Files:**
- Delete: `lib/src/data/remote/anilist_client.dart`, `lib/src/data/remote/cached_anilist_client.dart`, `lib/src/data/remote/jikan_client.dart`, `lib/src/data/remote/request_queue.dart`, `lib/src/services/title_matcher.dart`
- Delete: `test/data/anilist_client_test.dart`, `test/data/cached_anilist_client_test.dart`, `test/data/jikan_client_test.dart`, `test/data/request_queue_test.dart`
- Modify: `lib/src/app/providers.dart` (retrait des providers AniList/Jikan + health-check), `lib/src/ui/pages/library_page.dart` (ligne 1053 + conversion stream), toute réf. résiduelle.

- [ ] **Step 1: Supprimer les fichiers AniList/Jikan et leurs tests**

```bash
git rm lib/src/data/remote/anilist_client.dart \
       lib/src/data/remote/cached_anilist_client.dart \
       lib/src/data/remote/jikan_client.dart \
       lib/src/data/remote/request_queue.dart \
       lib/src/services/title_matcher.dart \
       test/data/anilist_client_test.dart \
       test/data/cached_anilist_client_test.dart \
       test/data/jikan_client_test.dart \
       test/data/request_queue_test.dart
```

- [ ] **Step 2: Nettoyer `providers.dart`**

Retirer : imports lignes 12-15 (`anilist_client`, `cached_anilist_client`, `jikan_client`, `request_queue`), import ligne 35 (`title_matcher`) ; providers `requestQueueProvider` (86), `rawAniListClientProvider` (88-90), `aniListClientProvider` (94-100), `jikanClientProvider` (102-104), `titleMatcherProvider` (305-311), `animeSamaResolvedTitleProvider` (183-214).

`metaCacheRepositoryProvider` (79-81) : CONSERVER (réutilisé). `MediaRepository`/autres inchangés.

Remplacer la sonde réseau du `healthServiceProvider` (lignes 334-345, qui tape `graphql.anilist.co`) par un ping anime-sama :

```dart
    networkOk: () async {
      try {
        final resp = await httpClient
            .get(Uri.parse('https://anime-sama.to/'))
            .timeout(const Duration(seconds: 8));
        return resp.statusCode < 500;
      } catch (_) {
        return false;
      }
    },
```

- [ ] **Step 3: Convertir `entriesByStatusProvider`/`countByStatusProvider` en streams**

Dans `lib/src/ui/pages/library_page.dart`, ces deux `FutureProvider` (lignes 52-62) appellent `_computeGrouped(ref)` (qui utilise `hasAnyProgress`). Les convertir en `StreamProvider` branchés sur `listRepository.watchAllEntries()` + la progression, pour que la biblio se rafraîchisse en temps réel. Version cible :

```dart
/// Toutes les entrees regroupees par statut EFFECTIF, en flux temps reel.
final _groupedEntriesProvider =
    StreamProvider<Map<ListStatus, List<ListEntry>>>((ref) {
  final listRepo = ref.watch(listRepositoryProvider);
  return listRepo.watchAllEntries().asyncMap((entries) async {
    return _computeGroupedFrom(ref, entries);
  });
});

final countByStatusProvider = StreamProvider<Map<ListStatus, int>>((ref) {
  return ref.watch(_groupedEntriesProvider.stream).map(
        (grouped) => {for (final e in grouped.entries) e.key: e.value.length},
      );
});

final entriesByStatusProvider =
    StreamProvider.family<List<ListEntry>, ListStatus>((ref, status) {
  return ref.watch(_groupedEntriesProvider.stream).map(
        (grouped) => grouped[status] ?? const [],
      );
});
```

Adapter `_computeGrouped` en `_computeGroupedFrom(ref, entries)` (prend la liste déjà lue au lieu de la relire). Retirer la ligne 1053 (`aniListClientProvider`) et son usage.

> Les consommateurs de `entriesByStatusProvider(...)`/`countByStatusProvider` doivent utiliser `.when(...)` sur un `AsyncValue` (déjà le cas avec FutureProvider) — l'API `AsyncValue` est identique pour `StreamProvider`, donc peu ou pas de changement côté widgets. `_continueWatchingProvider` (home) qui fait `.future` : remplacer par lecture directe `ref.watch(entriesByStatusProvider(...).future)` fonctionne aussi avec StreamProvider (première valeur). Vérifier les sites d'appel.

- [ ] **Step 4: Chercher les références résiduelles**

Run: `git grep -n -E "anilist_client|cached_anilist|jikan|request_queue|TitleMatcher|aniListClientProvider|animeSamaResolvedTitleProvider|AniListApi|fromAniList|enrichedWith" -- lib test`
Expected: aucun résultat (sinon corriger chaque site).

- [ ] **Step 5: Suite globale**

Run: `./scripts/flutter-ci.sh test`
Expected: PASS (toute la suite, sans les tests AniList supprimés).

- [ ] **Step 6: Commit**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add -A
git commit -m "refactor: suppression complete AniList/Jikan, biblio en streams, health-check anime-sama"
```

---

## Task 14 : Vérification finale

**Files:** aucun (contrôle qualité global).

- [ ] **Step 1: Analyse statique**

Run: `./scripts/flutter-ci.sh analyze`
Expected: `No issues found!` (lib + test).

- [ ] **Step 2: Suite de tests complète**

Run: `./scripts/flutter-ci.sh test`
Expected: tous les tests PASS.

- [ ] **Step 3: Vérifier l'absence de toute trace AniList**

Run: `git grep -n -iE "anilist|jikan" -- lib`
Expected: aucune occurrence fonctionnelle (au plus des commentaires historiques à nettoyer). Nettoyer les commentaires résiduels (`media.dart` en-tête « issu d'AniList/Jikan », `database.dart` « source AniList/Jikan », etc.).

- [ ] **Step 4: Commit du nettoyage de commentaires (si besoin)**

```bash
git checkout -- pubspec.lock 2>/dev/null || true
git add -A
git commit -m "docs: nettoyage des references AniList/Jikan dans les commentaires"
```

- [ ] **Step 5: Validation runtime par l'utilisateur (hors CI, sur PC)**

Checklist à faire tourner par l'utilisateur (non reproductible ici) :
- [ ] Les 3 actions Python renvoient un JSON valide : `catalogue-detail --slug one-piece`, `home`, `catalogue-filter --genre Action`.
- [ ] Accueil : rangées « Les classiques », « Derniers episodes ajoutes », « Sortis du moment », et une rangée par genre favori s'affichent avec images CDN.
- [ ] Ouvrir un anime : synopsis + genres + image proviennent d'anime-sama ; les bonnes saisons se chargent (plus de Dragon Ball → Heroes).
- [ ] Progression : marquer un épisode vu → l'accueil/fiche se mettent à jour SANS relancer l'app (temps réel).
- [ ] Purge : retirer un anime → disparaît immédiatement de la biblio/accueil sans relance.
- [ ] Migration : au 1er lancement, la progression des animes suivis est conservée sous la nouvelle identité. Consulter `slug_migration_report` (clé AppSettings) pour les échecs éventuels → fournir la BDD pour réparation manuelle si nécessaire.

---

## Récapitulatif de la couverture (self-review)

| Section spec | Tâche(s) |
|---|---|
| S1 Identité slug (1a) | Task 1, 5, 6 |
| S2 Scraper Python (search+slug, detail, home, filter, planning+slug) | Task 3 (parseurs/contrat), Task 4 (Python) |
| S3 DB=cache + streams temps réel | Task 6 (watchMedia), 7 (watch* list/settings), 9 (catalog service), 10 (providers stream), 13 (biblio stream) |
| S4 Dashboard + nettoyage AniList | Task 11 (rangées), 12 (fiche), 13 (suppression) |
| S5a Migration | Task 6 (schéma), 8 (SlugMigrationService), 10 (boot) |
| S5b Tests | chaque tâche (TDD) + Task 14 |
| S5c Risques | health-check (13), best-effort migration (8), cache-first (9) |
| AniSkip conservé | inchangé (aucune tâche de suppression le touche) |
