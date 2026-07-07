# Anime Dashboard

Dashboard personnel pour suivre les saisons d'anime (AniList) avec liens anime-sama à la demande.

## Stack

| Couche | Technologie |
|--------|-------------|
| Frontend | Vite + React 18 + TypeScript + Tailwind CSS |
| Backend | Express + TypeScript (stateless) |
| Données utilisateur | [AniList GraphQL API](https://anilist.co) (OAuth2) |
| Données locales | localStorage navigateur (token, animes masqués) |
| Liens streaming | anime-sama (résolution à la demande via FlareSolverr) |

## Fonctionnalités

- **Planning** — Saison de diffusion courante (AniList public), navigation hiver/printemps/été/automne, masquer/afficher des animes (localStorage)
- **Catalogue** — Recherche AniList
- **À regarder / Déjà vu** — Listes AniList (CURRENT + PLANNING / COMPLETED) via OAuth
- **Fiche anime** — Détails AniList + boutons « Regarder » et « Fiche anime-sama »

## Prérequis

- Node.js 18+
- Compte développeur AniList ([anilist.co/settings/developer](https://anilist.co/settings/developer))
- FlareSolverr (uniquement pour anime-sama) — voir `docker-compose.yml`

## Installation

```bash
git clone <votre-repo>
cd Dashboard-sama-scrapper
npm run install:all
cp .env.example .env
```

Renseignez `ANILIST_CLIENT_ID` et `ANILIST_CLIENT_SECRET` dans `.env` (voir ci-dessous).

## Connexion AniList

Les identifiants OAuth sont saisis dans **Paramètres** (Client ID + Client Secret). Seul le token AniList est conservé localement.

1. Créez une application sur [anilist.co/settings/developer](https://anilist.co/settings/developer)
2. Enregistrez le **Redirect URI** correspondant à votre environnement (affiché dans Paramètres) :
   - **Développement** (`npm run dev`) : `http://localhost:5173/settings/callback`
   - **Docker** (`docker compose up`) : `http://localhost/settings/callback`
3. Saisissez Client ID et Client Secret dans **Paramètres**, puis cliquez **Connecter AniList**

Le Redirect URI est calculé automatiquement depuis l'URL courante (`window.location.origin + '/settings/callback'`).

Après autorisation, le token est stocké dans le navigateur (`localStorage` → `anilist_token`).

### Variables `.env` OAuth (optionnel — fallback backend)

| Variable | Description | Défaut dev | Défaut Docker |
|----------|-------------|------------|---------------|
| `ANILIST_CLIENT_ID` | Client ID OAuth | — | — |
| `ANILIST_CLIENT_SECRET` | Client Secret OAuth | — | — |
| `ANILIST_REDIRECT_URI` | Fallback si non fourni par le frontend | `http://localhost:5173/settings/callback` | `http://localhost/settings/callback` |
| `FRONTEND_URL` | URL frontend (redirect post-OAuth API callback) | `http://localhost:5173` | `http://localhost` |

## Développement

```bash
# FlareSolverr (optionnel, requis pour anime-sama)
docker compose up -d flaresolverr

# API (port 3001) + Frontend Vite (port 5173)
npm run dev
```

Le proxy Vite redirige `/api/*` vers `http://localhost:3001`.

| Variable | Description | Défaut |
|----------|-------------|--------|
| `FLARESOLVERR_URL` | URL FlareSolverr | `http://localhost:8191/v1` |
| `SITE_EXTENSION` | Extension anime-sama (.to, .pw…) | `to` |
| `API_PORT` | Port API | `3001` |

## Stockage des données

| Donnée | Emplacement |
|--------|-------------|
| Listes (watching, planning, completed…) | AniList (via API authentifiée) |
| Progression épisodes | AniList `mediaListEntry.progress` |
| Token OAuth | `localStorage` → clé `anilist_token` |
| Animes masqués (planning) | `localStorage` → clé `hidden_animes` |
| Cache planning (10 min) | `sessionStorage` → clé `planning_cache:{season}:{year}` |

## API

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/anilist/oauth/authorize-url` | — | URL OAuth (credentials `.env`) |
| `GET /api/anilist/auth/callback?code=` | — | Callback OAuth → redirect frontend avec token |
| `GET /api/anilist/oauth/status` | Bearer | Statut connexion |
| `GET /api/anilist/season?season=&year=` | — | Anime d'une saison |
| `GET /api/anilist/search?q=` | — | Recherche AniList |
| `GET /api/anilist/planning?season=&year=` | — | Planning saison |
| `GET /api/anilist/anime/:id` | — | Détail anime |
| `GET /api/anilist/me` | Bearer | Utilisateur connecté |
| `GET /api/anilist/lists?status=CURRENT,PLANNING` | Bearer | Entrées de liste |
| `POST /api/anilist/lists/:mediaId` | Bearer | Ajouter/modifier une entrée |
| `DELETE /api/anilist/lists/:mediaId` | Bearer | Retirer de la liste |
| `GET /api/sama/resolve?title=` | — | URL catalogue anime-sama |

## Structure

```
src/
  api/client.ts      # Client REST (+ Authorization header, cache planning)
  lib/storage.ts     # localStorage (token, hidden)
  pages/             # Planning, Catalog, ToWatch, Anime detail, Settings
api/src/
  services/anilist.service.ts    # Proxy AniList GraphQL + OAuth
  services/sama-resolve.service.ts  # Fuzzy match anime-sama
```

## Build

```bash
npm run build:all
```

## Production Docker

```bash
docker compose up -d --build
```

| Service | Port | URL |
|---------|------|-----|
| Frontend (nginx) | 80 | http://localhost |
| API | 3001 | http://localhost:3001 |
| FlareSolverr | 8191 | http://localhost:8191 |

**OAuth AniList en Docker** : enregistrez `http://localhost/settings/callback` comme Redirect URI sur AniList. Nginx sert le SPA (y compris `/settings/callback`) et proxy `/api/*` vers le backend.

FlareSolverr est requis uniquement pour les boutons anime-sama. Le planning et le catalogue AniList fonctionnent sans lui.

## Notes

- Pas de base de données locale : l'API est entièrement stateless.
- Les animes masqués dans le planning sont locaux au navigateur (non synchronisés AniList).
- Le planning met en cache les réponses AniList côté serveur (20 min) et côté client (10 min) pour limiter les requêtes.
