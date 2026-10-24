#!/usr/bin/env python3
"""
Uploads the complete Terebi SQLite database to Turso via the HTTP pipeline API.
"""

import os
import json
import sqlite3
import urllib.request
import time

TURSO_URL = 'https://terebi-saloquin.aws-eu-west-1.turso.io/v2/pipeline'
TURSO_TOKEN = 'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3OTI4NzY4MTYsImlkIjoiMDFhMTZmYzktMGQwMS03ZDNjLThiNWEtYjQxZTA3OGYyYzY4Iiwia2lkIjoiTXRPeDVrUHRWOVRqZEpQMDNyUXZGRklCaENydnB4LUs3MG5rUFVzQjlUdyIsInJpZCI6IjAyYmUyYzBkLWViZDctNDRjMS04ZjI4LWZkNGQ5MjQzMTY2NCJ9.uXLu6xYQmxVb3xtYr86njwTat0r9Oeedn2Vp1vY1QTzSndk4EzpyBdBB6ikYMHcNeJGCC3AqC1VyELXBgMikCA'

def execute_pipeline(requests):
    payload = json.dumps({'requests': requests}).encode('utf-8')
    req = urllib.request.Request(TURSO_URL, data=payload, headers={
        'Authorization': f'Bearer {TURSO_TOKEN}',
        'Content-Type': 'application/json'
    }, method='POST')
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode('utf-8'))
        for r in res.get('results', []):
            if r.get('type') == 'error':
                raise RuntimeError(r.get('error'))
        return res

def sql_to_turso_arg(val):
    if val is None:
        return {'type': 'null'}
    elif isinstance(val, int):
        return {'type': 'integer', 'value': str(val)}
    elif isinstance(val, float):
        return {'type': 'float', 'value': val}
    elif isinstance(val, (bytes, bytearray)):
        import base64
        return {'type': 'blob', 'base64': base64.b64encode(val).decode('ascii')}
    else:
        return {'type': 'text', 'value': str(val)}

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    schema_path = os.path.join(root, 'scripts', 'turso_schema.sql')
    db_path = os.path.join(root, 'dist', 'terebi_turso.sqlite')

    print(f"1. Création des tables sur Turso ({TURSO_URL})...")
    with open(schema_path, 'r', encoding='utf-8') as f:
        schema_sql = f.read()

    # Drop tables cleanly first
    drop_order = [
        'watch_histories', 'episode_progresses', 'list_entries', 'user_settings',
        'user_sessions', 'users', 'media_table', 'app_settings', 'meta_cache'
    ]
    drop_reqs = [{'type': 'execute', 'stmt': {'sql': f'DROP TABLE IF EXISTS {t};'}} for t in drop_order]
    execute_pipeline(drop_reqs)

    # Découpe les instructions DDL
    ddl_stmts = [s.strip() for s in schema_sql.split(';') if s.strip()]
    reqs = [{'type': 'execute', 'stmt': {'sql': s + ';'}} for s in ddl_stmts]
    # Envoi par paquets de 20
    for i in range(0, len(reqs), 20):
        execute_pipeline(reqs[i:i+20])
    print("   Tables créées avec succès !")

    print(f"2. Lecture des données locales depuis {db_path}...")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    tables = [
        'users',
        'user_sessions',
        'media_table',
        'list_entries',
        'episode_progresses',
        'watch_histories',
        'user_settings',
        'app_settings',
        'meta_cache'
    ]

    for table in tables:
        cur.execute(f"PRAGMA table_info({table})")
        columns = [c[1] for c in cur.fetchall()]
        col_list = ', '.join(columns)
        placeholders = ', '.join(['?' for _ in columns])
        insert_sql = f"INSERT OR REPLACE INTO {table} ({col_list}) VALUES ({placeholders});"

        cur.execute(f"SELECT {col_list} FROM {table}")
        rows = cur.fetchall()
        if not rows:
            print(f"   Table {table}: 0 ligne (passé)")
            continue

        print(f"   Upload de {len(rows)} lignes dans {table}...")
        batch_size = 50
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i+batch_size]
            batch_reqs = []
            for r in batch:
                args = [sql_to_turso_arg(v) for v in r]
                batch_reqs.append({
                    'type': 'execute',
                    'stmt': {
                        'sql': insert_sql,
                        'args': args
                    }
                })
            execute_pipeline(batch_reqs)
            time.sleep(0.05) # respect rate limit

        print(f"   -> {table}: {len(rows)} lignes uploadées avec succès !")

    conn.close()

    print("\n3. Vérification des données en ligne sur Turso...")
    verify_reqs = [
        {'type': 'execute', 'stmt': {'sql': f"SELECT COUNT(*) FROM {t};"}} for t in ['users', 'media_table', 'list_entries', 'episode_progresses', 'watch_histories']
    ]
    res = execute_pipeline(verify_reqs)
    names = ['users', 'media_table', 'list_entries', 'episode_progresses', 'watch_histories']
    for idx, r in enumerate(res['results']):
        count = r['response']['result']['rows'][0][0]['value']
        print(f"   * {names[idx]}: {count} lignes sur Turso")

    print("\n=== TOUTES LES DONNÉES SONT EN LIGNE SUR TURSO ===")

if __name__ == '__main__':
    main()
