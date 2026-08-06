# Backlog produit — Terebi (application desktop anime)

> **Terebi** (テレビ, « télé ») — application personnelle de suivi, planning et visionnage d'anime,
> avec lecteur intégré.

| Métadonnée | Valeur |
|------------|--------|
| Nom de l'app | **Terebi** (テレビ) |
| Projet | Application desktop anime (réécriture from scratch) |
| Type | Application personnelle (utilisateur unique) |
| Version backlog | 2.0 |
| Date | 2026-08-06 |
| Document de référence | [`CAHIER_DES_CHARGES_STREAMING.md`](./CAHIER_DES_CHARGES_STREAMING.md) |
| Stack cible | **Flutter** (desktop) + **media_kit** (libmpv) + **SQLite** (drift) + **AniList/Jikan** + résolution **ani-cli** |
| Plateforme prioritaire | **Windows** (puis Linux, macOS) |

---

## 0. Décisions d'architecture (révision du cahier des charges)

Ce backlog acte plusieurs décisions prises **après** le cahier des charges, qui remplacent la cible « Tauri + React » initiale.

### 0.1 Réécriture from scratch

Le prototype web actuel (Vite/React/Express) **n'est pas réutilisé** : il est jugé insuffisant.
On repart de zéro avec la techno la plus adaptée. La **logique métier** du prototype (requêtes
AniList/Jikan, modèle de suivi, planning) est **transposable** conceptuellement, pas le code.

### 0.2 Stack retenue : Flutter + media_kit

Contraintes décisives : **belles interfaces** ET **vidéo encastrée dans l'app avec overlays maison**.

| Brique | Choix | Rôle |
|--------|-------|------|
| **UI** | **Flutter** (desktop) | Interfaces soignées, animations, overlays |
| **Lecteur** | **media_kit** (basé **libmpv**) | Vidéo **encastrée** en widget Flutter + overlays par-dessus + **timestamp exact** |
| **Résolution source** | **ani-cli** (ou moteur allanime) | Fournit l'**URL du flux** ; ne lance plus de lecteur |
| **Persistance** | **SQLite** via `drift` | **Source de vérité** du suivi |
| **Métadonnées** | **AniList** (OAuth) + **Jikan** (fallback) | Catalogue, fiches, relations, planning (airing) |
| **Process externe** | ani-cli lancé en sous-process | Résolution d'URL uniquement |

**Pourquoi pas web (Tauri/Electron)** : la vidéo encastrée (surface GPU) et une WebView se
superposent mal sous Windows (problème d'*airspace*). Flutter + media_kit évite ce conflit car la
vidéo est un widget natif du même arbre de rendu que l'UI.

### 0.3 Montage lecture (conséquence de l'encastrement)

> Puisque la vidéo est **encastrée** dans l'app, ani-cli **ne lance plus sa propre fenêtre mpv**.
> Nouveau flux : **ani-cli résout l'URL du flux → media_kit (libmpv) la joue dans l'app** avec
> overlays Flutter. media_kit utilise **le même moteur mpv** qu'ani-cli → même qualité/codecs.

### 0.4 Modèle « marquer vu » (règle validée)

> Un épisode devient **vu** quand l'utilisateur clique sur **« Épisode suivant »** (overlay ou page
> épisode). Ce clic : (a) marque l'épisode courant vu, (b) incrémente `progress` (SQLite + sync
> AniList), (c) charge l'épisode suivant **s'il existe**.

### 0.5 Reprise de visionnage

> Suivi **de l'épisode courant** + **timestamp exact** (position en secondes lue via media_kit/mpv,
> stockée en SQLite, reprise via `--start`/seek). Réactivé grâce au lecteur encastré.

### 0.6 Ce qui est ABANDONNÉ du cahier initial

| Abandonné | Motif |
|-----------|-------|
| Resolve anime-sama maison (scraping/fuzzy match) | ani-cli/allanime gère la résolution |
| FlareSolverr | Plus de scraping anime-sama |
| **Tauri + React** comme cible | Remplacé par Flutter (contrainte vidéo encastrée) |
| **Réutilisation du prototype web** | Réécriture from scratch |
| Téléchargement / offline vidéo | Hors périmètre lanceur (EF-O01→O08) |
| Sous-titres avancés / qualités manuelles / PiP | Gérés par libmpv/media_kit selon flux, pas d'UI dédiée MVP |

### 0.7 Contrainte d'environnement & stratégie de test

État de la machine de dev (Windows, poste managé) constaté le 2026-08-06 :

| Outil | État | Impact |
|-------|------|--------|
| Flutter 3.44.9 + Dart 3.12.2 | ✅ Installés (`C:\SAPDevelop\flutter`) | `flutter create/doctor/pub`, `dart test` OK |
| **`flutter_tester.exe`** | ❌ **Verrouillé par l'EDR** (antivirus d'entreprise) | **`flutter test` inutilisable** (tests de widgets) |
| Visual Studio « Desktop C++ » | ❌ Non installé | Compilation/lancement app **Windows desktop** impossible pour l'instant |
| mpv, ani-cli | ❌ Non installés | Requis pour lecteur (media_kit) + spike résolution |

**Conséquence sur la stratégie de test :**

> `flutter test` est bloqué par une protection de sécurité du poste (non contournable côté dev ; requiert
> une **exclusion EDR** via l'IT sur `C:\SAPDevelop\flutter`). En revanche **`dart test` fonctionne**.
>
> **Règle d'architecture** : toute la **logique métier** (modèles, repositories SQLite/drift, clients
> AniList/Jikan, suivi/franchise, résolution, health-check) est écrite en **Dart pur, isolée des
> widgets**, et **testée via `dart test`**. Les **widgets Flutter** sont écrits sans test automatisé
> (pas de `flutter_tester`) et **validés visuellement** quand l'app peut être lancée (après install de
> Visual Studio + mpv).

**Blocages IT à lever pour compléter le MVP** (hors de portée du dev, à traiter en parallèle) :
1. Exclusion antivirus/EDR sur le dossier Flutter → débloque `flutter test` + lancement app **natif Windows**.
2. Installation de **Visual Studio Build Tools** avec la charge « Desktop development with C++ » (pour builder/lancer l'app **Windows**).
3. Installation de **mpv** (media_kit) et **ani-cli** (via Git Bash) pour le spike et la lecture native Windows.

**Contournement retenu — environnement Docker (hors EDR)** :

> Docker Desktop est disponible. Une image `terebi-ci` (voir `Dockerfile.flutter-ci`, base
> `instrumentisto/flutter` + GTK/clang/ninja/mpv) fournit un environnement Linux **non soumis à
> l'EDR**, où **`flutter test` (widgets), `flutter analyze` et `flutter build linux` fonctionnent**.
> Scripts : `scripts/dart-test.sh` (logique pure, hôte) et `scripts/flutter-ci.sh` (widgets/build, Docker).
>
> → La vérification (tests widgets + compilation Linux) est donc possible **sans** débloquer l'IT.
> Le lancement/visualisation **natif Windows** de l'app reste dépendant des points 1–3 ci-dessus.
> Contrainte SDK abaissée à `>=3.5.0 <4.0.0` pour compatibilité hôte (Dart 3.12) / image (Dart 3.11).

---

## 1. Risque n°1 — Spike technique prioritaire

> ⚠️ **Hypothèse à valider AVANT de graver le MVP** : ani-cli sait-il **fournir l'URL du flux sans
> lancer de lecteur**, de façon fiable (VOSTFR/VF, choix épisode, format de sortie exploitable) ?
> ani-cli est d'abord conçu pour *lancer* un lecteur, pas comme API de résolution.

**US-00 (SPIKE, MVP, à faire en premier)** — Prototyper la résolution d'URL :
- tester les flags ani-cli (ex. modes non-interactifs / affichage de lien), parser la sortie ;
- valider langue (VOSTFR/VF), sélection épisode, gestion d'erreur ;
- mesurer la robustesse (provider allanime change souvent).

**Plan B si ani-cli inadapté** : intégrer **directement le moteur de résolution** (logique allanime,
comme le fait ani-cli en interne) dans l'app en Dart, sans dépendre du script ani-cli.
→ Décision d'architecture prise à l'issue du spike.

---

## 2. Priorisation & légende

| Tag | Signification |
|-----|---------------|
| **MVP** | Première version utilisable au quotidien |
| **V1** | Plateforme complète (online) |
| **V2** | Confort, personnalisation, résilience |
| **V3** | Nice-to-have / expérimental |

Chaque story : ID `US-xx`, priorité, trace vers l'exigence cahier (`EF-xxx`) ou `NEW`.

---

## 3. EPICs

| EPIC | Titre | Objectif |
|------|-------|----------|
| **E0** | Fondations Flutter & spike lecture | Bootstrap projet, spike résolution URL, socle média |
| **E1** | Persistance SQLite | Schéma drift, repositories, migrations, backup |
| **E2** | Métadonnées & découverte | Catalogue, recherche, fiches, relations, planning |
| **E3** | Suivi & bibliothèque | Statuts, progression, franchise multi-saisons |
| **E4** | Lecture encastrée (media_kit) | Player intégré, overlays, épisode suivant, timestamp |
| **E5** | Planning & notifications | Airing schedule, calendrier, rappels |
| **E6** | Statistiques & confort | Dashboard, command palette, reprise globale |
| **E7** | Outils externes & santé | Health-check, aide/auto-install ani-cli/mpv |
| **E8** | Résilience & données | Sync AniList, hors-ligne |

---

## 4. Backlog détaillé par EPIC

### E0 — Fondations Flutter & spike lecture

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-00 | **SPIKE** résolution URL via ani-cli (+ décision plan B allanime) | **MVP** | **NEW** | Voir §1 — bloquant |
| US-01 | Bootstrap projet **Flutter** desktop (Windows) | **MVP** | §0.2 | Structure, routing, thème de base |
| US-02 | Intégrer **media_kit** : jouer une URL de test en widget encastré | **MVP** | §0.2/0.3 | Valide libmpv sous Windows |
| US-03 | Architecture applicative (couches : ui / domain / data / services) | **MVP** | ENF-16 | Logique découplée de l'UI |
| US-04 | Packaging Windows (installateur) | **MVP** | ENF-11 | |
| US-05 | Packaging Linux (AppImage/deb) | V1 | ENF-12 | |
| US-06 | Packaging macOS | V2 | ENF-13 | |
| US-07 | Auto-update (vérif version) | V1 | EF-A05 | |

### E1 — Persistance SQLite

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-10 | Schéma **SQLite (drift)** + migrations versionnées | **MVP** | §7 cahier, ENF-16 | media, list_entry, episode_progress (épisode + position_seconds), watch_history, media_relation, airing_schedule, app_settings, meta_cache |
| US-11 | Repositories typés (accès données) | **MVP** | §6.2 | |
| US-12 | Stockage **sécurisé du token OAuth** | **MVP** | ENF-09 | secure storage plateforme |
| US-13 | Cache métadonnées (TTL + invalidation) | **MVP** | EF-A02 | `meta_cache` |
| US-14 | Bouton vider cache | **MVP** | EF-A03 | |
| US-15 | Backup manuel `.db` horodaté + restore | V1 | EF-A06/07 | |
| US-16 | **Backup auto planifié** (rotation N copies) | V2 | **NEW** | |
| US-17 | Reset données locales (confirmation) | V1 | EF-A04 | |

### E2 — Métadonnées & découverte

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-20 | Accueil (reprendre, en cours, saison, tendances) | **MVP** | EF-D01 | |
| US-21 | Rangée Continue watching (anime + prochain épisode) | **MVP** | EF-D03 | SQLite |
| US-22 | Catalogue paginé AniList/Jikan | **MVP** | EF-D04 | |
| US-23 | Recherche texte (romaji/anglais/natif) | **MVP** | EF-D05 | |
| US-24 | Navigation saisons broadcast | **MVP** | EF-D10 | |
| US-25 | Fiche titre complète | **MVP** | EF-D11 | |
| US-26 | Filtre type (TV/Movie/OVA/ONA/Special) | **MVP** | EF-D09 | |
| US-27 | Filtres genre / année / statut | V1 | EF-D06/07/08 | |
| US-28 | Cast / staff | V1 | EF-D12 | |
| US-29 | Recommandations / similaires | V1 | EF-D15 | |
| US-30 | Trending / Popular / Upcoming | V1 | EF-D16/17/18 | |
| US-31 | Hero / spotlight | V1 | EF-D02 | |
| US-32 | Tags anime en filtres | V2 | EF-D19 | |
| US-33 | Trailers (lien/embed YouTube) | V2 | EF-D14 | |

### E3 — Suivi & bibliothèque

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-40 | Statuts CURRENT / PLANNING / COMPLETED | **MVP** | EF-L01/02/03 | |
| US-41 | Statuts PAUSED / DROPPED | V1 | EF-L04/05 | todos.md |
| US-42 | Progression épisode (`progress`) | **MVP** | EF-L11 | |
| US-43 | **Suivi par saison / franchise** (statut par média lié + marquer chacun) | **MVP** | EF-L12, **NEW (todos.md)** | Cœur du besoin |
| US-44 | Relations navigables (préquelle/suite/side-story) | **MVP** | EF-D13 | |
| US-45 | Sélecteur de saison / média lié | **MVP** | EF-E09 | |
| US-46 | **Auto-replanif nouvelle saison** (suite RELEASING → « à voir » + badge) | V1 | EF-L13, **NEW (todos.md)** | |
| US-47 | Score personnel 1–10 (sync AniList) | **MVP** | EF-L09 | |
| US-48 | Masquer / réafficher du planning (persistant SQLite) | **MVP** | EF-L08, EF-C08 | |
| US-49 | Compteurs par statut (badges) | **MVP** | EF-L15 | |
| US-50 | Favoris (local + AniList) | V1 | EF-L06 | |
| US-51 | Tri & filtres des listes | V1 | EF-L14 | |
| US-52 | Marquer vu / non vu par épisode | **MVP** | EF-E04 | |
| US-53 | Barre progression saison (X/Y + %) | **MVP** | EF-E05 | |
| US-54 | Notes / mémo sur une entrée | V2 | EF-L10 | |
| US-55 | Listes custom nommées | V2 | EF-L07 | |
| US-56 | Historique de visionnage | **MVP** | EF-P13 | `watch_history` |

### E4 — Lecture encastrée (media_kit)

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-60 | **Player encastré** media_kit (play/pause/seek/volume/fullscreen) | **MVP** | EF-P01/P02 (réactivés) | Widget Flutter |
| US-61 | Charger l'URL résolue (US-00) dans le player | **MVP** | §0.3 | |
| US-62 | Préférence **VOSTFR / VF** transmise à la résolution | **MVP** | EF-S03 | |
| US-63 | **Overlay « Épisode suivant »** → marque vu + progress++ + charge suivant si existe | **MVP** | **NEW (règle validée)** | §0.4 |
| US-64 | **« Reprendre au dernier épisode »** sur chaque fiche | **MVP** | **NEW** | Lance le player sur l'épisode courant |
| US-65 | **Timestamp exact** : lire position (mpv), stocker SQLite, reprendre via seek/`--start` | **MVP** | EF-P14 (réactivé via IPC) | §0.5 |
| US-66 | Seuil « vu » auto au-delà d'un % (option, complément au clic suivant) | V1 | EF-P15 | Possible car position connue |
| US-67 | Liste épisodes ordonnée + n° connus / « ? » | **MVP** | EF-E01/E02/E10 | |
| US-68 | Films (média unique, pas de « suivant ») | **MVP** | EF-E06 | |
| US-69 | OVA / ONA suivis distinctement | **MVP** | EF-E07 | |
| US-70 | Raccourcis clavier lecteur (espace, ←/→, ↑/↓, F, M, N, P) | **MVP** | EF-P12 | Réactivé (player encastré) |
| US-71 | Vitesse de lecture 0.75×–2× | V2 | EF-P19 | media_kit le permet |
| US-72 | Sélection piste sous-titres / audio si présentes dans le flux | V1 | EF-P04/P07 | Selon flux résolu |
| US-73 | Skip intro/outro (AniSkip) en overlay | V2 | EF-P09/P10 | Possible car position connue |
| US-74 | Specials liés/séparés | V1 | EF-E08 | |
| US-75 | Fallback : ouvrir mpv/URL externe si player encastré échoue | V1 | EF-P18 (dégradé) | |

### E5 — Planning & notifications

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-80 | Planning saison courante (grille) | **MVP** | EF-C01 | |
| US-81 | Hides persistants sur planning | **MVP** | EF-C08 | US-48 |
| US-82 | Calendrier hebdo jour/heure (airingSchedule) | V1 | EF-C02 | |
| US-83 | Filtrer le planning sur mes listes | V1 | EF-C03 | |
| US-84 | Conversion timezone airing → local | V1 | EF-C07 | |
| US-85 | Badge « nouvel épisode » | V1 | EF-C06 | |
| US-86 | **Notifications OS** nouvel épisode | V1 | EF-C04, **confirmé NEW** | |
| US-87 | Continuité cross-season | V1 | EF-C05 | lié US-46 |

### E6 — Statistiques & confort

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-90 | **Dashboard statistiques** (temps total 24 min/ep, 2 h/film ; terminés ; genres/années) | V1 | EF-E11, **NEW (todos.md)** | |
| US-91 | Estimation temps restant (fiche/saison) | V1 | EF-E11, EF-D20 | |
| US-92 | **Reprise globale en 1 clic** (barre persistante, seulement si l'épisode existe) | V1 | **NEW** | |
| US-93 | **Command palette Ctrl+K** | V1 | **NEW** | |
| US-94 | Thème clair / sombre / système | V1 | EF-S04 | |
| US-95 | Langue UI FR/EN | V1 | EF-S02 | |
| US-96 | Préférences (autoplay next, langue défaut, seuil vu) | **MVP** | EF-S01 | |
| US-97 | Export / import listes JSON-CSV | V2 | EF-SO02/03 | |
| US-98 | Ouvrir page AniList publique | V3 | EF-SO04 | |

### E7 — Outils externes & santé

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-100 | Configurer chemins ani-cli / mpv | **MVP** | EF-S11 | |
| US-101 | **Health-check** (ani-cli, mpv/libmpv, token AniList, DB, réseau) | **MVP** | EF-A08, **confirmé NEW** | |
| US-102 | **Aide à l'installation** contextuelle si outil manquant | **MVP** | **NEW** | |
| US-103 | **Installation automatisée** best-effort (ani-cli & mpv) | V1 | **NEW** | Selon faisabilité par OS |
| US-104 | Logs applicatifs consultables | **MVP** | EF-A01 | résolution, lecture, sync |
| US-105 | Mode debug résolution (commande/sortie ani-cli) | V2 | EF-A09 (redéfini) | |

### E8 — Résilience & données

| ID | Story | Prio | Trace | Notes |
|----|-------|------|-------|-------|
| US-110 | OAuth AniList (login/logout/statut) | **MVP** | EF-S07 | |
| US-111 | Sync listes AniList (pull/push statut, progress, score) | **MVP** | EF-S08, ENF-14 | |
| US-112 | Mode sync (manuel / ouverture / périodique) | V1 | EF-S09 | |
| US-113 | Résolution conflits sync (local/remote/récent) | V1 | EF-S10 | `updated_at` |
| US-114 | **Consultation hors-ligne** (métadonnées+listes SQLite, bannière) | V1 | ENF-04, **confirmé NEW** | Lecture nécessite le net |
| US-115 | File de requêtes AniList résiliente (queue, retry, backoff) | **MVP** | ENF-14 | |
| US-116 | Éviction LRU cache images disque | V1 | ENF-17 | |

---

## 5. Feuille de route indicative

```
E0   → SPIKE résolution URL + bootstrap Flutter + media_kit qui joue une URL
MVP  → SQLite (drift) + suivi (statuts/progress/franchise) + planning + player ENCASTRÉ
       + épisode suivant + timestamp exact + reprendre + health-check + aide install + sync AniList
V1   → Découverte riche + calendrier + notifications + auto-replanif + dashboard stats
       + command palette + reprise globale + hors-ligne + sous-titres/audio + Linux
V2   → Listes custom + notes + export/import + backup auto + skip intro/outro + vitesse + macOS
V3   → Lien AniList public + polish
```

---

## 6. Critères d'acceptation MVP (révisés)

| # | Critère |
|---|---------|
| A0 | **Spike validé** : résolution d'URL fonctionne (ani-cli) OU décision plan B allanime prise |
| A1 | L'app **Flutter** démarre sous Windows |
| A2 | Un flux vidéo joue **encastré** dans l'app (media_kit) avec au moins un overlay |
| A3 | Le suivi (statuts, progress, hides, timestamp) est persisté en **SQLite** et survit au redémarrage |
| A4 | Recherche AniList → fiche complète ; relations navigables ; statut par saison (US-43) |
| A5 | Planning saison + année fonctionne |
| A6 | OAuth AniList réussie ; statut visible |
| A7 | Changement statut/score persiste (SQLite + sync AniList) |
| A8 | **« Épisode suivant »** marque vu, incrémente `progress`, charge le suivant si existe |
| A9 | **« Reprendre »** relance sur l'épisode courant **au timestamp exact** |
| A10 | Health-check signale ani-cli/mpv manquants + aide à l'installation |
| A11 | Logs consultables pour un échec de résolution ou de lecture |
| A12 | Token OAuth en secure storage, jamais loggé en clair, absent du dépôt |

---

## 7. Risques (révisés)

| Risque | Impact | Mitigation |
|--------|--------|------------|
| **ani-cli inadapté comme résolveur d'URL** | Bloque le montage lecture | **Spike US-00** en premier + plan B moteur allanime intégré |
| Provider allanime change (DOM/API) | Résolution cassée | Abstraction résolveur, smoke test, message clair |
| media_kit/libmpv instable sous Windows | Pas de lecture encastrée | Valider tôt (US-02) ; fallback mpv externe (US-75) |
| ani-cli / mpv absents | Pas de lecture | Health-check + aide install + auto-install (US-101/102/103) |
| Rate-limit AniList | Sync/planning dégradés | Queue, cache TTL, backoff (US-115) |
| Dérive schéma SQLite | Perte données | Migrations drift + backup avant migrate (US-10/15/16) |
| Sync conflictuelle AniList ↔ local | Progression incorrecte | Règle conflit + `updated_at` (US-113) |
| Courbe Dart/Flutter | Ralentissement initial | App perso, pas de deadline ; capitaliser sur la logique métier transposable |
| Scope creep | Retard | Abandons actés §0.6 ; player = media_kit, pas de resolve anime-sama |

---

*Backlog v2.0 — réécriture from scratch en Flutter + media_kit décidée le 2026-08-06. Lecteur vidéo
encastré (libmpv) avec overlays et timestamp exact ; ani-cli réduit au rôle de résolveur d'URL
(plan B : moteur allanime intégré, à trancher après le spike US-00) ; SQLite source de vérité du
suivi ; AniList/Jikan pour métadonnées et planning. Voir §0 pour les décisions et §1 pour le spike.*
