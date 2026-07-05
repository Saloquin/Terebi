import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';

const DB_DIR = path.join(__dirname, '..', '..', 'data');
const DB_PATH = path.join(DB_DIR, 'anime.db');

let db: Database.Database | null = null;

const SCHEMA = `
CREATE TABLE IF NOT EXISTS hidden_animes (
    anilist_id INTEGER PRIMARY KEY,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sama_cache (
    cache_key TEXT PRIMARY KEY,
    url TEXT NOT NULL,
    slug TEXT,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS episode_progress (
    anilist_id INTEGER NOT NULL,
    season_number INTEGER NOT NULL DEFAULT 1,
    last_episode INTEGER NOT NULL,
    total_episodes INTEGER,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (anilist_id, season_number)
);

CREATE TABLE IF NOT EXISTS user_lists (
    list_type TEXT NOT NULL CHECK (list_type IN ('towatch', 'viewed')),
    anilist_id INTEGER NOT NULL,
    added_at TEXT NOT NULL,
    PRIMARY KEY (list_type, anilist_id)
);

CREATE TABLE IF NOT EXISTS user_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
`;

const migrateLegacySchema = (database: Database.Database): void => {
    const tables = database
        .prepare("SELECT name FROM sqlite_master WHERE type='table'")
        .all() as Array<{ name: string }>;
    const tableNames = new Set(tables.map(t => t.name));

    if (tableNames.has('dashboard_state')) {
        try {
            const row = database
                .prepare('SELECT data FROM dashboard_state WHERE id = 1')
                .get() as { data: string } | undefined;
            if (row) {
                const parsed = JSON.parse(row.data) as { hidden?: string[] };
                const insertHidden = database.prepare(
                    'INSERT OR IGNORE INTO hidden_animes (anilist_id, created_at) VALUES (?, ?)'
                );
                for (const id of parsed.hidden || []) {
                    const numId = parseInt(id, 10);
                    if (!Number.isNaN(numId)) {
                        insertHidden.run(numId, new Date().toISOString());
                    }
                }
            }
        } catch {
            // ignore migration errors
        }
        database.exec('DROP TABLE IF EXISTS dashboard_state');
    }

    if (tableNames.has('episode_progress')) {
        const cols = database
            .prepare('PRAGMA table_info(episode_progress)')
            .all() as Array<{ name: string }>;
        if (cols.some(c => c.name === 'season_url')) {
            database.exec('DROP TABLE IF EXISTS episode_progress');
            database.exec(`
                CREATE TABLE episode_progress (
                    anilist_id INTEGER NOT NULL,
                    season_number INTEGER NOT NULL DEFAULT 1,
                    last_episode INTEGER NOT NULL,
                    total_episodes INTEGER,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY (anilist_id, season_number)
                )
            `);
        }
    }
};

export const getDb = (): Database.Database => {
    if (!db) {
        if (!fs.existsSync(DB_DIR)) {
            fs.mkdirSync(DB_DIR, { recursive: true });
        }

        db = new Database(DB_PATH);
        db.pragma('journal_mode = WAL');
        db.exec(SCHEMA);
        migrateLegacySchema(db);

        const extRow = db
            .prepare('SELECT value FROM user_settings WHERE key = ?')
            .get('extension') as { value: string } | undefined;
        if (!extRow) {
            db.prepare('INSERT INTO user_settings (key, value) VALUES (?, ?)').run(
                'extension',
                process.env.SITE_EXTENSION || 'to'
            );
        }
    }

    return db;
};

export const closeDb = (): void => {
    if (db) {
        db.close();
        db = null;
    }
};

export const getDbPath = (): string => DB_PATH;
