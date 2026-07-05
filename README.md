# Anime Dashboard

Dashboard personnel pour suivre les saisons d'anime (AniList) avec liens anime-sama à la demande.

## Stack

| Couche | Technologie |
|--------|-------------|
| Frontend | Vite + React 18 + TypeScript + Tailwind CSS |
| Backend | Express + TypeScript + SQLite (better-sqlite3) |
| Données anime | [AniList GraphQL API](https://anilist.co) (public) |
| Liens streaming | anime-sama (résolution à la demande via FlareSolverr) |

## Fonctionnalités

- **Planning** — Saison de diffusion courante (AniList), navigation hiver/printemps/été/automne, masquer/afficher des animes (persisté SQLite)
- **Catalogue** — Recherche AniList (plus de scrape catalogue complet)
- **À regarder / Déjà vu** — Listes persistées en SQLite par ID AniList
- **Fiche anime** — Détails AniList + boutons « Regarder » et « Fiche anime-sama » (résolution fuzzy + cache)

## Prérequis

- Node.js 18+
- FlareSolverr (uniquement pour les résolutions anime-sama) — voir `docker-compose.yml`

## Installation

```bash
git clone <votre-repo>
cd Dashboard-sama-scrapper
npm run install:all
```

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

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/anilist/season?season=&year=&page=` | Anime d'une saison |
| `GET /api/anilist/search?q=` | Recherche AniList |
| `GET /api/anilist/anime/:id` | Détail anime |
| `GET /api/anilist/current-season` | Saison courante |
| `GET /api/sama/resolve?title=` | URL catalogue anime-sama |
| `GET /api/sama/resolve?title=&season=N` | URL saison VOSTFR |
| `GET/POST/DELETE /api/user/hidden/:id` | Animes masqués (planning) |
| `GET/POST/DELETE /api/user/towatch/:id` | Liste à regarder |
| `GET/POST/DELETE /api/user/viewed/:id` | Liste déjà vu |
| `GET/PUT /api/user/episode-progress` | Progression épisodes (optionnel) |

## Structure

```
src/                 # Frontend Vite + React
  api/client.ts      # Client REST
  pages/             # Planning, Catalog, ToWatch, Anime detail
api/src/
  services/anilist.service.ts    # Proxy AniList GraphQL
  services/sama-resolve.service.ts  # Fuzzy match + cache
  db/init.ts         # SQLite: hidden_animes, sama_cache, user_lists
```

## Build

```bash
npm run build:all
```

## Supprimé / remplacé

- Frontend CRA (react-scripts) → Vite + React
- Planning scrape anime-sama comme source principale → AniList seasonal
- Onglets new/old/current → navigation par saison AniList
- Catalogue scrape anime-sama → recherche AniList
- localStorage comme stockage principal → SQLite via API REST

## Notes

- FlareSolverr n'est nécessaire que pour les boutons anime-sama (résolution catalogue/saison).
- Le planning et le catalogue fonctionnent sans FlareSolverr (AniList direct).
