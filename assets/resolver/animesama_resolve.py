#!/usr/bin/env python3
"""Wrapper de résolution VOSTFR/VF pour Terebi.

Réutilise les fonctions du projet animesama-cli (https://github.com/Miro-sh/animesama-cli,
fichier `anime_sama.py`) pour :
  - lister les saisons d'un anime (action list-seasons) ;
  - lister les épisodes d'une saison (action list-episodes) ;
  - résoudre l'URL directe d'un flux vidéo (action resolve, défaut).

anime-sama regroupe les saisons (Saison 1, 2, OAV…). Terebi affiche cette liste et
l'utilisateur choisit ; le `--season` de `resolve`/`list-episodes` est l'INDEX
(1-based) dans la liste renvoyée par list-seasons.

Sortie (stdout), une ligne préfixée :
  SEASONS_JSON: [{"index":1,"name":"Saison 1"}, ...]
  EPISODES_JSON: ["1","2", ...]
  RESOLVED_URL: <url>
  RESOLVE_ERROR: <message>   (+ exit code 1)

Usage :
  python animesama_resolve.py --script <anime_sama.py> --action list-seasons --title "Dr Stone" [--vf]
  python animesama_resolve.py --script <anime_sama.py> --action list-episodes --title "Dr Stone" --season 2 [--vf]
  python animesama_resolve.py --script <anime_sama.py> --action resolve --title "Dr Stone" --season 2 --episode 1 [--vf]
"""
import argparse
import importlib.util
import json
import sys


def _load_anime_sama(script_path):
    spec = importlib.util.spec_from_file_location("anime_sama", script_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Script anime_sama introuvable : {script_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _fail(msg):
    print(f"RESOLVE_ERROR: {msg}")
    sys.exit(1)


def _seasons_for(mod, dl, title, vf):
    """Retourne (anime_url, seasons[]) ou lève une erreur via _fail."""
    import requests
    animes, urls = dl.get_catalogue(title, vf=vf)
    if not animes:
        _fail(f"aucun anime trouvé pour « {title} »")
    anime_url = urls[0]
    resp = requests.get(anime_url, headers=mod.HEADERS_BASE, timeout=15)
    seasons = mod.get_seasons(resp.text)
    if not seasons:
        _fail("aucune saison trouvée")
    return anime_url, seasons


def _episodes_for(mod, dl, anime_url, season, vf):
    """Retourne le dict {ep_key: [video_ids]} pour une saison donnée."""
    season_url = anime_url.rstrip('/') + '/' + season['url'].lstrip('/')
    if vf:
        season_url = season_url.replace("vostfr", "vf")
    filever = mod.get_episode_list(season_url)
    return dl.get_anime_episode(season_url, filever)


def _pick_by_index(seasons, index):
    """Saison par index 1-based dans la liste anime-sama. None si hors bornes."""
    if 1 <= index <= len(seasons):
        return seasons[index - 1]
    return None


def action_list_seasons(mod, dl, args):
    _, seasons = _seasons_for(mod, dl, args.title, args.vf)
    payload = [
        {"index": i, "name": s.get('name', f'Saison {i}')}
        for i, s in enumerate(seasons, 1)
    ]
    print(f"SEASONS_JSON: {json.dumps(payload, ensure_ascii=False)}")
    sys.exit(0)


def action_list_episodes(mod, dl, args):
    anime_url, seasons = _seasons_for(mod, dl, args.title, args.vf)
    season = _pick_by_index(seasons, args.season)
    if season is None:
        _fail(f"saison #{args.season} hors bornes (1..{len(seasons)})")
    episodes = _episodes_for(mod, dl, anime_url, season, args.vf)
    if not episodes:
        _fail("aucun épisode trouvé")
    # Épisodes triés numériquement quand possible.
    keys = sorted(episodes.keys(), key=lambda k: int(k) if k.isdigit() else 1 << 30)
    print(f"EPISODES_JSON: {json.dumps(keys, ensure_ascii=False)}")
    sys.exit(0)


def action_resolve(mod, dl, args):
    anime_url, seasons = _seasons_for(mod, dl, args.title, args.vf)
    season = _pick_by_index(seasons, args.season)
    if season is None:
        _fail(f"saison #{args.season} hors bornes (1..{len(seasons)})")
    episodes = _episodes_for(mod, dl, anime_url, season, args.vf)
    if not episodes:
        _fail("aucun épisode trouvé")
    ep_key = str(args.episode)
    if ep_key not in episodes:
        _fail(f"épisode {args.episode} indisponible "
              f"(dispo : {', '.join(list(episodes.keys())[:10])})")
    url = dl.resolve_video_url(episodes[ep_key])
    if not url:
        _fail("aucune URL de flux résolue")
    if url.startswith("//"):
        url = "https:" + url
    print(f"RESOLVED_URL: {url}")
    sys.exit(0)


def main():
    parser = argparse.ArgumentParser(description="Résolveur anime-sama pour Terebi")
    parser.add_argument("--script", required=True, help="Chemin vers anime_sama.py")
    parser.add_argument("--action", default="resolve",
                        choices=["resolve", "list-seasons", "list-episodes"])
    parser.add_argument("--title", required=True, help="Titre de recherche")
    parser.add_argument("--season", type=int, default=1,
                        help="Index de saison (1-based, cf. list-seasons)")
    parser.add_argument("--episode", type=int, default=1, help="Numéro d'épisode")
    parser.add_argument("--vf", action="store_true", help="Version française (défaut VOSTFR)")
    args = parser.parse_args()

    try:
        mod = _load_anime_sama(args.script)
        dl = mod.AnimeDownloader(debug=False)
        if args.action == "list-seasons":
            action_list_seasons(mod, dl, args)
        elif args.action == "list-episodes":
            action_list_episodes(mod, dl, args)
        else:
            action_resolve(mod, dl, args)
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001 — on renvoie toute erreur proprement
        print(f"RESOLVE_ERROR: {type(e).__name__}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
