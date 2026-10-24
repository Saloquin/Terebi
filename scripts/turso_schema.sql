-- ============================================================================
-- SCHÉMA TEREBI CLOUD (TURSO / LIBSQL)
-- Base de données multi-utilisateurs avec persistance en ligne
-- ============================================================================

-- 1. Table des Utilisateurs
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,                          -- Identifiant unique UUID v4
  username TEXT NOT NULL UNIQUE COLLATE NOCASE, -- Pseudo unique (insensible à la casse)
  email TEXT UNIQUE COLLATE NOCASE,             -- Email optionnel
  password_hash TEXT NOT NULL,                  -- Hash SHA-256 avec sel
  salt TEXT NOT NULL,                           -- Sel cryptographique (hex)
  avatar_style TEXT NOT NULL DEFAULT 'lorelei', -- Style DiceBear (lorelei, adventurer, bottts, etc.)
  avatar_seed TEXT NOT NULL,                    -- Graine DiceBear (ex: pseudo ou aléatoire)
  avatar_url TEXT,                              -- URL personnalisée optionnelle
  bio TEXT DEFAULT '',                          -- Courte présentation
  created_at INTEGER NOT NULL,                  -- Timestamp millisecondes
  updated_at INTEGER NOT NULL                   -- Timestamp millisecondes
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- 2. Sessions utilisateur (pour "rester connecté")
CREATE TABLE IF NOT EXISTS user_sessions (
  token TEXT PRIMARY KEY,                       -- Jeton de session aléatoire (64 hex)
  user_id TEXT NOT NULL,                        -- ID de l'utilisateur
  device_name TEXT,                             -- Nom de l'appareil (ex: "Windows Desktop")
  created_at INTEGER NOT NULL,                  -- Timestamp millisecondes
  last_used_at INTEGER NOT NULL,                -- Dernière activité
  expires_at INTEGER,                           -- NULL = persistante jusqu'à déconnexion
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions(user_id);

-- 3. Catalogue des Médias (partagé entre tous les utilisateurs)
CREATE TABLE IF NOT EXISTS media_table (
  anilist_id INTEGER PRIMARY KEY,               -- ID technique dérivé du slug Anime-Sama
  title_romaji TEXT,
  title_english TEXT,
  title_native TEXT,
  episodes INTEGER,
  cover_url TEXT,
  banner_url TEXT,
  description TEXT,
  genres_json TEXT NOT NULL DEFAULT '[]',
  updated_at INTEGER NOT NULL,
  anime_sama_title TEXT,
  anime_sama_slug TEXT
);

CREATE INDEX IF NOT EXISTS idx_media_slug ON media_table(anime_sama_slug);

-- 4. Entrées de bibliothèque de chaque utilisateur
CREATE TABLE IF NOT EXISTS list_entries (
  user_id TEXT NOT NULL,
  media_id INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'planning',      -- current, completed, planning, dropped, paused
  progress INTEGER NOT NULL DEFAULT 0,
  hidden_from_planning INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, media_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_list_entries_user_status ON list_entries(user_id, status);

-- 5. Progression de lecture des épisodes par utilisateur
CREATE TABLE IF NOT EXISTS episode_progresses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  media_id INTEGER NOT NULL,
  episode_number REAL NOT NULL,
  watched INTEGER NOT NULL DEFAULT 0,           -- 1 = vu, 0 = non vu
  position_seconds REAL NOT NULL DEFAULT 0.0,
  duration_seconds REAL,
  completed_at INTEGER,
  updated_at INTEGER NOT NULL,
  UNIQUE(user_id, media_id, episode_number),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ep_progress_user_media ON episode_progresses(user_id, media_id);

-- 6. Historique de visionnage par utilisateur
CREATE TABLE IF NOT EXISTS watch_histories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  media_id INTEGER NOT NULL,
  episode_number REAL NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER,
  watched_seconds REAL NOT NULL DEFAULT 0.0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_watch_history_user ON watch_histories(user_id, started_at DESC);

-- 7. Paramètres et clés de progression par utilisateur
CREATE TABLE IF NOT EXISTS user_settings (
  user_id TEXT NOT NULL,
  key TEXT NOT NULL,                            -- Ex: anime_sama_watched:id:saison, prioritize_new_episodes
  value TEXT NOT NULL,
  PRIMARY KEY (user_id, key),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 8. Paramètres globaux du serveur / application
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- 9. Cache des métadonnées et plannings
CREATE TABLE IF NOT EXISTS meta_cache (
  cache_key TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
