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

Le rapport affiche : nombre d'animes, combien ont un slug (migres) vs legacy
(id negatif), la progression par anime (statut + episode de liste + progression
par saison 'anime_sama_watched:<id>:<s>'), et 'slug_migration_report' /
'slug_migration_done'.

--purge-slug-report supprime les animes dont le TITRE figure dans
'slug_migration_report' (media_table + list_entries + cles de progression
anime_sama_watched/season/lang/new_episode), puis vide le rapport. Sans --apply,
il ne fait que LISTER (dry-run). Avec --apply, il copie d'abord la base en
'<db>.bak' et opere dans une transaction.
"""

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

        # Pour chaque titre du rapport, retrouver le media correspondant.
        targets = []  # (title, media_id)
        for title in titles:
            r = con.execute(
                "SELECT anilist_id FROM media_table "
                "WHERE anime_sama_title = ? "
                "   OR title_english = ? OR title_romaji = ? OR title_native = ?",
                (title, title, title, title),
            ).fetchall() if has_media else []
            if r:
                for (mid,) in r:
                    targets.append((title, mid))
            else:
                targets.append((title, None))  # introuvable en base
    finally:
        con.close()

    # Affiche le plan de suppression.
    print("\n{} titre(s) dans le rapport :".format(len(titles)))
    found = [(t, mid) for (t, mid) in targets if mid is not None]
    missing = [t for (t, mid) in targets if mid is None]
    for title, mid in found:
        print("  [SUPPR] id={:<12} {}".format(mid, title))
    for title in missing:
        print("  [absent en base, ignore] {}".format(title))

    if not found:
        print("\nAucun media correspondant en base — rien a supprimer.")
        return

    if not apply_changes:
        print("\n--- DRY-RUN : rien n'a ete supprime. ---")
        print("Pour supprimer reellement (avec sauvegarde .bak) :")
        print('  python scripts/check_db.py "{}" --purge-slug-report --apply'.format(path))
        return

    # --apply : sauvegarde puis suppression transactionnelle.
    backup = path + ".bak"
    shutil.copy2(path, backup)
    print("\nSauvegarde creee :", backup)

    ids = [mid for (_, mid) in found]
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

    print("\n" + "=" * 70)
    print("Rapport termine (lecture seule — la base n'a PAS ete modifiee).")
    print("=" * 70)


if __name__ == "__main__":
    main()
