# Cahier des charges — Application personnelle de streaming anime

| Métadonnée | Valeur |
|------------|--------|
| Projet | Dashboard-sama-scrapper → application desktop anime |
| Type | Application personnelle (utilisateur unique) |
| Version document | 1.0 |
| Date | 2026-08-06 |
| Statut | Brouillon de référence produit |
| Prototype actuel | Dashboard web Vite + React + Express (AniList, planning, resolve anime-sama) |
| Cible long terme | Desktop Tauri + SQLite + AniList/Jikan + lecture mpv / ani-cli |

**Légende priorisation**

| Tag | Signification |
|-----|---------------|
| **MVP** | Indispensable pour une première version utilisable au quotidien |
| **V1** | Première version « plateforme » complète hors hors-ligne avancé |
| **V2** | Enrichissements confort, offline, social léger |
| **V3** | Nice-to-have / expérimentations |

---

## 1. Contexte & objectifs

### 1.1 Contexte

Le projet démarre comme un **dashboard web personnel** permettant de :

- consulter le **planning de diffusion** par saison (AniList) ;
- gérer des listes (**À regarder**, **Déjà vu**) via OAuth AniList ;
- ouvrir une **fiche anime** et résoudre un lien vers un provider (anime-sama) ;
- configurer la connexion AniList et l’extension de domaine du provider.

L’ambition long terme est de transformer ce prototype en une **application desktop personnelle** dédiée à l’anime : découverte, suivi, planification, lecture et reprise de visionnage — sans ambition SaaS multi-utilisateurs.

### 1.2 Objectifs produit

| Objectif | Description |
|----------|-------------|
| O1 | Centraliser catalogue, listes et planning anime dans une seule app |
| O2 | Offrir une expérience de lecture classique (lecteur, reprise, prochain épisode) |
| O3 | Conserver une source de vérité locale (SQLite) avec sync optionnelle AniList |
| O4 | Couvrir les besoins **spécifiques anime** (saisons broadcast, OVA, films, VF/VOSTFR, continuité multi-saisons) |
| O5 | Rester une app **solo**, installable, offline-capable à terme |

### 1.3 Objectifs non-produit (explicites)

- Pas de monétisation, pas de comptes utilisateurs multiples.
- Pas de CDN / hébergement de flux vidéo propriétaire.
- Pas de clone Netflix « films & séries générales » : le cœur métier est l’**anime**.

---

## 2. Périmètre

### 2.1 Dans le périmètre (in scope)

- Découverte et catalogue anime (métadonnées AniList / Jikan).
- Bibliothèques et listes personnelles (statuts AniList + listes custom locales).
- Lecteur vidéo intégré ou piloté (mpv / wrapper UI).
- Résolution de sources de lecture via providers configurables (ex. anime-sama, ani-cli).
- Planning hebdomadaire et rappels locaux.
- Progression épisode / saison / timestamp de reprise.
- Téléchargement et lecture offline (phases avancées).
- Préférences locales, backup SQLite, sync AniList.
- Packaging desktop multi-OS (Windows prioritaire, puis Linux/macOS).

### 2.2 Hors périmètre (out of scope)

| Élément | Motif |
|---------|-------|
| Compte cloud multi-appareils SaaS | App personnelle mono-utilisateur |
| Réseau social public (followers, feed) | Hors besoin perso ; notes locales seulement |
| Streaming légal agrégé (licences Netflix/Crunchyroll API payantes) | Hors modèle perso / non garanti |
| Contenu non-anime (films Hollywood, séries live-action) | Hors focus produit |
| Modération, facturation, RGPD multi-tenant | Non applicable |
| Hébergement ou redistribution de fichiers vidéo | L’app orchestre la lecture ; elle ne distribue pas de contenu |

### 2.3 Avertissement légal (note brève)

Cette application est conçue pour un **usage personnel**. L’utilisateur est seul responsable de la légalité des sources qu’il configure et des contenus qu’il visionne ou télécharge. Le présent cahier des charges décrit des **fonctionnalités techniques** ; il ne constitue pas une incitation à contourner les droits d’auteur. Les providers tiers (sites, CLI) sont **fragiles**, non contractuels, et peuvent disparaître ou changer sans préavis.

---

## 3. Personas

### 3.1 Persona unique — « Solo anime watcher »

| Attribut | Détail |
|----------|--------|
| Profil | Utilisateur unique, passionné d’anime |
| Contexte | Suit plusieurs saisons en parallèle (broadcast + catch-up) |
| Habitudes | Planning hebdo, listes Watching / Planning / Completed |
| Attentes | Reprise exacte, next episode, VF/VOSTFR, masquer le bruit du planning |
| Contraintes | Une machine principale (desktop) ; connexion AniList déjà existante |
| Non-besoins | Partage social public, profils famille, recommandations publicitaires |

**Scénarios clés**

1. Ouvrir l’app → continuer l’épisode en cours au timestamp exact.
2. Consulter le planning du jour → marquer vu / masquer un titre.
3. Chercher un anime → l’ajouter en Planning → démarrer l’épisode 1.
4. Une nouvelle saison sort pour un titre Completed → repasser en Watching / Planning.
5. Partir en déplacement → télécharger une saison et lire offline (V2+).

---

## 4. Exigences fonctionnelles

Chaque exigence porte un identifiant `EF-xxx`, une priorité (**MVP** / **V1** / **V2** / **V3**) et des notes anime si pertinent.

### 4.1 Découverte & catalogue

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-D01 | Accueil / Home | **MVP** | Écran d’accueil avec sections : reprendre, en cours, saison courante, tendances |
| EF-D02 | Hero / spotlight | **V1** | Mise en avant d’un titre (saison courante, favori, ou trending) |
| EF-D03 | Continue watching | **MVP** | Rangée des titres en cours avec progression (épisode + %) |
| EF-D04 | Catalogue paginé | **MVP** | Liste / grille de titres issus d’AniList/Jikan |
| EF-D05 | Recherche texte | **MVP** | Recherche par titre (romaji, anglais, natif) |
| EF-D06 | Filtres genre | **V1** | Filtrer par genre(s) AniList |
| EF-D07 | Filtre année | **V1** | Filtrer / trier par année de début |
| EF-D08 | Filtre statut | **V1** | RELEASING, FINISHED, NOT_YET_RELEASED, CANCELLED |
| EF-D09 | Filtre type | **MVP** | TV, Movie, OVA, ONA, Special, Music |
| EF-D10 | Saisons broadcast | **MVP** | Navigation Hiver / Printemps / Été / Automne + année (existant prototype) |
| EF-D11 | Fiche titre | **MVP** | Synopsis, cover, banner, score, studios, genres, statut |
| EF-D12 | Cast / staff | **V1** | Personnages principaux + staff (réalisateur, studio) |
| EF-D13 | Relations & saisons | **MVP** | Franchise : préquelles, suites, side-stories ; continuité multi-saisons |
| EF-D14 | Trailers | **V2** | Lecture / lien trailer (YouTube AniList) |
| EF-D15 | Recommandations / similaires | **V1** | Titres similaires (AniList recommendations) |
| EF-D16 | Trending | **V1** | Rangée « tendances » |
| EF-D17 | Popular | **V1** | Rangée « populaires » (saison / all-time) |
| EF-D18 | Upcoming | **V1** | Prochaines sorties / not yet released suivis |
| EF-D19 | Tags anime | **V2** | Tags AniList (ex. Isekai, School) en filtres avancés |
| EF-D20 | Format durée | **V2** | Afficher durée épisode / estimation temps total restant |

### 4.2 Bibliothèques & listes

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-L01 | Statut Watching (CURRENT) | **MVP** | Liste des animes en cours |
| EF-L02 | Statut Planning | **MVP** | Liste à regarder plus tard |
| EF-L03 | Statut Completed | **MVP** | Liste terminés |
| EF-L04 | Statut Paused | **V1** | En pause |
| EF-L05 | Statut Dropped | **V1** | Abandonnés |
| EF-L06 | Favoris | **V1** | Marquage favori local et/ou AniList |
| EF-L07 | Listes custom | **V2** | Listes personnelles nommées (ex. « À rewatch ») |
| EF-L08 | Masquer du planning | **MVP** | Hide local d’un titre sur le planning (existant prototype) |
| EF-L09 | Score personnel | **MVP** | Note 1–10 (sync AniList si connecté) |
| EF-L10 | Notes texte | **V2** | Mémo local sur une entrée de liste |
| EF-L11 | Progression épisode liste | **MVP** | `progress` = dernier épisode vu |
| EF-L12 | Progression par saison / media | **MVP** | Pour franchises : statut par média lié (saison 1 Completed, saison 2 Planning) |
| EF-L13 | Auto-replanification nouvelle saison | **V1** | Si un titre Completed a une suite RELEASING → proposer / auto-ajouter en Planning |
| EF-L14 | Tri & filtres listes | **V1** | Tri score, titre, date MAJ, progression |
| EF-L15 | Compteurs listes | **MVP** | Badge nombre d’entrées par statut |

### 4.3 Lecture & lecteur

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-P01 | Lecteur vidéo | **MVP** | Play / pause, seek, volume, mute |
| EF-P02 | Plein écran | **MVP** | Toggle fullscreen |
| EF-P03 | Qualités | **V1** | Sélection 480p / 720p / 1080p si disponibles |
| EF-P04 | Sous-titres — piste | **V1** | Choix de piste / fichier subtil |
| EF-P05 | Sous-titres — taille | **V2** | Taille / style des sous-titres |
| EF-P06 | Sous-titres — offset | **V2** | Décalage temporel des sous-titres |
| EF-P07 | Audio VO / VF | **V1** | Sélection piste ou source VOSTFR / VF |
| EF-P08 | Next episode auto | **MVP** | Enchaînement automatique vers l’épisode suivant |
| EF-P09 | Skip intro | **V2** | Saut intro si timestamps connus (AniSkip / manuel) |
| EF-P10 | Skip outro / ending | **V2** | Saut ending + proposition next episode |
| EF-P11 | Picture-in-picture | **V2** | PiP OS / fenêtre flottante |
| EF-P12 | Raccourcis clavier | **MVP** | Espace, ←/→, ↑/↓, F, M, N (next), P (prev) — documentés |
| EF-P13 | Historique de visionnage | **MVP** | Journal local des sessions (media, ep, durée) |
| EF-P14 | Reprise exacte (timestamp) | **MVP** | Reprendre à la seconde près |
| EF-P15 | Seuil « épisode vu » | **MVP** | Marquer vu automatiquement au-delà d’un % (ex. 90 %) |
| EF-P16 | Backend lecture mpv | **MVP** | Pilotage mpv (IPC) depuis l’UI Tauri |
| EF-P17 | Fallback ani-cli | **V1** | Résolution / lecture via ani-cli si configuré |
| EF-P18 | Ouverture provider externe | **MVP** | Fallback navigateur / URL résolue (comportement prototype) |
| EF-P19 | Speed playback | **V2** | Vitesse 0.75×–2× |
| EF-P20 | Aspect ratio / crop | **V3** | Ajustements avancés mpv |

### 4.4 Épisodes & saisons

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-E01 | Liste des épisodes | **MVP** | Liste ordonnée par numéro |
| EF-E02 | Numérotation | **MVP** | Affichage Ep. N ; gestion absolute vs relative si besoin |
| EF-E03 | Thumbnails épisodes | **V2** | Vignettes si disponibles |
| EF-E04 | Marquer vu / non vu | **MVP** | Toggle manuel par épisode |
| EF-E05 | Progression saison | **MVP** | Barre X/Y épisodes + % |
| EF-E06 | Films | **MVP** | Type Movie traité comme média unique |
| EF-E07 | OVA / ONA | **MVP** | Affichage et suivi distincts |
| EF-E08 | Specials | **V1** | Specials liés ou séparés selon métadonnées |
| EF-E09 | Sélecteur de saison | **MVP** | Changer de saison / média lié dans la fiche |
| EF-E10 | Nombre d’épisodes connus | **MVP** | Afficher `episodes` AniList (ou « ? » si inconnu) |
| EF-E11 | Estimation temps visionnage | **V1** | Heuristique (ex. TV ≈ 24 min, film ≈ 2 h) — besoin exprimé dans todos |
| EF-E12 | Filler / canon tags | **V3** | Indication optionnelle (sources communautaires) |

### 4.5 Planning & notifications

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-C01 | Planning saison AniList | **MVP** | Grille saison courante (existant) |
| EF-C02 | Calendrier hebdo jour/heure | **V1** | Vue semaine basée sur `airingSchedule` / broadcast |
| EF-C03 | Filtrer planning sur mes listes | **V1** | N’afficher que Watching / Planning |
| EF-C04 | Rappels nouvel épisode | **V2** | Notification locale OS à l’heure de diffusion |
| EF-C05 | Continuité cross-season | **V1** | Détecter suites et maintenir le suivi (EF-L13) |
| EF-C06 | Badge « nouvel épisode » | **V1** | Indicateur sur Continue watching / listes |
| EF-C07 | Timezone utilisateur | **V1** | Conversion horaires airing → fuseau local |
| EF-C08 | Masqués persistants | **MVP** | Persist hide (SQLite à terme, localStorage aujourd’hui) |

### 4.6 Téléchargement & offline

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-O01 | Download épisode | **V2** | Télécharger un épisode vers stockage local |
| EF-O02 | Download saison | **V2** | File d’attente pour tous les épisodes d’une saison |
| EF-O03 | File d’attente downloads | **V2** | Pause / reprise / annulation / priorités |
| EF-O04 | Gestion stockage local | **V2** | Quota, chemin de dossier, taille utilisée |
| EF-O05 | Lecture offline | **V2** | Lire les fichiers téléchargés sans réseau |
| EF-O06 | Qualité download | **V2** | Choix qualité au moment du téléchargement |
| EF-O07 | Nettoyage automatique | **V3** | Supprimer après visionnage (option) |
| EF-O08 | Intégrité fichiers | **V3** | Vérif. taille / re-download si corrompu |

### 4.7 Profil & préférences

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-S01 | Préférences lecteur | **MVP** | Volume défaut, autoplay next, seuil « vu » |
| EF-S02 | Langue UI | **V1** | FR (défaut) / EN |
| EF-S03 | Langue audio / subtil préférée | **MVP** | Préférence VOSTFR ou VF |
| EF-S04 | Thème | **V1** | Clair / sombre / système |
| EF-S05 | Extension domaine provider | **MVP** | Config `SITE_EXTENSION` / domaines (existant) |
| EF-S06 | Providers multiples | **V1** | Liste ordonnée de providers / stratégies de resolve |
| EF-S07 | Connexion AniList OAuth | **MVP** | Login / logout / statut (existant) |
| EF-S08 | Sync listes AniList | **MVP** | Pull / push statuts, progress, score |
| EF-S09 | Mode sync | **V1** | Manuel / à l’ouverture / périodique |
| EF-S10 | Résolution conflits sync | **V1** | Règle « local wins » / « remote wins » / plus récent |
| EF-S11 | Chemin mpv / ani-cli | **MVP** | Chemins binaires configurables |
| EF-S12 | Dossier downloads | **V2** | Chemin stockage offline |

### 4.8 Social léger (optionnel)

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-SO01 | Commentaires locaux | **V2** | Notes longues attachées à un média (privées) |
| EF-SO02 | Export listes | **V2** | Export JSON / CSV (MalSync-like simplifié) |
| EF-SO03 | Import listes | **V2** | Import JSON / CSV vers SQLite (+ sync AniList optionnelle) |
| EF-SO04 | Partage lien AniList | **V3** | Ouvrir la page AniList publique du titre |
| EF-SO05 | Activity feed distant | — | **Hors scope** |

### 4.9 Admin / technique (app perso)

| ID | Fonctionnalité | Priorité | Description |
|----|----------------|----------|-------------|
| EF-A01 | Logs applicatifs | **MVP** | Fichier / écran de logs récents (resolve, sync, lecture) |
| EF-A02 | Cache métadonnées | **MVP** | Cache AniList/Jikan avec TTL et invalidation |
| EF-A03 | Clear cache | **MVP** | Bouton vider cache images / API |
| EF-A04 | Clear data locale | **V1** | Reset progress / hides / préférences (avec confirmation) |
| EF-A05 | Mises à jour app | **V1** | Vérification de version / updater Tauri |
| EF-A06 | Backup SQLite | **V1** | Export `.db` horodaté |
| EF-A07 | Restore backup | **V1** | Restauration depuis backup |
| EF-A08 | Diagnostics | **V1** | Health : mpv trouvé, réseau, AniList token valide |
| EF-A09 | Mode debug resolve | **V2** | Tracer le fuzzy match provider (utile anime-sama) |

---

## 5. Exigences non fonctionnelles

| ID | Catégorie | Exigence | Priorité |
|----|-----------|----------|----------|
| ENF-01 | Performance | Accueil interactif &lt; 2 s sur machine de référence (SSD, cache chaud) | **MVP** |
| ENF-02 | Performance | Seek lecteur fluide ; pas de freeze UI pendant resolve | **MVP** |
| ENF-03 | Performance | Planning saison : cache client + serveur (déjà en place côté prototype) | **MVP** |
| ENF-04 | Offline | Métadonnées et listes consultables offline après sync (V1 lecture online OK) | **V1** |
| ENF-05 | Offline | Lecture fichiers téléchargés sans réseau | **V2** |
| ENF-06 | UX | Navigation clavier sur lecteur et listes | **MVP** |
| ENF-07 | UX | États vides / erreur / loading explicites | **MVP** |
| ENF-08 | UX | Pas de pub, pas de tracking tiers analytics | **MVP** |
| ENF-09 | Sécurité locale | Secrets OAuth : pas de commit ; token stocké localement (secure storage Tauri à terme) | **MVP** |
| ENF-10 | Sécurité locale | Pas d’écoute réseau exposée inutilement ; bind localhost pour API embed | **MVP** |
| ENF-11 | Multi-OS | Windows 10/11 prioritaire | **MVP** |
| ENF-12 | Multi-OS | Linux (AppImage/deb) | **V1** |
| ENF-13 | Multi-OS | macOS | **V2** |
| ENF-14 | Fiabilité | Sync AniList résiliente (queue, retry, rate-limit) | **MVP** |
| ENF-15 | Fiabilité | Providers : échec soft + fallback (URL externe / autre provider) | **MVP** |
| ENF-16 | Maintenabilité | Typage TypeScript end-to-end ; schéma SQLite versionné (migrations) | **MVP** |
| ENF-17 | Stockage | Taille DB raisonnable ; images en cache disque éviction LRU | **V1** |
| ENF-18 | Accessibilité | Contrastes thème sombre/clair ; focus visible | **V2** |

---

## 6. Architecture cible

### 6.1 Vue d’ensemble

```
┌─────────────────────────────────────────────────────────┐
│                    App Desktop (Tauri)                  │
│  ┌─────────────────────┐  ┌──────────────────────────┐  │
│  │  UI React / Vite    │  │  Rust commands (Tauri)   │  │
│  │  pages, player UI   │◄─┤  fs, notifications,      │  │
│  │  settings, lists    │  │  process spawn, updater  │  │
│  └─────────┬───────────┘  └────────────┬─────────────┘  │
│            │                           │                │
│  ┌─────────▼───────────────────────────▼─────────────┐  │
│  │         Couche domaine / services locaux          │  │
│  │  catalog · lists · progress · resolve · download  │  │
│  └─────────┬─────────────────┬─────────────┬─────────┘  │
│            │                 │             │            │
│     ┌──────▼──────┐   ┌──────▼──────┐ ┌───▼────────┐   │
│     │   SQLite    │   │ AniList API │ │ Jikan/MAL  │   │
│     │  (source de │   │  (OAuth +   │ │ (fallback  │   │
│     │   vérité)   │   │   GraphQL)  │ │  meta)     │   │
│     └─────────────┘   └─────────────┘ └────────────┘   │
│            │                                            │
│     ┌──────▼──────────────────────────────┐             │
│     │  Playback : mpv (IPC) / ani-cli     │             │
│     │  Resolve : anime-sama (+ FlareSolverr)│            │
│     └─────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────┘
```

### 6.2 Composants

| Composant | Rôle |
|-----------|------|
| **UI (React + Vite)** | Réutiliser / faire évoluer le prototype dashboard |
| **Tauri shell** | Fenêtre native, FS, notifications, updater, secure storage |
| **SQLite** | Listes, progress, timestamps, hides, cache meta, downloads |
| **AniList** | Métadonnées riches, OAuth, sync listes |
| **Jikan** | Complément / fallback métadonnées MAL |
| **Resolve layer** | Fuzzy match titre → URL / stream (anime-sama, autres) |
| **mpv** | Moteur de lecture haute qualité + raccourcis natifs |
| **ani-cli** | Option alternative de résolution / lecture CLI |
| **FlareSolverr** | Contournement anti-bot pour certains providers (optionnel) |

### 6.3 Transition depuis le prototype actuel

| Aujourd’hui (web) | Cible |
|-------------------|-------|
| Express stateless | Services locaux + SQLite (API embed ou commands Tauri) |
| localStorage (token, hides) | SQLite + secure storage |
| sessionStorage cache planning | Cache SQLite / disque TTL |
| Bouton « Regarder » → URL externe | Lecteur intégré mpv + fallback URL |
| Docker + nginx | Installateur desktop ; Docker reste utile pour FlareSolverr |

---

## 7. Modèle de données

Tables principales (SQLite). Les noms sont indicatifs ; les migrations versionnent le schéma.

### 7.1 `media`

| Colonne | Type | Description |
|---------|------|-------------|
| id | TEXT PK | ID local (UUID) |
| anilist_id | INTEGER UNIQUE | ID AniList |
| mal_id | INTEGER NULL | ID MAL / Jikan |
| title_romaji | TEXT | Titre romaji |
| title_english | TEXT NULL | Titre anglais |
| title_native | TEXT NULL | Titre natif |
| format | TEXT | TV, MOVIE, OVA, ONA, SPECIAL… |
| status | TEXT | RELEASING, FINISHED… |
| episodes | INTEGER NULL | Nombre d’épisodes |
| duration | INTEGER NULL | Minutes / épisode |
| season | TEXT NULL | WINTER/SPRING/SUMMER/FALL |
| season_year | INTEGER NULL | Année |
| cover_url | TEXT NULL | Cover |
| banner_url | TEXT NULL | Banner |
| description | TEXT NULL | Synopsis |
| genres_json | TEXT | JSON genres |
| updated_at | TEXT | ISO datetime |

### 7.2 `media_relation`

| Colonne | Type | Description |
|---------|------|-------------|
| media_id | TEXT | FK media |
| related_media_id | TEXT | FK media |
| relation_type | TEXT | SEQUEL, PREQUEL, SIDE_STORY… |

### 7.3 `list_entry`

| Colonne | Type | Description |
|---------|------|-------------|
| id | TEXT PK | |
| media_id | TEXT FK | |
| status | TEXT | CURRENT, PLANNING, COMPLETED, PAUSED, DROPPED |
| progress | INTEGER | Dernier épisode vu |
| score | REAL NULL | Note perso |
| favorite | INTEGER | 0/1 |
| notes | TEXT NULL | Mémo |
| hidden_from_planning | INTEGER | 0/1 |
| anilist_entry_id | INTEGER NULL | Sync |
| updated_at | TEXT | |
| synced_at | TEXT NULL | |

### 7.4 `custom_list` / `custom_list_item` (V2)

| Table | Rôle |
|-------|------|
| custom_list | id, name, created_at |
| custom_list_item | list_id, media_id, position |

### 7.5 `episode_progress`

| Colonne | Type | Description |
|---------|------|-------------|
| id | TEXT PK | |
| media_id | TEXT FK | |
| episode_number | REAL | Support 12.5 si besoin |
| watched | INTEGER | 0/1 |
| position_seconds | REAL | Reprise exacte |
| duration_seconds | REAL NULL | |
| completed_at | TEXT NULL | |
| updated_at | TEXT | |

### 7.6 `watch_history`

| Colonne | Type | Description |
|---------|------|-------------|
| id | TEXT PK | |
| media_id | TEXT | |
| episode_number | REAL | |
| started_at | TEXT | |
| ended_at | TEXT NULL | |
| watched_seconds | REAL | |

### 7.7 `airing_schedule`

| Colonne | Type | Description |
|---------|------|-------------|
| id | TEXT PK | |
| media_id | TEXT | |
| episode | INTEGER | |
| airs_at | TEXT | UTC ISO |
| notified | INTEGER | 0/1 |

### 7.8 `provider_source`

| Colonne | Type | Description |
|---------|------|-------------|
| id | TEXT PK | |
| media_id | TEXT | |
| provider | TEXT | anime-sama, ani-cli, … |
| external_url | TEXT NULL | |
| external_slug | TEXT NULL | |
| language | TEXT | VOSTFR, VF… |
| last_resolved_at | TEXT NULL | |
| confidence | REAL NULL | Score fuzzy match |

### 7.9 `download_job` (V2)

| Colonne | Type | Description |
|---------|------|-------------|
| id | TEXT PK | |
| media_id | TEXT | |
| episode_number | REAL | |
| status | TEXT | queued, running, paused, done, error |
| quality | TEXT NULL | |
| file_path | TEXT NULL | |
| bytes_total | INTEGER NULL | |
| bytes_done | INTEGER NULL | |
| error | TEXT NULL | |

### 7.10 `app_settings`

| Colonne | Type | Description |
|---------|------|-------------|
| key | TEXT PK | |
| value | TEXT | JSON ou scalaire |

Exemples de clés : `theme`, `preferred_audio`, `mpv_path`, `ani_cli_path`, `site_extension`, `autoplay_next`, `watched_threshold`, `sync_mode`, `download_dir`.

### 7.11 `meta_cache`

| Colonne | Type | Description |
|---------|------|-------------|
| cache_key | TEXT PK | |
| payload | TEXT | JSON |
| expires_at | TEXT | |

---

## 8. Priorisation MVP / V1 / V2 / V3

### 8.1 Synthèse MoSCoW par phase

| Phase | Must | Should | Could |
|-------|------|--------|-------|
| **MVP** | Home + continue, catalogue recherche, saisons, fiches + relations, listes CURRENT/PLANNING/COMPLETED, hide planning, score, lecteur basique mpv, next ep, reprise timestamp, sync AniList, resolve provider + fallback URL, logs/cache | Qualités, VF/VO | — |
| **V1** | Calendrier hebdo, Paused/Dropped, filtres catalogue, similaires/trending, auto nouvelle saison, audio/subs, providers multiples, backup SQLite, updater, Linux | Hero, specials, estimation temps | — |
| **V2** | Downloads + offline, skip intro/outro, PiP, listes custom, notifications, export/import, macOS | Trailers, tags, notes | — |
| **V3** | — | Filler tags, auto-delete downloads, crop mpv | Activity sociale distante (**won't**) |

### 8.2 Feuille de route indicative

```
MVP  → Socle quotidien : listes + planning + lecture + reprise + sync
V1   → Plateforme « complète online » : découverte riche + calendrier + robustesse
V2   → Confort & mobilité : offline, notifications, personnalisation avancée
V3   → Expérimental / polish
```

### 8.3 Lien avec le prototype actuel

Déjà approximativement couvert (à consolider en MVP) :

- Planning saison + hide local
- Catalogue recherche AniList
- Listes À regarder / Déjà vu (CURRENT+PLANNING / COMPLETED)
- Fiche anime + resolve anime-sama
- Settings OAuth AniList + extension domaine

À construire pour clôturer le MVP : SQLite, continue watching, lecteur mpv, timestamp, next episode, relations multi-saisons, historique.

---

## 9. Critères d’acceptation — MVP

Un build MVP est **accepté** si tous les critères suivants sont validés manuellement sur Windows.

### 9.1 Découverte & fiches

| # | Critère |
|---|---------|
| A1 | L’accueil affiche au moins « Continuer » et un accès saison courante |
| A2 | La recherche AniList retourne des résultats et ouvre une fiche |
| A3 | La fiche affiche synopsis, cover, format, épisodes, genres |
| A4 | Les relations (suite/préquelle) sont navigables |
| A5 | Le planning Hiver/Printemps/Été/Automne + année fonctionne |

### 9.2 Listes

| # | Critère |
|---|---------|
| A6 | Connexion AniList OAuth réussie ; statut visible dans Paramètres |
| A7 | Les listes Watching / Planning / Completed se chargent et se mettent à jour |
| A8 | Ajout / changement de statut depuis la fiche persiste (local + sync AniList) |
| A9 | Score perso enregistré |
| A10 | Masquer / réafficher un anime du planning survit au redémarrage |

### 9.3 Lecture & progression

| # | Critère |
|---|---------|
| A11 | Depuis une fiche, démarrer la lecture (mpv) d’un épisode résolu **ou** fallback URL si resolve échoue |
| A12 | Play / pause / seek / volume / fullscreen opérationnels |
| A13 | Fermer au milieu d’un épisode → reprendre au même timestamp à la réouverture |
| A14 | À ≥ seuil configuré (défaut 90 %), l’épisode est marqué vu et `progress` incrémente |
| A15 | Fin d’épisode → proposition / autoplay épisode suivant |
| A16 | Raccourcis clavier documentés fonctionnent dans le lecteur |

### 9.4 Technique

| # | Critère |
|---|---------|
| A17 | Données utilisateur principales en SQLite (listes, progress, hides, settings) |
| A18 | Cache API invalidable depuis Paramètres |
| A19 | Logs consultables pour un échec de resolve |
| A20 | Aucun secret OAuth dans le dépôt ; token non loggé en clair |

---

## 10. Hors scope / risques

### 10.1 Hors scope rappel

- SaaS multi-tenant, comptes famille, abonnements.
- Hébergement ou redistribution de flux vidéo.
- Réseau social public.
- Catalogue généraliste hors anime.
- Garantie de disponibilité d’un provider tiers.

### 10.2 Risques

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Providers (anime-sama, etc.) changent DOM / domaine / Cloudflare | Resolve cassé | Abstraction multi-providers, extension configurable, fallback URL, tests de smoke |
| Rate-limit AniList | Sync / planning dégradés | Queue, cache TTL, backoff (déjà amorcé côté API) |
| FlareSolverr indisponible | Resolve bloqué | Marquer FlareSolverr optionnel ; message UX clair |
| Légalité des sources | Responsabilité utilisateur | Disclaimer in-app + docs ; pas de redistribution |
| mpv / ani-cli absents sur la machine | Pas de lecture native | Détection binaire + guide install + fallback navigateur |
| Dérive schéma SQLite | Perte données | Migrations versionnées + backup avant migrate |
| Scope creep « Netflix complet » | Retard MVP | Respect strict des tags MVP ; V2+ pour offline/PiP/skip |
| Sync conflictuelle AniList ↔ local | Progression incorrecte | Règle de conflit explicite + horodatage `updated_at` |

### 10.3 Hypothèses

- Un seul utilisateur humain par installation.
- Windows est la plateforme de validation MVP.
- L’utilisateur possède (ou créera) une app OAuth AniList.
- La qualité de la métadonnée prime sur la garantie de stream.

---

## Annexes

### A. Glossaire

| Terme | Définition |
|-------|------------|
| Broadcast season | Saison de diffusion JP : Winter / Spring / Summer / Fall |
| VOSTFR | Version originale sous-titrée français |
| VF | Version française doublée |
| Resolve | Résolution d’un titre catalogue → source lisible |
| Continue watching | Rangée des titres avec reprise en cours |
| AniSkip | Base communautaire de timestamps intro/outro (option V2) |

### B. Traçabilité prototype → exigences

| Zone prototype actuelle | Exigences liées |
|-------------------------|-----------------|
| `PlanningPage` | EF-D10, EF-C01, EF-C08, EF-L08 |
| `CatalogPage` | EF-D04, EF-D05 |
| `UserListPage` (towatch / viewed) | EF-L01, EF-L02, EF-L03 |
| `AnimeDetailPage` | EF-D11, EF-P18 |
| `SettingsPage` + OAuth | EF-S05, EF-S07, EF-S08 |
| `sama-resolve.service` | EF-P18, provider_source |
| localStorage hides / token | → migrer vers SQLite / secure storage |

### C. Références

- Prototype README du dépôt (`README.md`)
- AniList GraphQL API — https://anilist.gitbook.io/anilist-apiv2-docs/
- Jikan API — https://docs.api.jikan.moe/
- Tauri — https://v2.tauri.app/
- mpv — https://mpv.io/

---

*Document rédigé pour usage personnel de planification produit. Les priorités MVP / V1 / V2 / V3 guident le découpage d’implémentation ; toute évolution de provider ou de stack devra mettre à jour les sections 6, 7 et 10.*
