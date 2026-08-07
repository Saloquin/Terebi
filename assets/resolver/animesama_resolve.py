#!/usr/bin/env python3
"""Wrapper de résolution VOSTFR/VF pour Terebi.

Réutilise les fonctions du projet animesama-cli (https://github.com/Miro-sh/animesama-cli,
fichier `anime_sama.py`) pour résoudre l'URL directe d'un flux vidéo (m3u8/mp4)
SANS lancer de lecteur — Terebi joue ensuite l'URL dans son lecteur media_kit encastré.

Sortie (stdout) :
  RESOLVED_URL: <url>      en cas de succès
  RESOLVE_ERROR: <message> en cas d'échec (exit code non nul)

Usage :
  python animesama_resolve.py --script /chemin/anime_sama.py \
      --title "Dr Stone" --season 2 --episode 1 [--vf]
"""
import argparse
import importlib.util
import sys


def _load_anime_sama(script_path):
    spec = importlib.util.spec_from_file_location("anime_sama", script_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Script anime_sama introuvable : {script_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _pick_season(seasons, wanted):
    """Choisit l'entrée de saison correspondant au numéro voulu.

    `seasons` : liste de dicts {name, url}. On cherche « Saison <wanted> » ;
    à défaut, si wanted == 1 et une seule saison régulière, on la prend ;
    sinon on retombe sur la 1re.
    """
    import re
    for s in seasons:
        m = re.search(r'saison\s+(\d+)', s['name'], re.IGNORECASE)
        if m and int(m.group(1)) == wanted:
            return s
    # Pas de correspondance explicite : défaut = première saison.
    return seasons[0] if seasons else None


def main():
    parser = argparse.ArgumentParser(description="Résolveur d'URL anime-sama pour Terebi")
    parser.add_argument("--script", required=True, help="Chemin vers anime_sama.py")
    parser.add_argument("--title", required=True, help="Titre de recherche")
    parser.add_argument("--season", type=int, default=1, help="Numéro de saison")
    parser.add_argument("--episode", type=int, default=1, help="Numéro d'épisode")
    parser.add_argument("--vf", action="store_true", help="Version française (défaut VOSTFR)")
    args = parser.parse_args()

    try:
        import requests
        mod = _load_anime_sama(args.script)
        dl = mod.AnimeDownloader(debug=False)

        # 1. Recherche.
        animes, urls = dl.get_catalogue(args.title, vf=args.vf)
        if not animes:
            print(f"RESOLVE_ERROR: aucun anime trouvé pour « {args.title} »")
            sys.exit(1)
        anime_url = urls[0]

        # 2. Saisons.
        resp = requests.get(anime_url, headers=mod.HEADERS_BASE, timeout=15)
        seasons = mod.get_seasons(resp.text)
        if not seasons:
            print("RESOLVE_ERROR: aucune saison trouvée")
            sys.exit(1)
        season = _pick_season(seasons, args.season)
        if season is None:
            print(f"RESOLVE_ERROR: saison {args.season} introuvable")
            sys.exit(1)

        # 3. Épisodes.
        season_url = anime_url.rstrip('/') + '/' + season['url'].lstrip('/')
        if args.vf:
            season_url = season_url.replace("vostfr", "vf")
        filever = mod.get_episode_list(season_url)
        episodes = dl.get_anime_episode(season_url, filever)
        if not episodes:
            print("RESOLVE_ERROR: aucun épisode trouvé")
            sys.exit(1)

        ep_key = str(args.episode)
        if ep_key not in episodes:
            print(f"RESOLVE_ERROR: épisode {args.episode} indisponible "
                  f"(dispo : {', '.join(list(episodes.keys())[:10])})")
            sys.exit(1)

        # 4. Résolution URL.
        url = dl.resolve_video_url(episodes[ep_key])
        if not url:
            print("RESOLVE_ERROR: aucune URL de flux résolue")
            sys.exit(1)

        # Normalise les URLs protocol-relative (//host/...) en https.
        if url.startswith("//"):
            url = "https:" + url
        print(f"RESOLVED_URL: {url}")
        sys.exit(0)

    except Exception as e:  # noqa: BLE001 — on renvoie toute erreur proprement
        print(f"RESOLVE_ERROR: {type(e).__name__}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
