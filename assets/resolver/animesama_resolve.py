#!/usr/bin/env python3
"""Wrapper de résolution VOSTFR/VF pour Terebi.

Réutilise les fonctions du projet animesama-cli (https://github.com/Miro-sh/animesama-cli,
fichier `anime_sama.py`) pour :
  - lister les saisons d'un anime (action list-seasons) ;
  - lister les épisodes d'une saison (action list-episodes) ;
  - résoudre l'URL directe d'un flux vidéo (action resolve, défaut) ;
  - lister le planning hebdomadaire (action planning) — jour + heure + titre + url ;
  - rechercher dans le catalogue (action search).

anime-sama regroupe les saisons (Saison 1, 2, OAV…). Terebi affiche cette liste et
l'utilisateur choisit ; le `--season` de `resolve`/`list-episodes` est l'INDEX
(1-based) dans la liste renvoyée par list-seasons.

Sortie (stdout), une ligne préfixée :
  SEASONS_JSON: [{"index":1,"name":"Saison 1"}, ...]
  EPISODES_JSON: ["1","2", ...]
  CATALOGUE_JSON: [{"title":"...","url":"/catalogue/..."}, ...]
  PLANNING_JSON: [{"day":"Lundi","time":"18h00","title":"...","url":"/catalogue/...","seasonIndex":2}, ...]
  RESOLVED_URL: <url>
  RESOLVE_ERROR: <message>   (+ exit code 1)

Usage :
  python animesama_resolve.py --script <anime_sama.py> --action list-seasons --title "Dr Stone" [--vf]
  python animesama_resolve.py --script <anime_sama.py> --action list-episodes --title "Dr Stone" --season 2 [--vf]
  python animesama_resolve.py --script <anime_sama.py> --action resolve --title "Dr Stone" --season 2 --episode 1 [--vf]
  python animesama_resolve.py --script <anime_sama.py> --action search --title "dr stone" [--vf]
  python animesama_resolve.py --script <anime_sama.py> --action planning [--vf]
"""
import argparse
import importlib.util
import json
import re
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
    return anime_url, _dedupe_seasons(seasons)


def _dedupe_seasons(seasons):
    """Retire les doublons (get_seasons renvoie parfois plusieurs fois la même
    saison, ex. variantes VF/VOSTFR ou blocs répétés). Déduplique par url puis
    par nom normalisé, en conservant l'ordre d'apparition."""
    seen = set()
    result = []
    for s in seasons:
        url = (s.get('url') or '').strip().lower().rstrip('/')
        name = re.sub(r'[^a-z0-9]', '', (s.get('name') or '').lower())
        key = url or name
        if not key or key in seen:
            continue
        seen.add(key)
        result.append(s)
    return result


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


def action_search(mod, dl, args):
    """Recherche catalogue : renvoie la liste des animes correspondants."""
    animes, urls = dl.get_catalogue(args.title, vf=args.vf)
    payload = [
        {"title": t, "url": u}
        for t, u in zip(animes, urls)
    ]
    print(f"CATALOGUE_JSON: {json.dumps(payload, ensure_ascii=False)}")
    sys.exit(0)


def _planning_times(mod):
    """Récupère la page /planning/ et extrait un map titre_normalisé -> heure.

    L'heure n'est PAS dans le HTML statique (parsé par afficher_planning) : elle
    est dans le JS du planning, via des appels du type
      cartePlanningAnime("Titre", "url", "img", "HHhMM", "VOSTFR")
    On récupère les scripts (inline + externes) et on parse ces appels.
    """
    import requests
    domain = mod.DOMAIN
    times = {}
    try:
        base = f"https://{domain}/planning/"
        resp = requests.get(base, headers=mod.HEADERS_BASE, timeout=15)
        html = resp.text
        # Scripts à inspecter : le HTML lui-même + les .js référencés.
        blobs = [html]
        for m in re.finditer(r'<script[^>]+src="([^"]+)"', html):
            src = m.group(1)
            if 'planning' not in src.lower() and 'emission' not in src.lower():
                continue
            if src.startswith('//'):
                src = 'https:' + src
            elif src.startswith('/'):
                src = f"https://{domain}{src}"
            elif not src.startswith('http'):
                src = f"https://{domain}/planning/{src}"
            try:
                blobs.append(requests.get(src, headers=mod.HEADERS_BASE,
                                          timeout=15).text)
            except requests.RequestException:
                pass
        # cartePlanningAnime("Titre","url","img","HHhMM","VERSION")
        pattern = re.compile(
            r'cartePlanningAnime\(\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,'
            r'\s*"([^"]*)"\s*,\s*"([^"]*)"'
        )
        for blob in blobs:
            for m in pattern.finditer(blob):
                title = m.group(1).strip()
                time_str = m.group(4).strip()
                if title and time_str:
                    times[_norm(title)] = time_str
    except requests.RequestException:
        pass
    return times


def _norm(text):
    """Normalise un titre pour le matching (minuscule, alphanumérique)."""
    return re.sub(r'[^a-z0-9]', '', text.lower())


def action_planning(mod, dl, args):
    """Planning hebdomadaire : jour + heure + titre + url + index de saison courante.

    Réutilise la logique de scraping de afficher_planning() SANS interaction, et
    complète avec l'heure extraite du JS.
    """
    import requests
    domain = mod.DOMAIN
    url = f"https://{domain}/planning/"
    try:
        response = requests.get(url, headers=mod.HEADERS_BASE, timeout=15)
    except requests.RequestException as e:
        _fail(f"planning inaccessible : {e}")
        return
    html_content = response.text

    day_pattern = r'<h2 class="titreJours[^>]*>([^<]+)</h2>'
    days = re.findall(day_pattern, html_content)
    planning = {day.strip(): [] for day in days}
    day_sections = re.split(day_pattern, html_content)

    times = _planning_times(mod)

    items = []
    seen = {}  # (jour, titre_normalisé) -> index dans items
    for i in range(1, len(day_sections), 2):
        current_day = day_sections[i].strip()
        day_content = day_sections[i + 1]
        if current_day not in planning:
            continue
        cards = re.findall(
            r'<a href="(/catalogue/[^"]+)"[^>]*>.*?<h3[^>]*>([^<]+)</h3>',
            day_content, re.DOTALL
        )
        if not cards:
            cards = re.findall(
                r'<a href="(/catalogue/[^"]+)"[^>]*>.*?<img[^>]*alt="([^"]*)"',
                day_content, re.DOTALL
            )
        for card_url, card_title in cards:
            # Ignore les scans (mangas) — on ne garde que les animes.
            if hasattr(mod, '_is_scan_url') and mod._is_scan_url(card_url):
                continue
            raw_title = card_title.strip()
            url = card_url.strip()
            # anime-sama liste souvent le même anime en VF ET en VOSTFR : on
            # nettoie un éventuel suffixe de version et on déduplique par jour.
            title = re.sub(r'\s+(VOSTFR|VF)\s*$', '', raw_title, flags=re.I).strip()
            is_vf = ('/vf' in url.lower()) or bool(re.search(r'\bvf\b', raw_title, re.I))
            key = (current_day, _norm(title))
            if key in seen:
                # Doublon : on privilégie la version VOSTFR (remplace une VF déjà vue).
                idx = seen[key]
                if items[idx].get("_vf") and not is_vf:
                    items[idx] = {
                        "day": current_day,
                        "time": times.get(_norm(title), ""),
                        "title": title,
                        "url": url,
                        "_vf": is_vf,
                    }
                continue
            seen[key] = len(items)
            items.append({
                "day": current_day,
                "time": times.get(_norm(title), ""),
                "title": title,
                "url": url,
                "_vf": is_vf,
            })

    # Retire le champ interne _vf avant la sortie.
    for it in items:
        it.pop("_vf", None)

    print(f"PLANNING_JSON: {json.dumps(items, ensure_ascii=False)}")
    sys.exit(0)


def main():
    parser = argparse.ArgumentParser(description="Résolveur anime-sama pour Terebi")
    parser.add_argument("--script", required=True, help="Chemin vers anime_sama.py")
    parser.add_argument("--action", default="resolve",
                        choices=["resolve", "list-seasons", "list-episodes",
                                 "search", "planning"])
    parser.add_argument("--title", default="", help="Titre de recherche")
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
        elif args.action == "search":
            action_search(mod, dl, args)
        elif args.action == "planning":
            action_planning(mod, dl, args)
        else:
            action_resolve(mod, dl, args)
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001 — on renvoie toute erreur proprement
        print(f"RESOLVE_ERROR: {type(e).__name__}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
