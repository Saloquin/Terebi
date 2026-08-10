# Terebi

> **Terebi** (テレビ, « télé ») — application desktop personnelle de suivi, planning et visionnage
> d'anime, avec lecteur vidéo intégré.

⚠️ **Réécriture en cours (from scratch).** Le prototype web précédent (Vite/React/Express +
anime-sama) a été supprimé. Il reste récupérable via le tag git `proto-web-backup-2026-08-06`.

## Vision

Terebi est un **tracker + planning + lecteur intégré** d'anime :

- **Suivi** : statuts (en cours / à voir / vu / en pause / abandonné), épisode courant, timestamp,
  progression par saison de franchise — source de vérité **locale (SQLite)**.
- **Planning** : saisons de diffusion et calendrier hebdomadaire via AniList (airing schedule).
- **Découverte** : catalogue, recherche, fiches, relations — métadonnées AniList + Jikan.
- **Lecture** : lecteur vidéo **encastré** dans l'app, avec overlays et reprise au timestamp exact.

## Stack cible

| Couche | Technologie |
|--------|-------------|
| UI | **Flutter** (desktop) |
| Lecteur | **media_kit** (libmpv) — vidéo encastrée + overlays |
| Persistance | **SQLite** (drift) — source de vérité du suivi |
| Métadonnées | **AniList** (GraphQL, OAuth) + **Jikan** (fallback) |
| Résolution de source | **anime-sama** (VOSTFR/VF) via wrapper Python (animesama-cli) — fournit l'URL du flux |
| Plateforme | **Windows** prioritaire, puis Linux, macOS |

## Documentation

- **Cahier des charges** : [`docs/CAHIER_DES_CHARGES_STREAMING.md`](docs/CAHIER_DES_CHARGES_STREAMING.md)
- **Backlog produit** (source de vérité de l'implémentation) : [`docs/BACKLOG.md`](docs/BACKLOG.md)

## État

Projet en phase de démarrage. Voir le backlog pour les EPICs, user stories et la feuille de route
(MVP → V1 → V2 → V3). Le premier jalon est un **spike technique (US-00)** validant la résolution
d'URL de flux avant de graver le reste du MVP.
