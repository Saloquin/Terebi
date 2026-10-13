# Audit Technique du Projet

> **Projet :** Terebi (Client Desktop & TV Dart/Flutter pour Anime-Sama)  
> **Date de l'audit :** 12 Octobre 2026  
> **Périmètre audité :** Code source complet (`lib/`, `test/`, `pubspec.yaml`, architecture Drift, Riverpod, MediaKit).  
> **Méthodologie :** Analyse statique du code source brut, métriques de complexité, inspection des flux asynchrones, du scraping et de la persistance locale.

---

## 🚨 Duplications de code détectées

L'analyse du code source met en lumière plusieurs zones critiques de duplication stricte et de redondance conceptuelle, particulièrement entre les déclinaisons Desktop et Android TV, ainsi qu'entre couches contrôleurs et pages UI.

### 1. Code mort et duplication massive : `PlayerController` vs `PlayerPage`
- **Fichiers concernés :** 
  - [`lib/src/controllers/player/player_controller.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/controllers/player/player_controller.dart) (484 lignes)
  - [`lib/src/controllers/player/player_state.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/controllers/player/player_state.dart) (96 lignes)
  - [`lib/src/ui/pages/player_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/player_page.dart) (1 994 lignes)
  - [`lib/src/app/providers.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/app/providers.dart#L588-L593)
- **Constat :**
  Un `PlayerController` complet (basé sur Riverpod `Notifier<PlayerState>`) a été conçu avec gestion des abonnements aux flux MediaKit (`position`, `duration`, `completed`), debounce de seek, throttling d'écriture de la position, et gestion d'auto-play.
  **Cependant, `PlayerPage` n'utilise absolument pas ce contrôleur ni `playerControllerProvider`.**
  À la place, `_PlayerPageState` (dans `player_page.dart`) réimplémente de façon impérative l'intégralité de cette machine à états :
  - `Player` et `VideoController(hwdec: 'no')` instanciés localement en `late final` (lignes 68-78) ;
  - `_subscribePlayerStreams()` (lignes 166-178) duplique les écoutes de flux ;
  - `_maybePersistPosition()` et `_onEpisodeCompleted()` dupliquent la logique de persistance et de fin d'épisode ;
  - Les timers de debounce (`_seekDebounce`) et de compte à rebours (`_autoPlayTimer`) sont déclarés en doublon.
- **Impact :** Près de 600 lignes de code mort dans `controllers/player/`, pendant que la vue UI accumule 1 994 lignes en mélangeant état métier, persistance et rendu.

---

### 2. Duplication systématique Desktop vs Android TV
Au lieu d'extraire des widgets partagés et des contrôleurs communs, les écrans TV ont été développés par duplication de code ("copy-paste-adapt") :

#### A. Fiches de détail : `media_detail_page.dart` vs `media_detail_page_tv.dart`
- **Fichiers :** [`lib/src/ui/pages/media_detail_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/media_detail_page.dart#L30-L79) et [`lib/src/ui/tv/media_detail_page_tv.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/tv/media_detail_page_tv.dart#L25-L64)
- **Preuve flagrante :** Le fichier TV comporte même le commentaire :
  ```dart
  // Providers locaux (copiés depuis media_detail_page.dart — non exportés)
  ```
- Les providers `_resolvedSlugProvider` (recherche du meilleur slug par correspondance de titre) et `_mediaDetailProvider` (`StreamProvider.family` orchestrant le cache local et la revalidation) sont copiés-collés caractère pour caractère dans les deux fichiers.

#### B. Catalogue : `catalog_page.dart` vs `catalog_page_tv.dart`
- **Fichiers :** [`lib/src/ui/pages/catalog_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/catalog_page.dart#L29-L73) et [`lib/src/ui/tv/catalog_page_tv.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/tv/catalog_page_tv.dart#L19-L34)
- Duplication à l'identique de :
  - `_searchResultsProvider` (`FutureProvider.family` pour interroger `resolver.search`) ;
  - La fonction helper `_slugOf(AnimeSamaCatalogueItem it)` ;
  - Le chargement et la bascule du toggle de persistance `SettingsKeys.catalogHideLibrary` ;
  - Le timer de debounce de 600 ms sur le champ de recherche textuelle.

#### C. Bibliothèque : `library_page.dart` vs `library_page_tv.dart`
- **Fichiers :** [`lib/src/ui/pages/library_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/library_page.dart#L33-L50) et [`lib/src/ui/tv/library_page_tv.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/tv/library_page_tv.dart#L15-L31)
- Les listes et maps statiques `_statusOrder` et `_statusLabels` sont dupliquées mot pour mot.

---

### 3. Redondance des libellés et comptages `ListStatus`
- **Fichiers concernés :**
  - [`lib/src/domain/models/list_status.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/domain/models/list_status.dart)
  - [`lib/src/ui/pages/library_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/library_page.dart#L42-L50)
  - [`lib/src/ui/tv/library_page_tv.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/tv/library_page_tv.dart#L24-L31)
  - [`lib/src/ui/pages/media_detail_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/media_detail_page.dart#L560-L566)
  - [`lib/src/ui/pages/catalog_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/catalog_page.dart#L670-L676)
  - [`lib/src/ui/tv/catalog_page_tv.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/tv/catalog_page_tv.dart#L623-L625)
  - [`lib/src/ui/pages/stats_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/stats_page.dart#L345-L347)
- **Constat :**
  L'enum `ListStatus` ne dispose d'aucun helper d'affichage (`label`, `order`, `color`). Par conséquent, 6 fichiers UI différents réécrivent leur propre map de traduction française (`'En cours'`, `'Planifié'`, `'Terminé'`, `'Revisionnage'`, `'En pause'`, `'Abandonné'`).
- **Comptage par statut implémenté 3 fois avec des logiques divergentes :**
  1. `ListRepository.countByStatus()` ([`list_repository.dart:113`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/data/repositories/list_repository.dart#L113-L121)) : boucle sur les lignes brutes de la base de données.
  2. `StatsService.countByStatus()` ([`stats_service.dart:80`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/domain/logic/stats_service.dart#L80-L88)) : calcule via `effectiveStatus(entry, hasProgress)`.
  3. `countByStatusProvider` ([`providers.dart:559`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/app/providers.dart#L559-L567)) : dérive de `effectiveEntriesProvider` avec une map inline.

---

### 4. Duplication des utilitaires Slugs, Titres et CDN
- **Extraction de slug :**
  - `slugFromCatalogueUrl(url)` dans [`anime_id.dart:145`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/domain/logic/anime_id.dart#L145) utilise `RegExp(r'/catalogue/([^/]+)')`.
  - `slugFromUrl(url)` dans [`animesama_catalog_parser.dart:18`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/animesama_catalog_parser.dart#L18) utilise exactement la même Regex.
  - `_slugOf(it)` est réécrit dans `catalog_page.dart` et `catalog_page_tv.dart`.
- **URLs des images CDN :**
  - Dans `anime_id.dart` (lignes 168-190) : `animeSamaCoverExtensions`, `animeSamaBannerExtensions`, `animeSamaCoverUrl()`, `animeSamaBannerUrl()`.
  - Dans `animesama_catalog_parser.dart` (lignes 9-29) : `_cdnCoverExts`, `_cdnBannerExts`, `cdnImageUrl(slug, banner: ...)`.
  - Même base d'URL (`https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/`), mêmes dossiers (`thumb/`), mêmes extensions (`webp`, `jpg`, `png`).
- **Normalisation des titres et Stopwords :**
  - `normTitle()` dans `animesama_title_matcher.dart`, `normalizeAnimeTitle()` dans `anime_id.dart`, et `normText()` dans `animesama_catalog_parser.dart` effectuent tous les trois `replaceAll(RegExp(r'[^a-z0-9]'), '')`.
  - Deux listes de stopwords quasi identiques coexistent : `_stopwords` ([`animesama_title_matcher.dart:22`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/animesama_title_matcher.dart#L22)) et `_titleStopwords` ([`anime_id.dart:39`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/domain/logic/anime_id.dart#L39)).
- **Nettoyage de chaîne répétitif :**
  - Dans `animesama_embed_resolver.dart` (lignes 70, 74, 78, 84, 87), `.replaceAll('&amp;', '&')` est répété sur 5 branches de retour consécutives dans `extractStreamUrl`.

---

## 🛠️ Anti-patterns et code à refactoriser

### 1. Scraping HTML par Expressions Régulières au lieu du DOM Parser
- **Fichier :** [`lib/src/services/animesama_catalog_parser.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/animesama_catalog_parser.dart)
- **Constat :**
  Bien que `package:html` soit présent dans les dépendances de `pubspec.yaml`, le fichier central de parsing catalogue traite le HTML comme de simples chaînes de caractères avec des expressions régulières à drapeaux `dotAll: true` :
  - `parseCatalogueDetail` :
    ```dart
    final mt = RegExp(r'<h1[^>]*>([^<]+)</h1>').firstMatch(htmlContent);
    final ms = RegExp(r'<p[^>]+id="synopsisText"[^>]*>(.*?)</p>', dotAll: true, caseSensitive: false).firstMatch(htmlContent);
    final mw = RegExp(r'<div[^>]+class="[^"]*genres-wrap[^"]*"[^>]*>(.*?)</div>', dotAll: true, caseSensitive: false).firstMatch(htmlContent);
    ```
  - `parseCards` :
    ```dart
    final cardRe = RegExp(r'<a\s[^>]*href="https?://[^"]*?/catalogue/([^/"]+)/?[^"]*"[^>]*>(.*?)</a>', dotAll: true);
    ```
  - `parsePlanning` : découpe la page via `_splitKeepingGroup(htmlContent, dayPattern)`.
- **Risques et défauts :**
  - **Fragilité extrême :** Une simple modification d'attribut HTML, l'ajout d'une balise imbriquée, ou un saut de ligne inattendu fait échouer silencieusement la regex.
  - **Incohérence :** `parseCards` exige `https?://` absolu dans le `href`, tandis que `parsePlanning` attend un chemin relatif `/catalogue/`.
  - **Performance :** L'allocation de sous-chaînes volumineuses et l'exécution de regex dotAll sur des pages HTML entières provoquent des pics de mémoire inutiles.

---

### 2. Sélecteurs CSS codés en dur avec classes utilitaires Tailwind
- **Fichier :** [`lib/src/services/animesama_title_matcher.dart:101-102`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/animesama_title_matcher.dart#L101-L102)
- **Extrait de code :**
  ```dart
  var titleTag = card.querySelector('h2.card-title');
  titleTag ??= card.querySelector(
      'h1.text-white.font-bold.uppercase.text-md.line-clamp-2');
  ```
- **Problème :** Coder en dur une combinaison stricte de six classes utilitaires CSS Tailwind (`text-white`, `font-bold`, `text-md`, `line-clamp-2`...) est un anti-pattern de scraping majeur. Si le site distant change `text-md` en `text-base` ou modifie l'ordre des classes CSS dans son template Blade/HTML, la recherche de catalogue échoue silencieusement.

---

### 3. Modélisation de données dévoyée : Table de configuration utilisée comme base relationnelle
- **Fichiers :** 
  - [`lib/src/domain/season_progress_repository.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/domain/season_progress_repository.dart)
  - [`lib/src/data/repositories/settings_repository.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/data/repositories/settings_repository.dart)
  - [`lib/src/data/local/database.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/data/local/database.dart)
- **Constat :**
  Bien que Drift (SQLite) soit configuré avec les tables `MediaTable`, `ListEntries`, et `EpisodeProgresses`, la progression par saison **contourne totalement le modèle relationnel** et stocke les épisodes vus dans la table clé/valeur `AppSettings` sous la forme de clés textuelles dynamiques : `anime_sama_watched:<anilistId>:<seasonIndex>`.
- **Anti-patterns SQL qui en découlent :**
  1. **Absence de filtrage SQL :**
     Dans `SettingsRepository.entriesWithPrefix(prefix)` :
     ```dart
     final rows = await _db.select(_db.appSettings).get(); // CHARGE TOUTE LA TABLE EN MÉMOIRE !
     return { for (final r in rows) if (r.key.startsWith(prefix)) r.key: r.value };
     ```
     Au lieu d'exécuter un simple `WHERE key LIKE '$prefix%'`, l'application lit l'intégralité des paramètres applicatifs en RAM puis filtre en Dart.
  2. **Suppression séquentielle N+1 :**
     Dans `SettingsRepository.deleteWithPrefix(prefix)` :
     ```dart
     for (final r in rows) {
       if (r.key.startsWith(prefix)) await delete(r.key); // Requête DELETE individuelle par clé !
     }
     ```
  3. **Agrégations exécutées en mémoire client :**
     Dans `ListRepository.countByStatus()` :
     ```dart
     final all = await _db.select(_db.listEntries).get();
     for (final row in all) { ... }
     ```
     Au lieu de `SELECT status, COUNT(*) FROM list_entries GROUP BY status;`.
  4. **Multiplication de requêtes séquentielles dans `calendar_page.dart` :**
     `_libraryIdsProvider` et `_persoIdsProvider` exécutent respectivement 6 et 5 requêtes `entriesByStatus()` consécutives dans une boucle for synchrone ([`calendar_page.dart:46-66`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/calendar_page.dart#L46-L66)) au lieu d'une unique requête `SELECT media_id FROM list_entries WHERE status != 'dropped'`.
  5. **Dette technique nominale :** Le paramètre `anilistId` reste nommé ainsi dans `SeasonProgressRepository` et dans `anime_id.dart` alors qu'AniList a été complètement purgé lors de la migration de schéma v4.

---

### 4. Composants monolithiques surdimensionnés (UI "God Classes")
Le découpage modulaire de Flutter n'est pas respecté sur les écrans principaux, générant des fichiers difficiles à tester, à maintenir et causant des re-renders inutiles :
- **[`player_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/player_page.dart) (1 994 lignes) :**
  La classe d'état `_PlayerPageState` fait à elle seule près de 1 700 lignes. Elle gère conjointement :
  - Le lecteur MPV natif et ses paramètres bas niveau (`hls-bitrate`, `hr-seek`, buffer) ;
  - Les écoutes clavier et commandes télécommande TV ;
  - L'overlay complet de contrôle (barre de progression, boutons, popup de vitesse, sélecteur de langue) ;
  - L'affichage et le déclenchement de l'auto-skip (AniSkip) ;
  - L'animation du compte à rebours de lecture automatique ;
  - La persistance en base de données.
- **[`library_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/library_page.dart) (1 215 lignes) :**
  Contient 12 classes différentes dans un seul fichier (`_SortBar`, `_SortFieldChip`, `_FilterBar`, `_EntriesTab`, `_SortedEntriesList`, `_MediaTitleResolver`, `_EntryCard`, `_Badge`, `_NewEpisodeDot`...).
- **[`media_detail_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/media_detail_page.dart) (1 057 lignes)**
- **[`settings_page.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/pages/settings_page.dart) (897 lignes)**

---

## 🚀 Pistes d'amélioration & Prochaines étapes

### 1. Couche Réseau & Scraping

#### A. Remplacement de `package:http` bas niveau par un Client HTTP résilient (Dio)
- **Constat dans [`system_http_fetcher.dart`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/system_http_fetcher.dart) :**
  - Pas de timeout par défaut configuré sur le client racine ;
  - Pas de politique de reconnexion ou d'exponential backoff lors d'erreurs 502/503 ou de perte temporaire de paquets ;
  - `Uri.parse(url)` est exécuté jusqu'à 3 fois d'affilée si des paramètres de query sont fournis (lignes 27, 28, 30) ;
  - Utilisation systématique de `try { ... } catch (_) { return null; }` dans tous les services, masquant les erreurs de connectivité, les problèmes DNS et les erreurs de rate-limiting (429).
- **Recommandation :**
  - Introduire **Dio** avec intercepteurs pour la journalisation des requêtes, le pooling de connexion, la gestion transparente des cookies, et des timeouts stricts (ex. 10 s pour les API, 15 s pour les pages HTML).
  - Implémenter un intercepteur de retry (ex. `dio_smart_retry`) pour amortir les instabilités réseau sans crasher.

#### B. Élimination des requêtes HTTP redondantes et cascades inefficaces
- **Le bug de double requête dans AniSkip :**
  Dans [`animesama_aniskip.dart:152-162`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/animesama_aniskip.dart#L152-L162) :
  ```dart
  // Requête 1
  final resp = await fetch('https://api.aniskip.com/v1/skip-times/$malId/$episode', query: {'types': 'op'});
  // Requête 2 IMMÉDIATEMENT APRÈS !
  final resp2 = await fetch('https://api.aniskip.com/v1/skip-times/$malId/$episode?types=op&types=ed');
  ```
  L'application exécute **deux requêtes HTTP consécutives pour chaque épisode vérifié** car `HttpFetcher` utilise une `Map<String, String>` qui n'autorise pas de clés dupliquées (`types=op&types=ed`).
  *Action :* Corriger `HttpFetcher` pour accepter des paramètres de query sous forme de liste (`Map<String, Object>`), et supprimer immédiatement la première requête inutile.
- **Requêtes séquentielles dans `_seasonsFor` ([`animesama_dart_resolver.dart:65-72`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/animesama_dart_resolver.dart#L65-L72)) :**
  Pour chaque saison candidate, `_seasonHasEpisodes` appelle `fetchEpisodes`, qui effectue 2 requêtes HTTP (HTML de la saison + `episodes.js`). Pour un anime de 5 saisons, 10 requêtes sont exécutées en série. Le résultat parsé est jeté, puis `fetchEpisodes` est ré-exécuté plus tard !
  *Action :* Mettre en cache mémoire (`Map<String, Map<String, List<String>>>`) les épisodes résolus lors de la phase de validation pour ne jamais re-télécharger une saison déjà analysée.
- **Dégradation de recherche mot à mot agressive ([`animesama_title_matcher.dart:148-156`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/animesama_title_matcher.dart#L148-L156)) :**
  `degradedQueries(title)` génère jusqu'à N requêtes séquentielles si un titre long ne matche pas directement. Il convient de limiter la dégradation aux 2-3 premiers mots significatifs ou de paralléliser via `Future.wait`.

#### C. Résolution de la cascade de 404 sur les images CDN (`AnimeSamaImage`)
- **Fichier :** [`lib/src/ui/widgets/anime_sama_image.dart:112-121`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/ui/widgets/anime_sama_image.dart#L112-L121)
- **Constat :**
  Pour afficher une miniature, `AnimeSamaImage` teste `.webp` par défaut. Si le fichier n'existe pas, l'`errorBuilder` déclenche un `setState` qui teste `.jpg`, puis `.png`.
  Lors du défilement d'une grille de 50 animes, cela peut générer des dizaines de requêtes HTTP 404 visibles dans les logs et provoquer des sautillements visuels.
- **Action :** Conserver en cache mémoire (ou persister dans `MediaTable.coverUrl`) la bonne URL résolue pour qu'un anime n'effectue jamais deux fois la cascade d'extensions.

---

### 2. Flux Réactifs Riverpod & Performance

#### A. Tempête de réémissions causée par `watchWithPrefix` pendant la lecture
- **Fichiers :** [`providers.dart:136-163`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/app/providers.dart#L136-L163) et [`settings_repository.dart:116`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/data/repositories/settings_repository.dart#L116)
- **Constat :**
  `effectiveEntriesProvider` combine `listRepo.watchAllEntries()` et `settings.watchWithPrefix('anime_sama_watched:')`.
  Comme `watchWithPrefix` écoute la totalité de la table `AppSettings`, chaque écriture de paramètre ou de position de lecture déclenche :
  1. Une requête `SELECT * FROM app_settings` par Drift ;
  2. Le recalcul complet de `effectiveEntriesProvider` sur toutes les entrées ;
  3. L'invalidation de `libraryStatusMapProvider` ;
  4. L'invalidation de `countByStatusProvider` ;
  5. Des notifications inutiles vers les vues abonnées alors qu'une vidéo tourne en plein écran.
- **Action :** Isoler la progression des saisons dans sa propre table Drift `SeasonProgresses` munie d'un flux ciblé (`watch()`), coupant net la pollution du flux `AppSettings`.

#### B. Dédoublement des requêtes de détail en arrière-plan
- **Fichier :** [`animesama_catalog_service.dart:34-38`](file:///C:/Users/Thomas/Documents/dev/Terebi/lib/src/services/animesama_catalog_service.dart#L34-L38)
- Chaque souscription à `watchDetail(slug)` déclenche `unawaited(_maybeRevalidate(slug, id))`. En l'absence de mécanisme d'in-flight deduplication (Mutex/Completer), plusieurs composants observant le même slug déclenchent des tâches de scraping concurrentes vers Anime-Sama et des écritures concurrentes en base.

---

### 3. Architecture Logicielle & Refactorisation Recommandée

| Priorité | Tâche | Fichiers cibles | Gain estimé |
| :--- | :--- | :--- | :--- |
| **P0** | **Activer `PlayerController` & Scinder `PlayerPage`** | `player_page.dart`, `player_controller.dart` | Élimination de 500+ lignes de code mort, modularité du lecteur, testabilité unitaire de la lecture |
| **P0** | **Créer la table Drift `SeasonProgresses`** | `database.dart`, `season_progress_repository.dart`, `settings_repository.dart` | Arrêt des `SELECT *` sauvages, requêtes SQL typées, intégrité référentielle |
| **P1** | **Fusionner les logiques Desktop et TV** | `catalog_page.dart` / `_tv`, `media_detail_page.dart` / `_tv`, `library_page.dart` / `_tv` | Suppression de ~1 500 lignes dupliquées, garantie de parité des fonctionnalités |
| **P1** | **Remplacer le Regex Scraping par le DOM `package:html`** | `animesama_catalog_parser.dart`, `animesama_title_matcher.dart` | Robustesse face aux évolutions du site source, suppression des sélecteurs CSS Tailwind instables |
| **P1** | **Centraliser `ListStatus` & Supprimer AniList Résiduel** | `list_status.dart`, `anime_id.dart`, `season_progress_repository.dart` | Clarté du modèle de données, centralisation des libellés et couleurs |
| **P2** | **Corriger le double appel AniSkip & Cache CDN** | `animesama_aniskip.dart`, `anime_sama_image.dart` | Réduction de 50% des requêtes AniSkip, suppression des 404 CDN à répétition |
| **P2** | **Optimiser le Splash Screen** | `splash_page.dart` | Évite de charger `loading.mp4` en RAM avant de vérifier sa présence sur disque |

---

### Synthèse Globale
Le projet **Terebi** dispose d'un socle fonctionnel bien pensé (décision pertinente du mode hors-AniList, réactivité Riverpod, intégration libmpv performante). Cependant, l'architecture souffre d'un manque de factorisation (dédoublement TV/Desktop), d'une utilisation inappropriée de la table de configuration comme base relationnelle, et de scrapers HTML régis par des expressions régulières fragiles. 

L'application de ce plan d'action permettra d'alléger la base de code d'environ **2 500 à 3 000 lignes**, de diviser par deux le nombre de requêtes réseau inutiles, et de stabiliser durablement l'application face aux changements de l'écosystème Anime-Sama.
