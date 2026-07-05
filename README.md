# Anime-Sama Dashboard

Dashboard personnel pour suivre le planning, le catalogue et votre liste de visionnage sur [anime-sama](https://anime-sama.pw).

## Fonctionnalités

- **Planning hebdomadaire** — Animes du jour avec filtres, onglets nouveaux/anciens/masqués
- **Catalogue** — Recherche et pagination d'animes et films VOSTFR via FlareSolverr
- **À regarder / Déjà vu** — Listes persistantes en localStorage avec suivi par saison
- **Fiche anime** — Saisons, marquage vu/non-vu, lecteur intégré (iframe), suivi d'épisode
- **Sync automatique** — Détection des nouvelles saisons pour les animes déjà vus → ajout auto à « À regarder »
- **Navigation** — React Router avec URLs partageables (`/planning`, `/catalog`, `/towatch`, `/anime/:slug`)

## Prérequis

- Node.js 18+
- [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) (contournement Cloudflare) — voir `docker-compose.yml`

## Installation

```bash
git clone <votre-repo>
cd Dashboard-sama-scrapper

# Frontend + API
npm run install:all
```

## Développement

```bash
# FlareSolverr (Docker)
docker compose up -d flaresolverr

# Frontend (port 3000) + API (port 3001)
npm run dev
```

Le proxy CRA redirige `/api/*` vers `http://localhost:3001`.

Variables d'environnement optionnelles :

| Variable | Description | Défaut |
|----------|-------------|--------|
| `FLARESOLVERR_URL` | URL FlareSolverr (API) | `http://localhost:8191/v1` |
| `REACT_APP_API_URL` | URL API (frontend) | `/api` |

## API Backend

| Endpoint | Description |
|----------|-------------|
| `GET /api/animes` | Planning complet |
| `GET /api/animes/today` | Animes du jour |
| `GET /api/animes/catalogue?search=&page=&type=` | Catalogue (pagination réelle) |
| `GET /api/animes/seasons/:slug` | Saisons d'un anime |
| `GET /api/animes/seasons/:slug/episodes?url=` | Nombre d'épisodes d'une saison |
| `POST /api/animes/refresh` | Force le rafraîchissement du cache planning |
| `GET /api/config/detect-extension` | Détection du domaine actif (.to, .pw, etc.) |

## Structure

```
src/                    # Frontend React + TypeScript
  components/           # Pages et composants UI
  hooks/                # useAnimeData, useAnimeSeasons
  services/api/         # Client API et sync localStorage
  utils/tabLogic/       # Logique planning / towatch / viewed
api/                    # Backend Express + scrapers FlareSolverr
  src/services/         # planning, catalog, season-scraper
```

## Build

```bash
npm run build:all
```

## Stockage local

Les listes (planning, à regarder, déjà vu, saisons vues, progression épisodes) sont stockées dans le navigateur (`localStorage`). Aucune donnée utilisateur n'est envoyée à un serveur tiers.

## Notes

- Le lecteur intégré charge la page anime-sama en iframe ; le suivi d'épisode est manuel (numéro d'épisode sauvegardé localement).
- Le temps de visionnage estimé : 24 min/épisode, 2 h/film.
- FlareSolverr est requis pour le scraping (Cloudflare).
