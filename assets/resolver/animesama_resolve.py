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
import contextlib
import importlib.util
import json
import os
import re
import sys


@contextlib.contextmanager
def _silence_output():
    """Étouffe stdout/stderr le temps d'un bloc. Le module anime_sama imprime des
    erreurs (« 404 … episodes.js ») pendant la validation des saisons ; on ne
    veut pas polluer notre sortie (préfixée SEASONS_JSON/…)."""
    with open(os.devnull, 'w') as devnull:
        old_out, old_err = sys.stdout, sys.stderr
        try:
            sys.stdout, sys.stderr = devnull, devnull
            yield
        finally:
            sys.stdout, sys.stderr = old_out, old_err


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


_STOPWORDS = {
    'the', 'a', 'an', 'of', 'to', 'in', 'and', 'le', 'la', 'les', 'un', 'une',
    'de', 'des', 'du', 'et', 'no', 'wa', 'ga', 'season', 'saison', 'part',
}


def _norm_title(s):
    return re.sub(r'[^a-z0-9]', '', (s or '').lower())


def _title_tokens(s):
    """Jetons significatifs (>=2 lettres, hors mots vides)."""
    return {
        t for t in re.split(r'[^a-z0-9]+', (s or '').lower())
        if len(t) >= 2 and t not in _STOPWORDS
    }


def _best_catalogue_index(query, animes):
    """Index du meilleur résultat catalogue pour [query], ou None si aucun n'est
    fiable.

    get_catalogue renvoie plusieurs animes. Prendre le 1er (ou un simple
    chevauchement de mots courants comme « the »/« princess ») peut tomber sur
    une grosse franchise sans rapport (d'où « 10 saisons + OAV »). On exige donc
    une correspondance FORTE : exacte > inclusion > chevauchement significatif
    (>= la moitié des jetons utiles de la requête). Sinon None (pas de match).
    """
    if not animes:
        return None
    qn = _norm_title(query)
    qt = _title_tokens(query)
    best_i, best_overlap = None, 0
    for i, name in enumerate(animes):
        nn = _norm_title(name)
        if nn == qn:
            return i  # correspondance exacte
        if qn and nn and (qn in nn or nn in qn):
            return i  # inclusion (sous-titre / suffixe)
        overlap = len(qt & _title_tokens(name))
        if overlap > best_overlap:
            best_overlap, best_i = overlap, i
    # Chevauchement significatif requis : au moins la moitié des jetons utiles
    # de la requête (et >= 1), pour éviter les faux positifs.
    if qt and best_overlap >= 1 and best_overlap * 2 >= len(qt):
        return best_i
    return None


def _search_catalogue(dl, title, vf):
    """Cherche [title] ; si aucun match fiable, réessaie avec des requêtes plus
    courtes en retirant le DERNIER mot à chaque tour. Retourne (anime_name,
    anime_url) ou None.

    Les titres AniList sont souvent plus longs que ceux d'anime-sama (suffixes
    « Season 3 », « Part 2 », sous-titre après « : »…). anime-sama ne trouve
    alors rien sur le titre complet. On dégrade donc mot par mot (du titre
    complet jusqu'au 1er mot) pour retrouver le nom de base présent sur
    anime-sama, en s'arrêtant au premier match fiable."""
    tokens = [t for t in re.split(r'[^A-Za-z0-9]+', title) if t]
    if not tokens:
        return None
    # Requêtes : titre complet, puis on retire le dernier mot à chaque tour,
    # jusqu'au 1er mot. Déduplication en conservant l'ordre.
    queries = []
    for n in range(len(tokens), 0, -1):
        q = ' '.join(tokens[:n])
        if q not in queries:
            queries.append(q)
    for q in queries:
        animes, urls = dl.get_catalogue(q, vf=vf)
        if not animes:
            continue
        idx = _best_catalogue_index(title, animes)
        if idx is not None and idx < len(urls):
            return animes[idx], urls[idx]
    return None


def _is_real_season(s):
    """Vrai si l'entrée est une VRAIE saison de l'anime courant (et non un
    anime recommandé / « voir aussi »). get_seasons capte TOUS les appels
    panneauAnime(...) de la page, y compris ceux de blocs de recommandations
    d'AUTRES animes → d'où « 10 saisons + OAV ». Une vraie saison a un chemin
    RELATIF court (ex. « saison1/vostfr », « oav/vf ») ; une reco pointe une
    autre page (http, //, /catalogue/, plusieurs segments de slug)."""
    url = (s.get('url') or '').strip().lower()
    if not url:
        return False
    if url.startswith('http') or url.startswith('//') or 'catalogue' in url:
        return False
    # Chemin relatif : on retire un éventuel suffixe de langue, il doit rester
    # au plus un segment (le nom de saison : saison1, oav, film, scan…).
    core = re.sub(r'/(vostfr|vf|va|vcn|vkr|vqc)\b', '', url).strip('/')
    return core != '' and core.count('/') == 0


def _url_has_id(url):
    """Vrai si l'URL vidéo contient un identifiant NON vide. anime-sama génère
    des URLs « coquilles » pour les épisodes annoncés mais non fournis :
      https://video.sibnet.ru/shell.php?videoid=   (videoid vide)
      https://ansembed.net/embed-.html             (id vide)
      https://sendvid.com/embed/                    (rien après /embed/)
      https://vk.com/video_ext.php?oid=&hd=3        (oid vide)
    On les détecte pour ne pas compter ces épisodes fantômes comme jouables."""
    u = (url or '').strip()
    if not u:
        return False
    low = u.lower()
    # Motifs de coquille : paramètre id vide, embed vide, chemin embed terminal.
    empty_patterns = [
        r'videoid=(?:&|$)',        # ...videoid=  (ou videoid=&)
        r'[?&]oid=(?:&|$)',        # ...oid=&hd=3
        r'embed-\.html',           # embed-.html
        r'/embed-?/?(?:\?|#|$)',   # /embed/ ou /embed terminal
        r'[?&#][a-z_]+=(?:&|$)',   # tout param clé= vide en fin
    ]
    for p in empty_patterns:
        if re.search(p, low):
            return False
    # Sinon : URL avec un identifiant réel (chemin/param non vide après le motif).
    return True


def _playable_episode_count(eps):
    """Nombre d'épisodes RÉELLEMENT jouables : au moins une URL vidéo avec un
    identifiant non vide (cf. [_url_has_id]). Écarte les épisodes « fantômes »
    (URLs-coquilles) qu'anime-sama déclare pour des saisons annoncées mais dont
    la vidéo n'est pas encore fournie."""
    if not eps:
        return 0
    count = 0
    for _key, urls in (eps or {}).items():
        if any(_url_has_id(u) for u in (urls or [])):
            count += 1
    return count


def _season_has_episodes(mod, dl, anime_url, season, vf):
    """Vrai si la saison a au moins un épisode réellement JOUABLE (avec une URL
    vidéo). anime-sama expose « Saison 1..10 » alors qu'une seule existe, et des
    saisons annoncées avec 1 épisode « fantôme » (sans lien vidéo) : le critère
    fiable est la présence d'au moins un épisode ayant une URL."""
    try:
        with _silence_output():
            eps = _episodes_for(mod, dl, anime_url, season, vf)
        return _playable_episode_count(eps) > 0
    except Exception:
        return False


def _seasons_for(mod, dl, title, vf):
    """Retourne (anime_url, seasons[]) ou lève une erreur via _fail.

    Ne conserve que les saisons RÉELLES : chemin relatif valide (exclut les
    recommandations) ET ayant au moins un épisode (exclut les « Saison N »
    factices générées par anime-sama). On valide dans l'ordre et on s'arrête à
    la première saison vide après en avoir trouvé au moins une valide (les
    factices sont contiguës en fin de liste) — limite le nombre de requêtes."""
    import requests
    found = _search_catalogue(dl, title, vf)
    if found is None:
        _fail(f"aucun anime correspondant à « {title} »")
    _, anime_url = found
    resp = requests.get(anime_url, headers=mod.HEADERS_BASE, timeout=15)
    raw = mod.get_seasons(resp.text)
    candidates = _dedupe_seasons([s for s in raw if _is_real_season(s)])

    real = []
    for s in candidates:
        if _season_has_episodes(mod, dl, anime_url, s, vf):
            real.append(s)
        elif real:
            # On a déjà des saisons valides et celle-ci est vide → fin des
            # vraies saisons (les suivantes sont factices). Arrêt anticipé.
            break

    if not real:
        _fail("aucune saison avec épisodes trouvée")
    return anime_url, real


def _dedupe_seasons(seasons):
    """Retire les doublons. get_seasons renvoie souvent la MÊME saison plusieurs
    fois : doublon exact, ou variantes de langue (« saison1/vostfr » et
    « saison1/vf ») — c'est la cause du « trop de saisons ». On déduplique donc
    par l'URL SANS son suffixe de langue (/vostfr, /vf), en repli sur le nom
    normalisé. Ordre d'apparition conservé."""
    def _season_key(s):
        url = (s.get('url') or '').strip().lower().rstrip('/')
        # Retire un éventuel segment de langue final pour fusionner VF/VOSTFR.
        url = re.sub(r'/(vostfr|vf|va|vcn|vkr|vqc)$', '', url)
        if url:
            return url
        return re.sub(r'[^a-z0-9]', '', (s.get('name') or '').lower())

    seen = set()
    result = []
    for s in seasons:
        key = _season_key(s)
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
        {"index": i, "name": s.get('name', f'Saison {i}'), "url": s.get('url', '')}
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
    """Recherche catalogue : renvoie la liste des animes (titre, url, slug)."""
    animes, urls = dl.get_catalogue(args.title, vf=args.vf)
    payload = [
        {"title": t, "url": u, "slug": _slug_from_url(u)}
        for t, u in zip(animes, urls)
    ]
    print(f"CATALOGUE_JSON: {json.dumps(payload, ensure_ascii=False)}")
    sys.exit(0)


def action_skip_times(mod, dl, args):
    """Timestamps de skip intro/outro (AniSkip via MyAnimeList) pour un épisode.

    Sortie : SKIP_JSON: {"op_start":..,"op_end":..,"ed_start":..,"ed_end":..,
    "episode_length":..} — champs présents seulement si trouvés. SKIP_JSON: {}
    si aucun timestamp (jamais une erreur : l'absence de skip n'est pas un échec).
    """
    # Libellé de saison (« Saison N ») pour affiner la recherche MAL côté AniSkip.
    saison = f"Saison {args.season}" if args.season and args.season > 1 else None
    # MAL id fourni par Terebi (via AniList/Jikan) : bien plus fiable que la
    # recherche par titre. 0 ou absent -> repli sur la recherche textuelle.
    mal_id = args.mal_id if args.mal_id and args.mal_id > 0 else None
    try:
        times = mod._get_skip_times(args.title, args.episode, saison, mal_id=mal_id)
    except Exception:
        times = None
    print(f"SKIP_JSON: {json.dumps(times or {}, ensure_ascii=False)}")
    sys.exit(0)


def _planning_times(mod):
    """Récupère la page /planning/ et extrait un map titre_normalisé -> heure.

    anime-sama encode desormais l'heure de diffusion dans un attribut
    `data-release-ts` (timestamp Unix) sur chaque carte `.planning-card`, avec le
    titre dans `data-title`. On lit ces attributs et on formate l'heure locale en
    « HHhMM ». (L'ancien format JS `cartePlanningAnime(...)` n'existe plus.)
    """
    import requests
    import time
    domain = mod.DOMAIN
    times = {}
    try:
        base = f"https://{domain}/planning/"
        resp = requests.get(base, headers=mod.HEADERS_BASE, timeout=15)
        html = resp.text
        # data-title="..." et data-release-ts="..." dans le meme <div> de carte
        # (ordre variable) -> on capte la balise puis on extrait les 2 attributs.
        card_re = re.compile(r'<div[^>]*\bplanning-card\b[^>]*>', re.I)
        title_attr = re.compile(r'data-title="([^"]*)"')
        ts_attr = re.compile(r'data-release-ts="(\d+)"')
        for m in card_re.finditer(html):
            tag = m.group(0)
            mt = title_attr.search(tag)
            mts = ts_attr.search(tag)
            if not mt or not mts:
                continue
            title = mt.group(1).strip()
            try:
                ts = int(mts.group(1))
            except ValueError:
                continue
            hhmm = time.strftime("%Hh%M", time.localtime(ts))
            if title:
                times[_norm(title)] = hhmm
    except requests.RequestException:
        pass
    return times


def _slug_from_url(url):
    """Extrait le slug d'une URL /catalogue/<slug>/ (ex. one-piece). '' sinon."""
    m = re.search(r'/catalogue/([^/]+)', url or '')
    return m.group(1).strip() if m else ''


# Extensions testees dans l'ordre pour trouver l'image CDN d'un slug, selon le
# type : les thumbnails sont en .webp, les bannieres en .jpg (constate sur le
# CDN Anime-Sama). On met la plus probable en premier pour eviter un 404 inutile.
_CDN_COVER_EXTS = ("webp", "jpg", "png")
_CDN_BANNER_EXTS = ("jpg", "webp", "png")


def _cdn_image_url(slug, banner=False, probe=True):
    """URL de l'image CDN Anime-Sama derivee du [slug].

    - cover/thumbnail : .../IMG@img/contenu/thumb/<slug>.<ext> (defaut .webp)
    - banniere         : .../IMG@img/contenu/<slug>.<ext>       (defaut .jpg)

    Si [probe] (defaut), teste les extensions du bon type (webp d'abord pour la
    cover, jpg d'abord pour la banniere) via HEAD et retient la premiere qui
    repond 200. Sinon (listes de cartes : on evite N requetes reseau), renvoie
    directement la 1re extension : cote Dart, le widget re-teste les extensions.
    """
    sub = "thumb/" if not banner else ""
    exts = _CDN_BANNER_EXTS if banner else _CDN_COVER_EXTS
    base = "https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/" + sub
    default = "{}{}.{}".format(base, slug, exts[0])
    if not probe:
        return default
    import requests
    for ext in exts:
        url = "{}{}.{}".format(base, slug, ext)
        try:
            r = requests.head(url, timeout=8, allow_redirects=True)
            if r.status_code == 200:
                return url
        except requests.RequestException:
            break  # reseau KO : inutile d'insister, on renvoie le defaut
    return default


def _norm(text):
    """Normalise un titre pour le matching (minuscule, alphanumérique)."""
    return re.sub(r'[^a-z0-9]', '', text.lower())


def _normalize_genres(raw):
    """Nettoie et normalise une liste de genres scrapes anime-sama.

    Corrige les defauts constates : entites HTML non decodees (&amp;), espaces /
    retours ligne parasites ('Surnaturel\\n'), « Science-Fiction » eclate en deux
    pills « Science » + « Fiction », variantes de casse. Recolle, decode,
    deduplique en conservant l'ordre.
    """
    import html as _html
    cleaned = []
    for g in raw:
        g = _html.unescape(g)
        g = re.sub(r'\s+', ' ', g).strip()
        if g and len(g) > 1:
            cleaned.append(g)
    merged = []
    i = 0
    while i < len(cleaned):
        cur = cleaned[i]
        nxt = cleaned[i + 1] if i + 1 < len(cleaned) else None
        if cur.lower() == "science" and nxt and nxt.lower() == "fiction":
            merged.append("Science-Fiction")
            i += 2
            continue
        if cur.lower() == "fiction":  # « Fiction » orpheline = bruit
            i += 1
            continue
        merged.append(cur)
        i += 1
    seen = set()
    out = []
    for g in merged:
        k = g.lower()
        if k not in seen:
            seen.add(k)
            out.append(g)
    return out


def action_planning(mod, dl, args):
    """Planning hebdomadaire : jour + heure + titre + url, filtre par LANGUE.

    Structure reelle : chaque diffusion est une carte
      <div class="... Anime VOSTFR|VF ... planning-card"
           data-title="..." data-release-ts="<ts>">
        <a href="/catalogue/<slug>/saisonX/<lang>/">
    Le planning melange VOSTFR et VF ; on ne garde que la langue demandee
    (args.vf -> VF, sinon VOSTFR). L'heure vient du timestamp data-release-ts.
    Les cartes sont regroupees par jour via les entetes <h2 class="titreJours">.
    """
    import requests
    import time
    import html as _html
    domain = mod.DOMAIN
    url = f"https://{domain}/planning/"
    try:
        response = requests.get(url, headers=mod.HEADERS_BASE, timeout=15)
    except requests.RequestException as e:
        _fail(f"planning inaccessible : {e}")
        return
    html_content = response.text
    want_vf = bool(args.vf)

    day_pattern = r'<h2 class="titreJours[^>]*>([^<]+)</h2>'
    days = re.findall(day_pattern, html_content)
    planning = {day.strip(): [] for day in days}
    day_sections = re.split(day_pattern, html_content)

    # Une carte planning complete : la div (avec classes + data-*) jusqu'au <a href>.
    card_re = re.compile(
        r'<div[^>]*\bplanning-card\b[^>]*data-title="([^"]*)"[^>]*'
        r'data-release-ts="(\d+)"[^>]*>\s*<a href="(/catalogue/[^"]+)"',
        re.DOTALL | re.I)
    # La langue est une classe de la div : on relit la div entiere pour la classe.
    div_re = re.compile(r'<div[^>]*\bplanning-card\b[^>]*>', re.I)

    items = []
    seen = set()  # (jour, slug) -> dedup
    for i in range(1, len(day_sections), 2):
        current_day = day_sections[i].strip()
        day_content = day_sections[i + 1]
        if current_day not in planning:
            continue
        for m in card_re.finditer(day_content):
            title = _html.unescape(m.group(1)).strip()
            ts = m.group(2)
            card_url = m.group(3).strip()
            # Langue : la classe de la div (VOSTFR / VF), repli sur l'URL.
            div_tag = day_content[m.start():m.start() + 400]
            is_vf = bool(re.search(r'\bVF\b', div_tag)) or '/vf/' in card_url.lower()
            is_vo = bool(re.search(r'\bVOSTFR\b', div_tag)) or \
                '/vostfr/' in card_url.lower()
            # Filtre langue : on ne garde que la langue demandee. Si la carte
            # n'indique aucune langue, on la garde en VOSTFR (defaut).
            if want_vf and not is_vf:
                continue
            if not want_vf and is_vf and not is_vo:
                continue
            if hasattr(mod, '_is_scan_url') and mod._is_scan_url(card_url):
                continue
            slug = _slug_from_url(card_url)
            key = (current_day, slug)
            if not slug or key in seen:
                continue
            seen.add(key)
            try:
                hhmm = time.strftime("%Hh%M", time.localtime(int(ts)))
            except ValueError:
                hhmm = ""
            items.append({
                "day": current_day,
                "time": hhmm,
                "title": title,
                "url": card_url,
                "slug": slug,
            })

    print(f"PLANNING_JSON: {json.dumps(items, ensure_ascii=False)}")
    sys.exit(0)


def action_catalogue_detail(mod, dl, args):
    """Scrape /catalogue/<slug>/ : titre, synopsis, genres, image de couverture.

    Tolerant : tout champ absent -> null/[] ; ne leve jamais d'exception qui
    casse la sortie JSON (au pire DETAIL_JSON minimal {slug,title}).
    """
    import requests
    slug = args.slug.strip()
    if not slug:
        _fail("catalogue-detail requiert --slug")
    domain = mod.DOMAIN
    url = f"https://{domain}/catalogue/{slug}/"
    detail = {"slug": slug, "title": slug, "synopsis": None,
              "genres": [], "cover_url": None, "banner_url": None}
    try:
        html = requests.get(url, headers=mod.HEADERS_BASE, timeout=15).text
        mt = re.search(r'<h1[^>]*>([^<]+)</h1>', html)
        if mt:
            detail["title"] = mt.group(1).strip()
        # Synopsis : <p id="synopsisText" ...>...</p> (structure reelle fiche).
        ms = re.search(
            r'<p[^>]+id="synopsisText"[^>]*>(.*?)</p>', html, re.DOTALL | re.I)
        if ms:
            detail["synopsis"] = re.sub(r'<[^>]+>', '', ms.group(1)).strip()
        # Genres : bloc <div class="genres-wrap"> contenant des
        # <span class="genre-pill">Nom</span>. On lit le contenu du wrap puis
        # tous les pills. Repli : anciens formats (liste separee par virgule).
        mw = re.search(
            r'<div[^>]+class="[^"]*genres-wrap[^"]*"[^>]*>(.*?)</div>',
            html, re.DOTALL | re.I)
        if mw:
            pills = re.findall(
                r'<span[^>]+class="[^"]*genre-pill[^"]*"[^>]*>([^<]+)</span>',
                mw.group(1), re.I)
            detail["genres"] = _normalize_genres(pills)
        if not detail["genres"]:
            mg = re.search(r'Genres?\s*</[^>]+>\s*<[^>]*>(.*?)</', html,
                           re.DOTALL | re.I)
            if mg:
                detail["genres"] = _normalize_genres(
                    [g for g in re.split(r'[,\n]', mg.group(1))
                     if g.strip() and '<' not in g])
        # Cover (thumbnail) et banniere derivees du slug sur le CDN Anime-Sama
        # (extension testee dans l'ordre jpg/webp/png). La cover est la
        # vignette utilisee par les cartes.
        detail["cover_url"] = _cdn_image_url(slug)
        # Banniere : priorite a l'image de la page si presente, sinon CDN slug.
        mb = re.search(r'<img[^>]+id="coverOeuvre"[^>]+src="([^"]+)"', html)
        detail["banner_url"] = mb.group(1) if mb else _cdn_image_url(slug, banner=True)
    except requests.RequestException:
        pass
    print(f"DETAIL_JSON: {json.dumps(detail, ensure_ascii=False)}")
    sys.exit(0)


def _card_type(inner):
    """Type de contenu d'une carte catalogue : « Anime », « Scans »,
    « Anime, Scans », « Film »… Lu dans le bloc `type-row` (premier
    <p class="info-value"> qui suit). '' si introuvable.

    NB : le SVG icone entre `type-row` et le <p> est long -> fenetre DOTALL
    large, pas de limite de caracteres.
    """
    m = re.search(
        r'type-row"?\s*>.*?<p[^>]+class="[^"]*info-value[^"]*"[^>]*>([^<]+)</p>',
        inner, re.DOTALL | re.I)
    return m.group(1).strip() if m else ''


def _is_video_card(inner):
    """Vrai si la carte contient du contenu VIDEO (anime et/ou film), donc
    lisible dans Terebi. Une carte de type « Scans » pur (manga) est ecartee.

    Le type du catalogue est « Anime », « Film », « Scans », ou une combinaison
    (« Anime, Scans »). On garde des qu'« anime » ou « film » apparait ; on
    n'ecarte que le pur « Scans ». Si le type est absent (structure inattendue),
    on garde par prudence (repli sur le comportement historique)."""
    t = _card_type(inner).lower()
    if not t:
        return True
    return ('anime' in t) or ('film' in t)


def _cards_from_html(mod, html):
    """Extrait des cartes (title,url,slug,cover_url,genres) d'un fragment HTML.

    Structure reelle anime-sama.to (page catalogue) : chaque carte est un
    <a href="https://.../catalogue/<slug>/"> contenant <img class="card-image"
    src="..."> (vrai nom de fichier CDN, suffixe possible), <h2 class="card-title">
    et un bloc <div class="catalog-info"> avec les genres en tags et le type
    (« Anime » / « Scans » / « Film ») dans un bloc `type-row`.

    Les cartes de type « Scans » PUR (mangas, sans video) sont ecartees : elles
    n'ont rien de lisible dans Terebi et polluaient le catalogue / la base.
    """
    card_re = re.compile(
        r'<a\s[^>]*href="https?://[^"]*?/catalogue/([^/"]+)/?[^"]*"[^>]*>'
        r'(.*?)</a>',
        re.DOTALL,
    )
    img_re = re.compile(
        r'<img[^>]+class="[^"]*card-image[^"]*"[^>]+src="([^"]+)"', re.DOTALL)
    img_alt_re = re.compile(r'<img[^>]+src="([^"]+)"', re.DOTALL)  # repli
    title_re = re.compile(
        r'<h2[^>]*card-title[^>]*>([^<]+)</h2>', re.DOTALL)
    # Genres : tags <span class="genre-tag">Nom</span> dans le bloc catalog-info.
    genre_tag_re = re.compile(
        r'<span[^>]+class="[^"]*genre-tag[^"]*"[^>]*>([^<]+)</span>', re.I)

    items = []
    for m in card_re.finditer(html):
        slug, inner = m.group(1).strip(), m.group(2)
        # Ecarte les scans (mangas) : type « Scans » pur, sans video.
        if not _is_video_card(inner):
            continue
        mt = title_re.search(inner)
        if not mt:
            continue  # pas une carte anime exploitable
        title = mt.group(1).strip()
        # Cover : src reel de card-image (repli : autre <img>, sinon CDN slug).
        mc = img_re.search(inner) or img_alt_re.search(inner)
        cover_url = mc.group(1).strip() if mc else _cdn_image_url(slug, probe=False)
        # Genres : textes des tags <span class="genre-tag">, normalises
        # (decodage entites, recollage Science-Fiction, dedup).
        genres = _normalize_genres(genre_tag_re.findall(inner))
        items.append({
            "title": title,
            "url": "https://{}/catalogue/{}/".format(mod.DOMAIN, slug),
            "slug": slug,
            "cover_url": cover_url,
            "genres": genres,
        })
    return items


def _genre_matches(genre_norm, card_genres):
    """Vrai si [genre_norm] (normalise) correspond a un genre de la carte.

    Egalite normalisee OU inclusion mutuelle (couvre « Tranche de vie » vs
    « tranchedevie », « Science-fiction » vs « sciencefiction »…).
    """
    for g in card_genres:
        gn = _norm(g)
        if not gn:
            continue
        if gn == genre_norm or genre_norm in gn or gn in genre_norm:
            return True
    return False


# Slugs des animes « classiques » (sections de la home anime-sama non
# scrapables — peuplees par JS). Liste verifiee presente au catalogue ; les
# titres absents d'anime-sama ont ete ecartes pour ne pas creer de cartes cassees.
_CLASSIC_SLUGS = [
    "one-piece", "demon-slayer", "slam-dunk", "detective-conan", "dragon-ball",
    "shingeki-no-kyojin", "naruto", "haikyuu", "fullmetal-alchemist",
    "jojos-bizarre-adventure", "hunter-x-hunter", "gintama", "kingdom",
    "world-trigger", "my-hero-academia", "yuyu-hakusho", "jujutsu-kaisen",
    "ken-le-survivant", "bleach", "banana-fish", "inuyasha", "ashita-no-joe",
    "kenshin-le-vagabond", "golden-kamui", "tokyo-ghoul",
    "the-quintessential-quintuplets", "the-promised-neverland", "hajime-no-ippo",
    "master-keaton", "kaguya-sama-love-is-war", "assassination-classroom",
    "kuroko-no-basket", "black-butler", "candy-candy", "city-hunter",
    "chainsaw-man", "parasite", "urusei-yatsura", "card-captor-sakura",
    "bungou-stray-dogs", "fairy-tail", "katekyo-hitman-reborn", "hana-yori-dango",
    "galaxy-express-999", "devilman-crybaby", "magi-the-labyrinth-of-magic",
    "hikaru-no-go", "major", "fire-force", "toilet-bound-hanako-kun",
    "karakuri-circus", "fruits-basket", "berserk", "rent-a-girlfriend",
    "d-gray-man", "captain-tsubasa", "march-comes-in-like-a-lion", "dr-stone",
]


def _catalogue_url(domain, genre="", page=1,
                   annee_min="", annee_max="",
                   episodes_min="", episodes_max=""):
    """Construit une URL de catalogue avec les filtres dans l'URL (filtrage cote
    SERVEUR anime-sama). `type[]=Anime` est TOUJOURS present -> jamais de scan
    dans le resultat. `genre[]`, `annee_min/max`, `episodes_min/max` sont
    optionnels (vides = non filtres). `page` >1 ajoute la pagination.

    Exemple complet :
      /catalogue/?type[]=Anime&annee_min=&annee_max=&episodes_min=&episodes_max=
      &chapitres_min=&chapitres_max=&genre[]=<Genre>&search=&page=N
    """
    from urllib.parse import quote
    qs = (
        "type%5B%5D=Anime"
        "&annee_min={}&annee_max={}&episodes_min={}&episodes_max={}"
        "&chapitres_min=&chapitres_max="
        "&genre%5B%5D={}&search=".format(
            quote(str(annee_min)), quote(str(annee_max)),
            quote(str(episodes_min)), quote(str(episodes_max)),
            quote(genre))
    )
    if page > 1:
        qs += "&page={}".format(page)
    return "https://{}/catalogue/?{}".format(domain, qs)


def action_home(mod, dl, args):
    """Sections de l'accueil.

    - classics : liste statique de slugs classiques (les sections de la home
      anime-sama sont peuplees par JS, non scrapables). Slugs verifies presents
      au catalogue. Titre approximatif depuis le slug ; le vrai titre/genres/cover
      sont enrichis cote app (cache/revalidation + image derivee du slug).
    - latest_episodes : premiere page du catalogue FILTRE animes (type[]=Anime)
      -> jamais de scan.
    """
    import requests
    domain = mod.DOMAIN
    home = {"classics": [], "latest_episodes": []}

    for slug in _CLASSIC_SLUGS:
        home["classics"].append({
            "title": slug.replace("-", " ").title(),
            "url": "https://{}/catalogue/{}/".format(domain, slug),
            "slug": slug,
            "cover_url": _cdn_image_url(slug, probe=False),
            "genres": [],
        })

    try:
        html = requests.get(_catalogue_url(domain),
                            headers=mod.HEADERS_BASE, timeout=15).text
        home["latest_episodes"] = _cards_from_html(mod, html)
    except requests.RequestException:
        pass

    print(f"HOME_JSON: {json.dumps(home, ensure_ascii=False)}")
    sys.exit(0)


def _catalogue_last_page(html):
    """Numero de la derniere page du catalogue, lu dans les liens de pagination
    (?page=N) de la page 1. Repli 1 si aucune pagination trouvee."""
    nums = [int(n) for n in re.findall(r'[?&]page=(\d+)', html or '')]
    return max(nums) if nums else 1


def action_catalogue_filter(mod, dl, args):
    """Catalogue filtre par criteres OPTIONNELS, via le FILTRE SERVEUR anime-sama.

    Le filtre serveur fonctionne :
      /catalogue/?type[]=Anime&annee_min=..&episodes_min=..&genre[]=<Genre>[&page=N]
    renvoie exactement les oeuvres correspondantes (ex. Thriller = 46, Ghibli =
    20), scans exclus grace a type[]=Anime.

    Criteres tous optionnels : sans aucun critere, c'est le mode « parcourir »
    (premiere(s) page(s) du catalogue anime-only). On pagine (bornee) jusqu'a
    TARGET items. Repli client-side seulement si un GENRE est fourni et que le
    serveur ne renvoie rien (genre non reconnu mais present dans les tags)."""
    import requests
    domain = mod.DOMAIN
    genre = args.genre.strip()
    annee_min = args.annee_min.strip()
    annee_max = args.annee_max.strip()
    episodes_min = args.episodes_min.strip()
    episodes_max = args.episodes_max.strip()
    # Aucune garde : genre vide = mode « parcourir » (catalogue anime-only).

    target = 100
    hard_max_pages = 60

    items = []
    seen = set()
    last_page = hard_max_pages
    page = 1
    while page <= last_page:
        url = _catalogue_url(
            domain, genre=genre, page=page,
            annee_min=annee_min, annee_max=annee_max,
            episodes_min=episodes_min, episodes_max=episodes_max)
        try:
            html = requests.get(url, headers=mod.HEADERS_BASE, timeout=15).text
        except requests.RequestException:
            break
        if page == 1:
            last_page = min(_catalogue_last_page(html), hard_max_pages)
        cards = _cards_from_html(mod, html)
        fresh = 0
        for it in cards:
            if it["slug"] in seen:
                continue
            seen.add(it["slug"])
            fresh += 1
            items.append(it)
        if fresh == 0:
            break
        if len(items) >= target:
            break
        page += 1

    # Repli cote client si un GENRE est fourni et que le filtre serveur n'a rien
    # donne (genre inconnu du serveur mais present dans les tags des cartes).
    if not items and genre:
        items = _filter_genre_client_side(mod, domain, genre, target,
                                          hard_max_pages)

    print(f"CATALOGUE_JSON: {json.dumps(items, ensure_ascii=False)}")
    sys.exit(0)


def _filter_genre_client_side(mod, domain, genre, target, hard_max_pages):
    """Repli : scanne la pagination du catalogue et filtre par genre cote
    scraper (tags des cartes). Utilise si le filtre serveur ne renvoie rien."""
    import requests
    genre_norm = _norm(genre)
    items = []
    seen = set()
    last_page = hard_max_pages
    page = 1
    while page <= last_page:
        suffix = "?page={}".format(page) if page > 1 else ""
        url = "https://{}/catalogue/{}".format(domain, suffix)
        try:
            html = requests.get(url, headers=mod.HEADERS_BASE, timeout=15).text
        except requests.RequestException:
            break
        if page == 1:
            last_page = min(_catalogue_last_page(html), hard_max_pages)
        cards = _cards_from_html(mod, html)
        fresh = 0
        for it in cards:
            if it["slug"] in seen:
                continue
            seen.add(it["slug"])
            fresh += 1
            if _genre_matches(genre_norm, it.get("genres", [])):
                items.append(it)
        if fresh == 0:
            break
        if len(items) >= target:
            break
        page += 1
    return items


def main():
    parser = argparse.ArgumentParser(description="Résolveur anime-sama pour Terebi")
    parser.add_argument("--script", required=True, help="Chemin vers anime_sama.py")
    parser.add_argument("--action", default="resolve",
                        choices=["resolve", "list-seasons", "list-episodes",
                                 "search", "planning", "skip-times",
                                 "catalogue-detail", "home", "catalogue-filter"])
    parser.add_argument("--title", default="", help="Titre de recherche")
    parser.add_argument("--season", type=int, default=1,
                        help="Index de saison (1-based, cf. list-seasons)")
    parser.add_argument("--episode", type=int, default=1, help="Numéro d'épisode")
    parser.add_argument("--mal-id", type=int, default=0,
                        help="MAL id (AniSkip) — 0 = recherche par titre")
    parser.add_argument("--vf", action="store_true", help="Version française (défaut VOSTFR)")
    parser.add_argument("--slug", default="", help="Slug catalogue (catalogue-detail)")
    parser.add_argument("--genre", default="", help="Genre (catalogue-filter)")
    # Filtres optionnels du catalogue (argparse : --annee-min -> args.annee_min).
    parser.add_argument("--annee-min", default="",
                        help="Annee de sortie minimum (catalogue-filter)")
    parser.add_argument("--annee-max", default="",
                        help="Annee de sortie maximum (catalogue-filter)")
    parser.add_argument("--episodes-min", default="",
                        help="Nombre d'episodes minimum (catalogue-filter)")
    parser.add_argument("--episodes-max", default="",
                        help="Nombre d'episodes maximum (catalogue-filter)")
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
        elif args.action == "skip-times":
            action_skip_times(mod, dl, args)
        elif args.action == "catalogue-detail":
            action_catalogue_detail(mod, dl, args)
        elif args.action == "home":
            action_home(mod, dl, args)
        elif args.action == "catalogue-filter":
            action_catalogue_filter(mod, dl, args)
        else:
            action_resolve(mod, dl, args)
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001 — on renvoie toute erreur proprement
        print(f"RESOLVE_ERROR: {type(e).__name__}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
