# Design — Retrait complet d'AniList, tout via anime-sama (Terebi)

**Date :** 2026-08-14
**Statut :** approuvé (design), prêt pour le plan d'implémentation.

## Contexte & objectif

Terebi utilise aujourd'hui deux sources : **AniList/Jikan** (identité, image, synopsis, genres,
tendances, populaires, saison, malId) et **anime-sama** (résolveur de flux VOSTFR/VF, saisons,
épisodes, planning, AniSkip). Le pont AniList↔anime-sama repose sur un matching par titre
(`TitleMatcher`) qui produit des **mauvais matchs** : mauvaises saisons (Dragon Ball → Dragon Ball
Heroes/Z), mauvaises images, et une identité instable (id AniList positif OU hash négatif du titre)
qui fait « perdre » la progression quand un anime est ré-résolu sous un id différent.

**Décision :** abandonner **totalement** AniList/Jikan. anime-sama devient la source unique
(identité, enrichissement, découverte). AniSkip est conservé (résolution du malId par titre, déjà
côté Python). Ce qu'AniList apportait et qu'anime-sama n'a pas nativement (synopsis, genres, image,
heure de planning) est obtenu en **enrichissant le scraping anime-sama**.

**Deux contraintes transverses de premier plan (exprimées par l'utilisateur) :**

1. **La DB est un cache.** Elle sert à accéder rapidement aux données pendant qu'elles sont
   recalculées ; elle n'est pas la source de vérité. Toute lecture doit être *cache-first* avec
   **revalidation en arrière-plan**.
2. **L'UI doit être réactive en temps réel.** Aujourd'hui l'UI ne se met pas à jour immédiatement
   après un changement de DB (elle dépend d'`invalidate` manuels fragiles). Toute écriture DB doit
   se propager automatiquement à l'écran.

Domaine anime-sama de référence : **anime-sama.to**.

## Approche retenue

**Approche A — Scraper anime-sama étendu + cache réactif.** Trois piliers :
1. DB = cache, revalidation en arrière-plan (cache-first).
2. UI temps réel via **streams Drift** (`watch*()` → `StreamProvider`), remplaçant les
   `FutureProvider` + `invalidate` manuels.
3. anime-sama seul, identité par **slug d'URL**, AniSkip conservé.

Approches écartées : **B** (garder les `FutureProvider`+`invalidate` — ne résout PAS la plainte
« pas de temps réel ») ; **C** (pré-indexer tout le catalogue au premier lancement — sur-ingénierie,
YAGNI pour un usage perso).

---

## Section 1 — Identité par slug + migration BDD (choix 1a)

**Problème.** L'identité est un `int` : `anilistId` positif (import AniList) OU hash négatif du titre
(`animeSamaIdFor`). Collisions/mauvais matchs, progression perdue. La progression est indexée par cet
id : `ListEntries.mediaId`, `EpisodeProgresses.mediaId`, `WatchHistories.mediaId`, et les clés
`AppSettings` (`anime_sama_watched:<id>:<saison>`, `anime_sama_season:<id>`, `anime_sama_lang:<id>`,
`new_episode:<id>`).

**Cible (choix 1a — id entier dérivé du slug).** L'identité **logique** devient le **slug d'URL**
anime-sama (`/catalogue/one-piece/` → `one-piece`), stable et unique par construction. L'identité
**technique** reste un `int` **positif déterministe** dérivé du slug, pour ne PAS toucher aux FK
entières des tables de progression.

- Nouvelle fonction `animeSamaIdForSlug(String slug) -> int` (FNV-1a 32 bits → masqué en positif non
  nul, sur 31 bits). Remplace `animeSamaIdFor(title)`.
- Le slug est stocké **en clair** dans une nouvelle colonne `MediaTable.animeSamaSlug` (source de
  vérité affichable, détection de collision).

> Choix 1b (slug en clé TEXT sur les 5 tables) écarté : impose de migrer toutes les PK/FK et de
> regénérer tout le code drift — risqué et long pour un gain sémantique marginal.

**Migration (schemaVersion 2 → 3) — voir Section 5 pour le détail en deux temps.** Principe :
re-résoudre le slug de chaque média existant, calculer le nouvel id, **ré-indexer** la progression
de l'ancien id vers le nouveau **dans une transaction**, en préservant la progression. Best-effort :
tout média non re-résolu est **logué** (jamais supprimé) ; l'utilisateur fournira la BDD pour
réparation manuelle si besoin.

---

## Section 2 — Scraper anime-sama enrichi (Python)

Extensions de `assets/resolver/animesama_resolve.py` (wrapper) s'appuyant sur `anime_sama.py`.
Contrat inchangé : une ligne `PREFIX_JSON: {...}` sur stdout en succès, `RESOLVE_ERROR: ...` + exit 1
sinon. Chaque action tolère un HTML partiel (champ absent → `null`/`[]`, jamais d'exception qui casse
la sortie JSON).

**2a — `search` renvoie le slug.** `action_search` renvoie désormais le slug dérivé de l'URL :
```
CATALOGUE_JSON: [{"title": "...", "url": "/catalogue/one-piece/", "slug": "one-piece"}]
```

**2b — nouvelle action `catalogue-detail` (entrée `--slug`).** Scrape `/catalogue/<slug>/` :
```
DETAIL_JSON: {"slug","title","synopsis","genres":[...],"cover_url","banner_url"}
```
Remplace l'enrichissement AniList (→ `MediaTable.description`, `genresJson`, `coverUrl`, `bannerUrl`).
**Image en priorité depuis le CDN anime-sama** (`cdn.jsdelivr.net/gh/Anime-Sama/IMG`), cohérente avec
l'accueil et le planning.

**2c — nouvelle action `home`.** Scrape l'accueil `anime-sama.to` :
```
HOME_JSON: {
  "classics":        [{"title","url","slug","cover_url","genres":[...]}],
  "latest_episodes": [{"title","url","slug","cover_url","genres":[...]}]
}
```
« Les classiques » + « derniers épisodes ajoutés ». Remplace tendances/populaires AniList.

**2d — nouvelle action `catalogue-filter` (entrée `--genre`).** Interroge le filtre par genre du
catalogue anime-sama pour les rangées « par genre » de l'accueil :
```
CATALOGUE_JSON: [{"title","url","slug","cover_url","genres":[...]}]
```

**2e — `planning` : ajout du slug.** `action_planning` capture déjà `day/time/title/url` (heure via
`cartePlanningAnime(...,"HHhMM",...)`). On ajoute `slug` à chaque item. **L'heure est déjà gérée** —
rien d'autre à faire de ce côté.

**2f — AniSkip inchangé.** `action_skip_times` (malId par titre via `_resolve_mal_ids`) ne bouge pas.

**Fragilité assumée.** Le scraping dépend du HTML/JS d'anime-sama. Si la structure change,
l'enrichissement se dégrade (champs `null`) mais l'app continue de fonctionner (le résolveur de flux
marche déjà) ; le cache DB masque en plus les pannes réseau ponctuelles.

---

## Section 3 — DB = cache, UI temps réel (pilier)

**3a — Cache-first + revalidation en arrière-plan.** Chaque écran lit la DB **immédiatement**
(affichage instantané, même périmé), puis déclenche un scraping **en tâche de fond** qui ré-écrit la
DB. Un service `AnimeSamaCatalogService` :
```
watchDetail(slug) -> Stream<Media>   // émet l'état DB tout de suite
   ↳ en parallèle : si TTL expiré (MetaCache.expiresAt / MediaTable.updatedAt),
     scrape catalogue-detail → upsert DB (le stream ré-émet automatiquement).
```
Un scrape en cours n'est jamais bloquant pour l'affichage.

**3b — UI temps réel via streams Drift (le vrai fix).** Les `FutureProvider` de **données de
catalogue** deviennent des **`StreamProvider`** branchés sur `watch*()` Drift. Ajouts de repository :
`MediaRepository.watchMedia(id)` (en plus de `watchAllMedia()` existant),
`ListRepository.watchEntry(id)` / `watchEntriesByStatus(status)` / `watchAllEntries()`,
`SettingsRepository.watchWithPrefix(prefix)`. **Toute écriture DB** (revalidation, purge, progression,
migration) fait émettre Drift → l'UI se rafraîchit seule. **La cascade d'`invalidate` dans `_purge`
est supprimée** : la purge écrit en DB, le stream propage.

**Décision validée : « tout en streams »** — on convertit dans ce refactor l'ensemble des providers de
données de catalogue (média, entrées de liste, statuts, progression par saison), pas seulement fiche
+ accueil.

**3c — Ce qui reste en `FutureProvider.family`.** Les appels **purement réseau sans miroir DB** :
résolution d'URL de flux (`resolveStreamUrl`), langues dispo par épisode (`animeSamaLanguagesProvider`),
skip-times (`animeSamaSkipTimesProvider`). Ce sont des actions ponctuelles au moment de lire, pas des
données de catalogue à cacher/observer.

**3d — Progression par saison (`AppSettings`) réactive.** La progression par saison vit dans
`AppSettings` (`anime_sama_watched:*`). `SettingsRepository.watchWithPrefix(prefix)` (stream Drift sur
`AppSettings`) alimente `SeasonProgressRepository` et `hasProgressProvider`, pour que fiche/accueil
réagissent en temps réel à un épisode marqué vu.

**Bilan.** Après ce refactor, purge, reprise d'épisode, revalidation background et migration passent
**tous** par une écriture DB observée par un stream. Aucun écran ne dépend plus d'un `invalidate`
manuel. C'est le « temps réel » qui manque aujourd'hui.

---

## Section 4 — Dashboard, providers & nettoyage AniList

**4a — Rangées d'accueil (100 % anime-sama).**

| Rangée | Source | Provider |
|---|---|---|
| En ce moment | historique local | `_mostWatchedProvider` (inchangé) |
| Continuer à regarder | liste « en cours » locale | `_continueWatchingProvider` (inchangé) |
| Sortis du moment | `planning` anime-sama (avec heures) | adapté (slug) |
| **Les classiques** | `home` → `classics` | **nouveau** |
| **Derniers épisodes ajoutés** | `home` → `latest_episodes` | **nouveau** |
| Par genre · *(genre favori)* | `catalogue-filter --genre` | **nouveau** |

**Supprimées :** « Tendances du moment », « Populaires », « Saison courante », « Recommandé · genre »
(toutes AniList). Le `_libraryFilterProvider` (exclusion biblio) est **conservé mais simplifié** :
l'identité étant unifiée par slug, l'exclusion redevient un simple `Set<int>` d'ids (plus de
double-clé id + titre normalisé).

**4b — « Par genre » via `catalogue-filter`** (action Python dédiée — choix validé, plus fiable que
filtrer un échantillon de la home). Une rangée par genre favori (les genres les plus présents dans la
bibliothèque suivie, cf. `_favoriteGenresProvider`, conservé).

**4c — Suppression du code AniList/Jikan.** Retirer du projet :
- `aniListClientProvider`, `rawAniListClientProvider`, `CachedAniListClient`, `AniListClient`,
  `AniListApi` ;
- `jikanClientProvider`, `JikanClient`, `requestQueueProvider`, `RequestQueue` ;
- `titleMatcherProvider` + `TitleMatcher` (remplacé par résolution slug + `catalogue-detail`) ;
- `animeSamaResolvedTitleProvider` (l'identité slug rend le scoring inutile au **runtime** ;
  `titleMatchScore` **reste** utile uniquement pour choisir le bon résultat lors d'une **recherche
  manuelle** de titre) ;
- providers `_trendingProvider`, `_popularProvider`, `_byGenreProvider`, `_seasonPreviewProvider`.
- `MetaCacheRepository`/`MetaCache` : **réutilisés** comme cache de scraping anime-sama (pas
  supprimés) — TTL pour la revalidation cache-first.
- `healthServiceProvider` : la sonde réseau `graphql.anilist.co` → remplacée par un ping
  `anime-sama.to`.

**4d — Enrichissement = `catalogue-detail`.** Là où on faisait `TitleMatcher.resolve(title)`
(image/synopsis AniList), on appelle `catalogue-detail(slug)` → `Media` enrichi (cover CDN, synopsis,
genres). `Media.fromAnimeSama` gagne les champs enrichis ; `Media.enrichedWith` (fusion AniList)
disparaît.

**4e — AniSkip garde le malId par titre.** `catalogue-detail` ne fournit pas de malId ;
`MediaTable.malId` peut rester `null`. AniSkip se débrouille par titre (`_resolve_mal_ids` déjà côté
Python). La colonne `malId` est conservée (non remplie depuis Jikan).

---

## Section 5 — Migration détaillée, tests & risques

**5a — Migration v2→v3 en deux temps (préserve la progression).**

`onUpgrade` ne peut pas scraper le réseau proprement (contexte d'ouverture DB). Donc :

1. **Schéma (dans `onUpgrade`)** : ajouter la colonne `MediaTable.animeSamaSlug` (nullable). Seul
   changement de schéma → rapide et sûr.
2. **Ré-indexation (au 1er boot post-migration, HORS `onUpgrade`)** : service `SlugMigrationService`
   exécuté une seule fois (drapeau `AppSettings['slug_migration_done']`). Pour chaque `Media` sans
   slug :
   - `search(animeSamaTitle ?? title)` → meilleur résultat via `titleMatchScore` → `slug` ;
   - `newId = animeSamaIdForSlug(slug)` ;
   - dans **une transaction Drift** : ré-écrire `ListEntries.mediaId`, `EpisodeProgresses.mediaId`,
     `WatchHistories.mediaId`, et renommer les clés `AppSettings`
     (`anime_sama_watched:<old>:*`, `anime_sama_season:<old>`, `anime_sama_lang:<old>`,
     `new_episode:<old>`) de `<old>` vers `<new>` ; renseigner `MediaTable.animeSamaSlug` ;
   - média **non résolu** → **logué** dans `AppSettings['slug_migration_report']` (liste des titres
     échoués), **jamais supprimé** (il garde son ancien id en attendant réparation).

   Filet de sécurité (accord utilisateur) : si la ré-indexation rate des animes, le rapport les liste,
   l'utilisateur fournit la BDD, réparation manuelle. **Aucune progression n'est effacée.**

**5b — Tests.**
- **Domaine pur (`dart test`)** : `animeSamaIdForSlug` (déterministe, positif, pas de collision
  triviale) ; parsing des sorties JSON (`DETAIL_JSON`, `HOME_JSON`, `CATALOGUE_JSON` avec slug,
  `PLANNING_JSON` avec slug) ; `titleMatchScore` (déjà couvert) ; logique de ré-indexation avec
  `NativeDatabase.memory()`.
- **Migration** : test dédié — DB v2 peuplée (média + entrée + progression `EpisodeProgresses` +
  clés `anime_sama_watched`) → migration + ré-indexation → assert que la progression est retrouvée
  sous le nouvel id dérivé du slug.
- **Streams** : test qu'une écriture (`upsertMedia`, purge) fait émettre le `watch*` correspondant.
- **Widget (Docker `scripts/flutter-ci.sh test`)** : l'accueil monte les nouvelles rangées sans
  réseau (providers mockés/surchargés).
- **Non testable ici (validation utilisateur sur PC)** : rendu réel des images CDN ; scraping live
  `home` / `catalogue-detail` / `catalogue-filter` ; migration sur la vraie BDD.

**5c — Risques & parades.**

| Risque | Parade |
|---|---|
| HTML anime-sama change → enrichissement `null` | app fonctionne (flux OK) ; champs dégradés, pas de crash |
| Migration rate des animes | rapport loggé + BDD fournie pour réparation ; rien n'est supprimé |
| Scraping plus lent qu'AniList caché | cache-first : affichage DB instantané, revalidation en fond |
| Collision hash slug→int | slug stocké en clair ; collision détectable/logable (très improbable, FNV-1a 31 bits sur quelques milliers d'animes) |
| `flutter-ci.sh test` casse `package_config` Windows | procédure connue : `dart pub get` + `git checkout -- pubspec.lock` avant commit |

**5d — Ordre d'implémentation (pour le plan).**
1. Scraper Python : `search`+slug, `catalogue-detail`, `home`, `catalogue-filter`, `planning`+slug +
   tests de parsing.
2. `animeSamaIdForSlug` + colonne `animeSamaSlug` + schéma v3 (`onUpgrade`).
3. Repositories : streams `watch*` manquants + purge/`deleteMedia` par écriture.
4. `SlugMigrationService` + test de migration.
5. `AnimeSamaCatalogService` (cache-first + revalidation background).
6. `providers.dart` : conversion en `StreamProvider`, suppression du câblage AniList/Jikan.
7. Dashboard : nouvelles rangées (classiques, derniers ajoutés, par genre), suppression des rangées
   AniList.
8. Fiche : enrichissement via `catalogue-detail`, purge sans `invalidate`.
9. Nettoyage fichiers AniList/Jikan + health-check `anime-sama.to`.
10. Vérif finale : `dart analyze` (lib+test, 0 issue), `dart test`, Docker widget tests.

## Fichiers touchés (indicatif)

**Python (assets/resolver/)** : `animesama_resolve.py` (nouvelles actions + slug),
éventuellement helpers dans `anime_sama.py`.
**Dart — modifiés** : `lib/src/domain/logic/anime_id.dart` (ajout `animeSamaIdForSlug`),
`lib/src/data/local/database.dart` (colonne `animeSamaSlug`, schéma v3, migration),
`lib/src/data/repositories/{media,list,settings}_repository.dart` (streams `watch*`),
`lib/src/services/animesama_resolver.dart` (nouvelles actions), `lib/src/app/providers.dart`
(StreamProviders, suppression AniList), `lib/src/ui/pages/home_page.dart` (rangées),
`lib/src/ui/pages/media_detail_page.dart` (enrichissement + purge), `lib/src/domain/models/media.dart`
(`fromAnimeSama` enrichi, retrait `enrichedWith`), `healthServiceProvider`.
**Dart — nouveaux** : `lib/src/services/animesama_catalog_service.dart`,
`lib/src/services/slug_migration_service.dart`.
**Dart — supprimés** : `anilist_client.dart`, `cached_anilist_client.dart`, `jikan_client.dart`,
`request_queue.dart`, `title_matcher.dart` (+ tests associés).

## Hors périmètre (YAGNI)

- Pré-indexation du catalogue complet au démarrage (approche C).
- Repli AniList silencieux (approche B).
- Remplissage de `malId` depuis une source externe (AniSkip se débrouille par titre).
- Support mobile (déjà reporté : verrou = résolveur Python `Process.run`).
