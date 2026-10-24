#!/usr/bin/env python3
"""
Prépare la base de données SQLite pour Turso en important les données
actuelles de l'utilisateur (C:\\Users\\Thomas\\Documents\\terebi.sqlite) vers
le nouveau schéma multi-utilisateurs avec comptes et avatars DiceBear.
"""

import os
import sys
import uuid
import hashlib
import secrets
import sqlite3
import time

def hash_password(password: str, salt: str) -> str:
    return hashlib.sha256((salt + password).encode('utf-8')).hexdigest()

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    schema_path = os.path.join(root, 'scripts', 'turso_schema.sql')
    dist_dir = os.path.join(root, 'dist')
    os.makedirs(dist_dir, exist_ok=True)
    out_db_path = os.path.join(dist_dir, 'terebi_turso.sqlite')

    src_db_path = os.path.expanduser('~/Documents/terebi.sqlite')
    if not os.path.exists(src_db_path):
        print(f"Base source introuvable à {src_db_path}, création d'une base vide.")
        src_conn = None
    else:
        print(f"Base source trouvée : {src_db_path}")
        src_conn = sqlite3.connect(src_db_path)
        src_conn.row_factory = sqlite3.Row

    if os.path.exists(out_db_path):
        os.remove(out_db_path)

    out_conn = sqlite3.connect(out_db_path)
    with open(schema_path, 'r', encoding='utf-8') as f:
        out_conn.executescript(f.read())

    print("Schéma Turso créé avec succès.")

    # Création du compte utilisateur initial
    username = "Thomas"
    password = "change_me_123"  # Mot de passe par défaut
    salt = secrets.token_hex(16)
    pwd_hash = hash_password(password, salt)
    user_id = str(uuid.uuid4())
    now_ms = int(time.time() * 1000)

    out_conn.execute("""
        INSERT INTO users (id, username, email, password_hash, salt, avatar_style, avatar_seed, bio, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        user_id,
        username,
        f"{username.lower()}@terebi.local",
        pwd_hash,
        salt,
        "lorelei",
        username,
        "Utilisateur Terebi",
        now_ms,
        now_ms
    ))

    # Création d'une session par défaut
    session_token = secrets.token_hex(32)
    out_conn.execute("""
        INSERT INTO user_sessions (token, user_id, device_name, created_at, last_used_at, expires_at)
        VALUES (?, ?, ?, ?, ?, NULL)
    """, (
        session_token,
        user_id,
        "Windows Desktop",
        now_ms,
        now_ms
    ))

    print(f"Compte utilisateur créé : {username} (ID: {user_id})")
    print(f"Session token initial : {session_token}")

    if src_conn:
        src_cur = src_conn.cursor()

        # 1. Copie des médias partagés
        try:
            src_cur.execute("SELECT * FROM media_table")
            medias = src_cur.fetchall()
            for m in medias:
                out_conn.execute("""
                    INSERT OR REPLACE INTO media_table (
                        anilist_id, title_romaji, title_english, title_native,
                        episodes, cover_url, banner_url, description, genres_json,
                        updated_at, anime_sama_title, anime_sama_slug
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    m['anilist_id'], m['title_romaji'], m['title_english'], m['title_native'],
                    m['episodes'], m['cover_url'], m['banner_url'], m['description'], m['genres_json'],
                    m['updated_at'], m['anime_sama_title'], m['anime_sama_slug']
                ))
            print(f"  + {len(medias)} médias importés dans media_table")
        except Exception as e:
            print(f"Erreur copie media_table: {e}")

        # 2. Copie des list_entries rattachées à user_id
        try:
            src_cur.execute("SELECT * FROM list_entries")
            entries = src_cur.fetchall()
            for e in entries:
                out_conn.execute("""
                    INSERT OR REPLACE INTO list_entries (
                        user_id, media_id, status, progress, hidden_from_planning, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    user_id, e['media_id'], e['status'], e['progress'], e['hidden_from_planning'], e['updated_at']
                ))
            print(f"  + {len(entries)} entrées de liste importées pour {username}")
        except Exception as e:
            print(f"Erreur copie list_entries: {e}")

        # 3. Copie des episode_progresses rattachées à user_id
        try:
            src_cur.execute("SELECT * FROM episode_progresses")
            progs = src_cur.fetchall()
            for p in progs:
                out_conn.execute("""
                    INSERT OR REPLACE INTO episode_progresses (
                        user_id, media_id, episode_number, watched, position_seconds,
                        duration_seconds, completed_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    user_id, p['media_id'], p['episode_number'], p['watched'], p['position_seconds'],
                    p['duration_seconds'], p['completed_at'], p['updated_at']
                ))
            print(f"  + {len(progs)} progressions d'épisodes importées pour {username}")
        except Exception as e:
            print(f"Erreur copie episode_progresses: {e}")

        # 4. Copie des watch_histories rattachées à user_id
        try:
            src_cur.execute("SELECT * FROM watch_histories")
            hists = src_cur.fetchall()
            for h in hists:
                out_conn.execute("""
                    INSERT INTO watch_histories (
                        user_id, media_id, episode_number, started_at, ended_at, watched_seconds
                    ) VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    user_id, h['media_id'], h['episode_number'], h['started_at'], h['ended_at'], h['watched_seconds']
                ))
            print(f"  + {len(hists)} sessions d'historique importées pour {username}")
        except Exception as e:
            print(f"Erreur copie watch_histories: {e}")

        # 5. Copie des paramètres utilisateur (anime_sama_watched, etc.)
        try:
            src_cur.execute("SELECT * FROM app_settings")
            settings = src_cur.fetchall()
            count_user_settings = 0
            for s in settings:
                k = s['key']
                v = s['value']
                # Clés spécifiques à l'utilisateur vs globales
                if k.startswith('anime_sama_watched:') or k.startswith('new_episode:') or k == 'prioritize_new_episodes':
                    out_conn.execute("""
                        INSERT OR REPLACE INTO user_settings (user_id, key, value) VALUES (?, ?, ?)
                    """, (user_id, k, v))
                    count_user_settings += 1
                else:
                    out_conn.execute("""
                        INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)
                    """, (k, v))
            print(f"  + {count_user_settings} paramètres utilisateur migrés pour {username}")
        except Exception as e:
            print(f"Erreur copie settings: {e}")

        src_conn.close()

    out_conn.commit()
    out_conn.close()

    size_mb = os.path.getsize(out_db_path) / (1024 * 1024)
    print(f"\nBase Turso prête : {out_db_path} ({size_mb:.2f} MB)")
    print("\nPour l'envoyer sur Turso :")
    print(f"  turso db create terebi --from-file {out_db_path}")

if __name__ == '__main__':
    main()
