#!/usr/bin/env python3
"""Inspecte la base SQLite de Terebi et affiche un rapport (LECTURE SEULE par defaut).

Sert a verifier l'etat de la progression AVANT et APRES le 1er demarrage
post-refactor (migration titre -> slug).

Usage :
    python scripts/check_db.py                       # rapport seul (aucune ecriture)
    python scripts/check_db.py "C:/.../terebi.db"    # chemin explicite

    # Purge des animes NON resolus par la migration (listes dans slug_migration_report) :
    python scripts/check_db.py --purge-slug-report            # DRY-RUN : liste sans rien supprimer
    python scripts/check_db.py --purge-slug-report --apply    # supprime reellement (avec sauvegarde .bak)

    # Nettoyage des images residuelles AniList/MAL/Kitsu (cover_url/banner_url) :
    python scripts/check_db.py --clean-anilist-images         # DRY-RUN : liste les images concernees
    python scripts/check_db.py --clean-anilist-images --apply # met ces images a NULL (avec .bak)

Le rapport affiche : nombre d'animes, combien ont un slug (migres) vs legacy
(id negatif), la progression par anime (statut + episode de liste + progression
par saison 'anime_sama_watched:<id>:<s>'), et 'slug_migration_report' /
'slug_migration_done'.

--purge-slug-report supprime les animes dont le TITRE figure dans
'slug_migration_report' (media_table + list_entries + cles de progression
anime_sama_watched/season/lang/new_episode), puis vide le rapport. Sans --apply,
il ne fait que LISTER (dry-run). Avec --apply, il copie d'abord la base en
'<db>.bak' et opere dans une transaction.

Dans les deux cas (dry-run ET --apply), il ecrit un releve lisible de la
progression des animes cibles dans 'purged_progress.txt' (a cote de la base),
pour pouvoir la re-saisir a la main dans l'app apres coup.
"""

import json
import os
import shutil
import sqlite3
import sys


# Emplacements probables de la base sur Windows / macOS / Linux.
def _candidate_paths():
    paths = []
    appdata = os.environ.get("APPDATA")
    local = os.environ.get("LOCALAPPDATA")
    home = os.path.expanduser("~")
    for base in (appdata, local):
        if base:
            paths.append(os.path.join(base, "terebi", "terebi.db"))
            # Certains toolkits utilisent com.exemple.terebi ; on tente aussi terebi seul.
            paths.append(os.path.join(base, "Terebi", "terebi.db"))
    paths.append(os.path.join(home, "Library", "Application Support", "terebi", "terebi.db"))
    paths.append(os.path.join(home, ".local", "share", "terebi", "terebi.db"))
    return paths


def _resolve_db_path(positional):
    if positional:
        return positional[0]
    for p in _candidate_paths():
        if os.path.isfile(p):
            return p
    return None


def _open_readonly(path):
    """Ouvre la base en LECTURE SEULE (URI mode=ro) : aucune ecriture possible."""
    uri = "file:{}?mode=ro".format(path.replace("\\", "/"))
    return sqlite3.connect(uri, uri=True)


def _table_exists(con, name):
    row = con.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone()
    return row is not None


def _has_column(con, table, column):
    cols = [r[1] for r in con.execute("PRAGMA table_info({})".format(table)).fetchall()]
    return column in cols


def main():
    args = sys.argv[1:]
    purge = "--purge-slug-report" in args
    clean_images = "--clean-anilist-images" in args
    apply_changes = "--apply" in args
    positional = [a for a in args if not a.startswith("--")]

    path = _resolve_db_path(positional)
    if not path:
        print("ERREUR : base introuvable. Passe le chemin en argument :")
        print('  python scripts/check_db.py "C:/Users/<toi>/AppData/Roaming/terebi/terebi.db"')
        print("\nEmplacements testes :")
        for p in _candidate_paths():
            print("  -", p)
        sys.exit(1)

    if not os.path.isfile(path):
        print("ERREUR : fichier inexistant :", path)
        sys.exit(1)

    print("=" * 70)
    print("Base :", path)
    print("Taille : {:.1f} Ko".format(os.path.getsize(path) / 1024))
    print("=" * 70)

    # Rapport (toujours en lecture seule).
    con = _open_readonly(path)
    try:
        _report(con)
    finally:
        con.close()

    # Purge optionnelle des animes non resolus (listes dans slug_migration_report).
    if purge:
        _purge_slug_report(path, apply_changes)

    # Nettoyage optionnel des images residuelles AniList (cover_url/banner_url).
    if clean_images:
        _clean_anilist_images(path, apply_changes)


# Hotes d'images des anciennes sources (AniList / MyAnimeList / Kitsu). Une
# cover_url/banner_url contenant l'un de ces fragments est un residu a nettoyer.
_LEGACY_IMAGE_HOSTS = (
    "anilist.co",        # s4.anilist.co/...
    "myanimelist.net",   # cdn.myanimelist.net/...
    "kitsu.io",
    "kitsu.app",
)


def _clean_anilist_images(path, apply_changes):
    print("\n" + "#" * 70)
    print("NETTOYAGE DES IMAGES RESIDUELLES ANILIST (cover_url / banner_url)")
    print("#" * 70)

    con = _open_readonly(path)
    try:
        if not _table_exists(con, "media_table"):
            print("(table media_table absente — rien a nettoyer.)")
            return
        like = " OR ".join(
            ["cover_url LIKE '%{}%'".format(h) for h in _LEGACY_IMAGE_HOSTS]
            + ["banner_url LIKE '%{}%'".format(h) for h in _LEGACY_IMAGE_HOSTS]
        )
        rows = con.execute(
            "SELECT anilist_id, "
            "COALESCE(anime_sama_title, title_english, title_romaji, title_native), "
            "cover_url, banner_url FROM media_table WHERE " + like
        ).fetchall()
    finally:
        con.close()

    if not rows:
        print("Aucune image residuelle AniList/MAL/Kitsu detectee. Rien a faire.")
        return

    def _is_legacy(url):
        return bool(url) and any(h in url for h in _LEGACY_IMAGE_HOSTS)

    print("\n{} media(s) avec une image residuelle :".format(len(rows)))
    for mid, title, cover, banner in rows:
        parts = []
        if _is_legacy(cover):
            parts.append("cover")
        if _is_legacy(banner):
            parts.append("banner")
        print("  [NETTOIE {}] id={:<12} {}".format(
            "+".join(parts), mid, (title or "?")[:45]))

    if not apply_changes:
        print("\n--- DRY-RUN : aucune image modifiee. ---")
        print("Les images seront mises a NULL (l'app les re-resout via anime-sama")
        print("au prochain affichage, cache-first). Pour appliquer :")
        print('  python scripts/check_db.py "{}" --clean-anilist-images --apply'.format(path))
        return

    backup = path + ".bak"
    shutil.copy2(path, backup)
    print("\nSauvegarde creee :", backup)

    con = sqlite3.connect(path)  # lecture-ecriture
    try:
        con.execute("BEGIN")
        for host in _LEGACY_IMAGE_HOSTS:
            con.execute(
                "UPDATE media_table SET cover_url = NULL "
                "WHERE cover_url LIKE ?", ("%{}%".format(host),))
            con.execute(
                "UPDATE media_table SET banner_url = NULL "
                "WHERE banner_url LIKE ?", ("%{}%".format(host),))
        con.execute("COMMIT")
    except sqlite3.Error as e:
        con.execute("ROLLBACK")
        print("ERREUR — nettoyage annule (ROLLBACK) :", e)
        print("Base intacte ; sauvegarde disponible :", backup)
        con.close()
        sys.exit(1)
    finally:
        con.close()

    print("\n{} media(s) nettoye(s) : cover_url/banner_url AniList mis a NULL.".format(
        len(rows)))
    print("L'app re-resoudra les images via anime-sama au prochain affichage.")
    print("En cas de probleme, restaure la sauvegarde :")
    print('  copy "{}" "{}"   (Windows)'.format(backup, path))


def _write_progress_receipt(out_path, db_path, found, applied):
    """Ecrit un releve LISIBLE de la progression des animes cibles par la purge.

    Sert a re-saisir manuellement dans l'app apres suppression : pour chaque
    anime, titre + statut + episode de liste + progression par saison.
    Ecrit en dry-run comme en --apply (mention de l'etat dans l'entete).
    """
    lines = []
    lines.append("Progression des animes purges de la base Terebi")
    lines.append("Base : {}".format(db_path))
    lines.append("Mode : {}".format(
        "SUPPRESSION APPLIQUEE (--apply)" if applied else "DRY-RUN (rien supprime)"
    ))
    lines.append("A re-saisir a la main dans l'app pour ces animes.")
    lines.append("=" * 60)
    for t in found:
        lines.append("")
        lines.append("Titre  : {}".format(t["title"]))
        lines.append("  id ancien   : {}".format(t["media_id"]))
        lines.append("  statut      : {}".format(t["status"]))
        lines.append("  episode liste: {}".format(t["progress"]))
        if t["seasons"]:
            lines.append("  progression par saison :")
            for s, v in t["seasons"]:
                lines.append("    - saison {} : dernier episode vu = {}".format(s, v))
        else:
            lines.append("  progression par saison : (aucune)")
    lines.append("")
    # ecriture UTF-8 (titres accentues/japonais possibles).
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def _purge_slug_report(path, apply_changes):
    print("\n" + "#" * 70)
    print("PURGE DES ANIMES NON RESOLUS (slug_migration_report)")
    print("#" * 70)

    # Lecture seule d'abord : recuperer la liste des titres non resolus.
    con = _open_readonly(path)
    try:
        if not _table_exists(con, "app_settings"):
            print("(table app_settings absente — rien a purger.)")
            return
        row = con.execute(
            "SELECT value FROM app_settings WHERE key='slug_migration_report'"
        ).fetchone()
        titles = [t.strip() for t in (row[0].split("\n") if row and row[0] else []) if t.strip()]

        if not titles:
            print("slug_migration_report vide ou absent — aucun anime a purger.")
            return

        has_media = _table_exists(con, "media_table")
        has_entries = _table_exists(con, "list_entries")
        has_slug = has_media and _has_column(con, "media_table", "anime_sama_slug")

        # Progression par saison de TOUS les medias (cles anime_sama_watched:<id>:<s>).
        watched_by_id = {}
        rows = con.execute(
            "SELECT key, value FROM app_settings WHERE key LIKE 'anime_sama_watched:%'"
        ).fetchall()
        for key, value in rows:
            parts = key.split(":")
            if len(parts) >= 3:
                watched_by_id.setdefault(parts[1], []).append((parts[2], value))

        # Pour chaque titre du rapport, retrouver le media + sa progression.
        # target = dict(title, media_id, status, progress, seasons)
        targets = []
        for title in titles:
            r = con.execute(
                "SELECT anilist_id FROM media_table "
                "WHERE anime_sama_title = ? "
                "   OR title_english = ? OR title_romaji = ? OR title_native = ?",
                (title, title, title, title),
            ).fetchall() if has_media else []
            if r:
                for (mid,) in r:
                    status, progress = "?", "?"
                    if has_entries:
                        e = con.execute(
                            "SELECT status, progress FROM list_entries WHERE media_id = ?",
                            (mid,),
                        ).fetchone()
                        if e:
                            status, progress = e[0], e[1]
                        else:
                            status, progress = "(pas dans la liste)", 0
                    seasons = sorted(watched_by_id.get(str(mid), []))
                    targets.append({
                        "title": title, "media_id": mid,
                        "status": status, "progress": progress, "seasons": seasons,
                    })
            else:
                targets.append({
                    "title": title, "media_id": None,
                    "status": None, "progress": None, "seasons": [],
                })
    finally:
        con.close()

    # Affiche le plan de suppression AVEC la progression.
    print("\n{} titre(s) dans le rapport :".format(len(titles)))
    found = [t for t in targets if t["media_id"] is not None]
    missing = [t for t in targets if t["media_id"] is None]
    for t in found:
        seasons_str = ", ".join("S{}={}".format(s, v) for s, v in t["seasons"]) or "-"
        print("  [SUPPR] id={:<12} {:<40} statut={} prog_liste={} saisons=[{}]".format(
            t["media_id"], t["title"][:40], t["status"], t["progress"], seasons_str
        ))
    for t in missing:
        print("  [absent en base, ignore] {}".format(t["title"]))

    if not found:
        print("\nAucun media correspondant en base — rien a supprimer.")
        return

    # Ecrit TOUJOURS (dry-run ET apply) un releve lisible de la progression, a
    # cote de la base, pour pouvoir re-saisir a la main dans l'app apres coup.
    progress_file = os.path.join(os.path.dirname(os.path.abspath(path)),
                                 "purged_progress.txt")
    _write_progress_receipt(progress_file, path, found, applied=apply_changes)
    print("\nProgression sauvegardee (pour re-saisie manuelle) :", progress_file)

    if not apply_changes:
        print("\n--- DRY-RUN : rien n'a ete supprime. ---")
        print("Pour supprimer reellement (avec sauvegarde .bak) :")
        print('  python scripts/check_db.py "{}" --purge-slug-report --apply'.format(path))
        return

    # --apply : sauvegarde puis suppression transactionnelle.
    backup = path + ".bak"
    shutil.copy2(path, backup)
    print("\nSauvegarde creee :", backup)

    ids = [t["media_id"] for t in found]
    con = sqlite3.connect(path)  # lecture-ecriture
    try:
        con.execute("BEGIN")
        for mid in ids:
            con.execute("DELETE FROM media_table WHERE anilist_id = ?", (mid,))
            con.execute("DELETE FROM list_entries WHERE media_id = ?", (mid,))
            # Progression + reglages par media (cles app_settings prefixees).
            con.execute(
                "DELETE FROM app_settings WHERE key LIKE ?",
                ("anime_sama_watched:{}:%".format(mid),),
            )
            for prefix in ("anime_sama_season:", "anime_sama_lang:", "new_episode:"):
                con.execute(
                    "DELETE FROM app_settings WHERE key = ?", (prefix + str(mid),)
                )
        # Vide le rapport (les cas sont traites).
        con.execute(
            "UPDATE app_settings SET value = '' WHERE key = 'slug_migration_report'"
        )
        con.execute("COMMIT")
    except sqlite3.Error as e:
        con.execute("ROLLBACK")
        print("ERREUR — suppression annulee (ROLLBACK) :", e)
        print("La base d'origine est intacte ; sauvegarde disponible :", backup)
        con.close()
        sys.exit(1)
    finally:
        con.close()

    print("\n{} anime(s) supprime(s). slug_migration_report vide.".format(len(ids)))
    print("En cas de probleme, restaure la sauvegarde :")
    print('  copy "{}" "{}"   (Windows)'.format(backup, path))


def _report(con):
    # --- Schema / version ---------------------------------------------------
    try:
        uv = con.execute("PRAGMA user_version").fetchone()[0]
        print("\nschemaVersion (user_version drift) :", uv,
              "  (>= 3 attendu apres migration)")
    except sqlite3.Error:
        pass

    has_media = _table_exists(con, "media_table")
    has_entries = _table_exists(con, "list_entries")
    has_settings = _table_exists(con, "app_settings")

    if not has_media:
        print("\n(!) table 'media_table' absente — base vide ou schema inattendu.")
    has_slug = has_media and _has_column(con, "media_table", "anime_sama_slug")

    # --- Vue d'ensemble des medias -----------------------------------------
    print("\n" + "-" * 70)
    print("MEDIAS")
    print("-" * 70)
    if has_media:
        total = con.execute("SELECT COUNT(*) FROM media_table").fetchone()[0]
        neg = con.execute(
            "SELECT COUNT(*) FROM media_table WHERE anilist_id < 0"
        ).fetchone()[0]
        pos = con.execute(
            "SELECT COUNT(*) FROM media_table WHERE anilist_id > 0"
        ).fetchone()[0]
        print("Total animes            :", total)
        print("  id positif (slug/neuf):", pos)
        print("  id negatif (legacy)   :", neg,
              "  <- a migrer vers slug" if neg else "")
        if has_slug:
            with_slug = con.execute(
                "SELECT COUNT(*) FROM media_table "
                "WHERE anime_sama_slug IS NOT NULL AND anime_sama_slug <> ''"
            ).fetchone()[0]
            print("  avec slug renseigne   :", with_slug, "/", total,
                  "  <- migres" if with_slug else "")
            print("  sans slug             :", total - with_slug,
                  "  <- pas encore migres" if (total - with_slug) else "")
        else:
            print("  (colonne anime_sama_slug absente : base encore en v2, "
                  "migration pas faite)")

    # --- Progression par anime ---------------------------------------------
    print("\n" + "-" * 70)
    print("PROGRESSION PAR ANIME (entree de liste + progression par saison)")
    print("-" * 70)

    # Progression par saison : cles app_settings 'anime_sama_watched:<id>:<saison>'.
    watched_by_id = {}
    if has_settings:
        rows = con.execute(
            "SELECT key, value FROM app_settings "
            "WHERE key LIKE 'anime_sama_watched:%'"
        ).fetchall()
        for key, value in rows:
            parts = key.split(":")
            if len(parts) >= 3:
                media_id = parts[1]
                season = parts[2]
                watched_by_id.setdefault(media_id, []).append((season, value))

    if has_entries:
        entries = con.execute(
            "SELECT media_id, status, progress FROM list_entries "
            "ORDER BY media_id"
        ).fetchall()
        if not entries:
            print("(aucune entree de liste — bibliotheque vide)")
        for media_id, status, progress in entries:
            title = "?"
            if has_media:
                r = con.execute(
                    "SELECT COALESCE(title_english, title_romaji, title_native), "
                    "anime_sama_title{} FROM media_table WHERE anilist_id=?".format(
                        ", anime_sama_slug" if has_slug else ""
                    ),
                    (media_id,),
                ).fetchone()
                if r:
                    title = r[1] or r[0] or "?"
                    slug = (r[2] if has_slug and len(r) > 2 else None)
                else:
                    slug = None
                    title = "(media absent de media_table)"
            seasons = watched_by_id.get(str(media_id), [])
            seasons_str = ", ".join(
                "S{}={}".format(s, v) for s, v in sorted(seasons)
            ) or "-"
            slug_str = ""
            if has_slug:
                slug_str = "  [slug: {}]".format(slug or "AUCUN")
            print("- id={:<12} {:<40} statut={:<10} prog_liste={} saisons=[{}]{}".format(
                media_id, (title or "?")[:40], status, progress, seasons_str, slug_str
            ))
    else:
        print("(table list_entries absente)")

    # Cles de progression orphelines (watched sans entree de liste) : signal utile.
    if has_entries and watched_by_id:
        entry_ids = {
            str(r[0]) for r in con.execute("SELECT media_id FROM list_entries").fetchall()
        }
        orphans = [mid for mid in watched_by_id if mid not in entry_ids]
        if orphans:
            print("\n(!) Progression par saison SANS entree de liste (ids) :", orphans)
            print("    -> normal si l'anime a ete regarde sans etre 'suivi' ;")
            print("       a surveiller apres migration (l'id doit basculer vers le slug).")

    # --- Rapport de migration ----------------------------------------------
    print("\n" + "-" * 70)
    print("MIGRATION SLUG")
    print("-" * 70)
    if has_settings:
        done = con.execute(
            "SELECT value FROM app_settings WHERE key='slug_migration_done'"
        ).fetchone()
        report = con.execute(
            "SELECT value FROM app_settings WHERE key='slug_migration_report'"
        ).fetchone()
        print("slug_migration_done :", (done[0] if done else "(absente — migration pas encore lancee)"))
        if report and report[0].strip():
            titres = [t for t in report[0].split("\n") if t.strip()]
            print("slug_migration_report : {} anime(s) NON resolu(s) :".format(len(titres)))
            for t in titres:
                print("   - ", t)
            print("\n   -> Ces animes gardent leur ancien id (progression conservee).")
            print("      Envoie la base pour reparation manuelle de ces cas.")
        else:
            print("slug_migration_report : (vide — aucun echec)" if done
                  else "slug_migration_report : (absente)")
    else:
        print("(table app_settings absente)")

    # --- Diagnostic ACCUEIL (rangees) --------------------------------------
    # Explique pourquoi les rangees "Regarde recemment", "Ca pourrait vous
    # plaire" et "par genre" seraient vides : elles derivent de l'historique de
    # visionnage (table watch_histories) et des genres des medias regardes.
    print("\n" + "-" * 70)
    print("ACCUEIL (diagnostic des rangees)")
    print("-" * 70)
    has_history = _table_exists(con, "watch_histories")
    if not has_history:
        print("(!) table 'watch_histories' absente : aucune lecture jamais lancee")
        print("    -> 'Regarde recemment', 'Ca pourrait vous plaire' et les")
        print("       rangees par genre restent VIDES tant qu'aucun episode")
        print("       n'a ete lance DEPUIS LE LECTEUR de l'app.")
    else:
        hist_rows = con.execute(
            "SELECT COUNT(*) FROM watch_histories"
        ).fetchone()[0]
        hist_ids = [
            r[0]
            for r in con.execute(
                "SELECT DISTINCT media_id FROM watch_histories"
            ).fetchall()
        ]
        print("Lancements de lecture enregistres :", hist_rows)
        print("Animes distincts regardes         :", len(hist_ids))
        if hist_rows == 0:
            print("(!) Historique VIDE -> 'Regarde recemment', 'Ca pourrait vous")
            print("    plaire' et les rangees par genre ne s'affichent pas.")
            print("    Lance un episode depuis le lecteur pour amorcer l'historique.")
        elif has_media:
            # Combien de ces animes existent en media_table (sinon 'Regarde
            # recemment' les ignore) et combien ont des genres (sinon pas de
            # rangee par genre ni 'Ca pourrait vous plaire').
            found = 0
            with_genres = 0
            genre_counts = {}
            for mid in hist_ids:
                row = con.execute(
                    "SELECT genres_json FROM media_table WHERE anilist_id=?",
                    (mid,),
                ).fetchone()
                if row is None:
                    continue
                found += 1
                raw = row[0] or "[]"
                try:
                    genres = json.loads(raw)
                except (ValueError, TypeError):
                    genres = []
                if genres:
                    with_genres += 1
                    # Pondere par le nombre de visionnages de cet anime.
                    plays = con.execute(
                        "SELECT COUNT(*) FROM watch_histories WHERE media_id=?",
                        (mid,),
                    ).fetchone()[0]
                    for g in genres:
                        genre_counts[g] = genre_counts.get(g, 0) + plays
            print("  presents dans media_table       :", found, "/", len(hist_ids),
                  "  <- les absents sont ignores par 'Regarde recemment'"
                  if found < len(hist_ids) else "")
            print("  avec genres renseignes          :", with_genres, "/", found)
            if with_genres == 0:
                print("(!) Aucun anime regarde n'a de genres en base -> pas de")
                print("    rangee 'Ca pourrait vous plaire' ni de rangee par genre.")
                print("    (les genres se remplissent via la fiche/le scraper ;")
                print("     ouvre la fiche des animes concernes pour les enrichir.)")
            else:
                ordered = sorted(
                    genre_counts.items(),
                    key=lambda kv: (-kv[1], kv[0]),
                )
                print("  Genres regardes (par nb de visionnages, ordre des rangees) :")
                for g, c in ordered:
                    print("     - {:<20} {}".format(g, c))

    print("\n" + "=" * 70)
    print("Rapport termine (lecture seule — la base n'a PAS ete modifiee).")
    print("=" * 70)


if __name__ == "__main__":
    main()
