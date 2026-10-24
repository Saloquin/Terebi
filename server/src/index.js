import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { jwt, sign, verify } from 'hono/jwt';

const app = new Hono();

app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

app.get('/', (c) => c.json({ status: 'ok', service: 'terebi-api', version: '1.0.0' }));

// --- Helper Turso libSQL Pipeline HTTP ---
async function queryTurso(env, sql, args = []) {
  const dbUrl = env.TURSO_DATABASE_URL.replace(/\/+$/, '') + '/v2/pipeline';
  const token = env.TURSO_AUTH_TOKEN;

  const tursoArgs = args.map(arg => {
    if (arg === null || arg === undefined) return { type: 'null' };
    if (typeof arg === 'number') {
      return Number.isInteger(arg)
        ? { type: 'integer', value: String(arg) }
        : { type: 'float', value: arg };
    }
    if (typeof arg === 'boolean') return { type: 'integer', value: arg ? '1' : '0' };
    return { type: 'text', value: String(arg) };
  });

  const res = await fetch(dbUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      requests: [{ type: 'execute', stmt: { sql, args: tursoArgs } }]
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Turso HTTP error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  const first = data.results?.[0];
  if (!first) return [];
  if (first.type === 'error') {
    throw new Error(first.error?.message || 'Erreur SQLite');
  }

  const result = first.response?.result;
  if (!result || !result.rows) return [];

  const cols = result.cols?.map(c => c.name) || [];
  return result.rows.map(row => {
    const obj = {};
    cols.forEach((col, i) => {
      const cell = row[i];
      if (!cell || cell.type === 'null') {
        obj[col] = null;
      } else if (cell.type === 'integer') {
        obj[col] = parseInt(cell.value, 10);
      } else if (cell.type === 'float') {
        obj[col] = cell.value;
      } else {
        obj[col] = cell.value;
      }
    });
    return obj;
  });
}

// --- Hashage de mot de passe sécurisé (SHA-256 avec sel) ---
async function hashPassword(password, salt) {
  const enc = new TextEncoder();
  const data = enc.encode(salt + password);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padLeft ? b.toString(16).padLeft(2, '0') : b.toString(16).padStart(2, '0')).join('');
}

function generateRandomHex(bytesCount = 16) {
  const arr = new Uint8Array(bytesCount);
  crypto.getRandomValues(arr);
  return Array.from(arr).map(b => b.toString(16).padStart(2, '0')).join('');
}

// --- Middleware Auth JWT ---
const authMiddleware = async (c, next) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Non authentifié. Token manquant.' }, 401);
  }
  const token = authHeader.substring(7);
  try {
    const payload = await verify(token, c.env.JWT_SECRET || 'terebi_secret_key');
    c.set('user', payload);
    await next();
  } catch (err) {
    return c.json({ error: 'Session invalide ou expirée.' }, 401);
  }
};

// ============================================================================
// ROUTES API
// ============================================================================

// 1. Healthcheck
app.get('/api/health', (c) => c.json({ status: 'ok', service: 'Terebi Secure API', time: Date.now() }));

// 2. Inscription
app.post('/api/auth/register', async (c) => {
  try {
    const body = await c.req.json();
    const username = (body.username || '').trim();
    const password = body.password || '';
    const email = (body.email || '').trim() || null;
    const avatarStyle = body.avatarStyle || 'lorelei';
    const avatarSeed = (body.avatarSeed || '').trim() || username;

    if (username.length < 2) return c.json({ error: 'Le pseudo doit comporter au moins 2 caractères.' }, 400);
    if (password.length < 4) return c.json({ error: 'Le mot de passe doit comporter au moins 4 caractères.' }, 400);

    const existing = await queryTurso(c.env, 'SELECT id FROM users WHERE username = ? COLLATE NOCASE LIMIT 1', [username]);
    if (existing.length > 0) {
      return c.json({ error: 'Ce nom d\'utilisateur est déjà pris.' }, 409);
    }

    const userId = crypto.randomUUID();
    const salt = generateRandomHex(16);
    const pwdHash = await hashPassword(password, salt);
    const now = Date.now();

    await queryTurso(c.env, `
      INSERT INTO users (id, username, email, password_hash, salt, avatar_style, avatar_seed, bio, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [userId, username, email, pwdHash, salt, avatarStyle, avatarSeed, 'Membre passionné d\'animes', now, now]);

    const token = await sign({ userId, username, exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 365) }, c.env.JWT_SECRET || 'terebi_secret_key');

    return c.json({
      token,
      user: {
        id: userId,
        username,
        email,
        avatarStyle,
        avatarSeed,
        bio: 'Membre passionné d\'animes',
        createdAt: now,
      }
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// 3. Connexion
app.post('/api/auth/login', async (c) => {
  try {
    const { username, password } = await c.req.json();
    const cleanUsername = (username || '').trim();
    if (!cleanUsername || !password) return c.json({ error: 'Pseudo et mot de passe requis.' }, 400);

    const rows = await queryTurso(c.env, 'SELECT * FROM users WHERE username = ? COLLATE NOCASE LIMIT 1', [cleanUsername]);
    if (rows.length === 0) return c.json({ error: 'Compte introuvable.' }, 404);

    const user = rows[0];
    const computed = await hashPassword(password, user.salt);
    if (computed !== user.password_hash) {
      return c.json({ error: 'Mot de passe incorrect.' }, 401);
    }

    const token = await sign({ userId: user.id, username: user.username, exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 365) }, c.env.JWT_SECRET || 'terebi_secret_key');

    return c.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        avatarStyle: user.avatar_style || 'lorelei',
        avatarSeed: user.avatar_seed || user.username,
        avatarUrl: user.avatar_url,
        bio: user.bio || '',
        createdAt: user.created_at,
      }
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// 4. Profil utilisateur connecté
app.get('/api/profile/me', authMiddleware, async (c) => {
  const { userId } = c.get('user');
  const rows = await queryTurso(c.env, 'SELECT * FROM users WHERE id = ? LIMIT 1', [userId]);
  if (rows.length === 0) return c.json({ error: 'Utilisateur introuvable.' }, 404);

  const user = rows[0];
  delete user.password_hash;
  delete user.salt;
  return c.json(user);
});

// 5. Modification du profil (pseudo, avatar, bio)
app.post('/api/profile/update', authMiddleware, async (c) => {
  try {
    const { userId } = c.get('user');
    const { username, avatarStyle, avatarSeed, bio } = await c.req.json();

    const currentRows = await queryTurso(c.env, 'SELECT * FROM users WHERE id = ? LIMIT 1', [userId]);
    if (currentRows.length === 0) return c.json({ error: 'Utilisateur introuvable.' }, 404);
    const current = currentRows[0];

    let newUsername = current.username;
    if (username && username.trim() !== current.username) {
      const cleanNew = username.trim();
      if (cleanNew.length < 2) return c.json({ error: 'Le pseudo doit comporter au moins 2 caractères.' }, 400);
      const existing = await queryTurso(c.env, 'SELECT id FROM users WHERE username = ? COLLATE NOCASE AND id != ? LIMIT 1', [cleanNew, userId]);
      if (existing.length > 0) return c.json({ error: 'Ce pseudo est déjà pris.' }, 409);
      newUsername = cleanNew;
    }

    const newStyle = avatarStyle || current.avatar_style || 'lorelei';
    const newSeed = (avatarSeed !== undefined ? avatarSeed.trim() : current.avatar_seed) || newUsername;
    const newBio = bio !== undefined ? bio : current.bio;
    const now = Date.now();

    await queryTurso(c.env, `
      UPDATE users 
      SET username = ?, avatar_style = ?, avatar_seed = ?, bio = ?, updated_at = ?
      WHERE id = ?
    `, [newUsername, newStyle, newSeed, newBio, now, userId]);

    return c.json({
      id: userId,
      username: newUsername,
      avatarStyle: newStyle,
      avatarSeed: newSeed,
      bio: newBio,
      updatedAt: now,
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// 6. Modification du mot de passe
app.post('/api/profile/password', authMiddleware, async (c) => {
  try {
    const { userId } = c.get('user');
    const { oldPassword, newPassword } = await c.req.json();
    if (!newPassword || newPassword.length < 4) return c.json({ error: 'Le nouveau mot de passe doit faire au moins 4 caractères.' }, 400);

    const rows = await queryTurso(c.env, 'SELECT salt, password_hash FROM users WHERE id = ? LIMIT 1', [userId]);
    if (rows.length === 0) return c.json({ error: 'Utilisateur introuvable.' }, 404);

    const { salt, password_hash } = rows[0];
    const computed = await hashPassword(oldPassword, salt);
    if (computed !== password_hash) {
      return c.json({ error: 'L\'ancien mot de passe est incorrect.' }, 401);
    }

    const newSalt = generateRandomHex(16);
    const newHash = await hashPassword(newPassword, newSalt);
    const now = Date.now();

    await queryTurso(c.env, 'UPDATE users SET password_hash = ?, salt = ?, updated_at = ? WHERE id = ?', [newHash, newSalt, now, userId]);
    return c.json({ success: true, message: 'Mot de passe mis à jour avec succès.' });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// 7. LEADERBOARD & DASHBOARDS COMMUNAUTAIRES
app.get('/api/leaderboard', async (c) => {
  try {
    // Liste des utilisateurs avec leurs totaux de visionnage
    const usersStats = await queryTurso(c.env, `
      SELECT 
        u.id,
        u.username,
        u.avatar_style,
        u.avatar_seed,
        u.bio,
        u.created_at,
        COUNT(DISTINCT CASE WHEN l.status = 'completed' THEN l.media_id END) as completed_count,
        COUNT(DISTINCT l.media_id) as total_animes,
        COALESCE(SUM(DISTINCT CASE WHEN p.watched = 1 THEN 1 ELSE 0 END), 0) as episodes_watched,
        COALESCE(ROUND(SUM(w.watched_seconds) / 3600.0, 1), 0.0) as watched_hours
      FROM users u
      LEFT JOIN list_entries l ON l.user_id = u.id
      LEFT JOIN episode_progresses p ON p.user_id = u.id
      LEFT JOIN watch_histories w ON w.user_id = u.id
      GROUP BY u.id
      ORDER BY watched_hours DESC, episodes_watched DESC, completed_count DESC
      LIMIT 100
    `);

    // Top 5 animes les plus suivis dans la communauté
    const topAnimes = await queryTurso(c.env, `
      SELECT 
        m.anilist_id,
        m.anime_sama_title,
        m.title_romaji,
        m.cover_url,
        m.genres_json,
        COUNT(l.user_id) as tracking_users
      FROM media_table m
      JOIN list_entries l ON l.media_id = m.anilist_id
      GROUP BY m.anilist_id
      ORDER BY tracking_users DESC
      LIMIT 5
    `);

    // Statistiques globales de la communauté
    const globalStats = await queryTurso(c.env, `
      SELECT 
        COUNT(DISTINCT u.id) as total_users,
        COUNT(DISTINCT l.media_id) as community_unique_animes,
        COALESCE(ROUND(SUM(w.watched_seconds) / 3600.0, 1), 0.0) as community_total_hours
      FROM users u
      LEFT JOIN list_entries l ON l.user_id = u.id
      LEFT JOIN watch_histories w ON w.user_id = u.id
    `);

    return c.json({
      leaderboard: usersStats.map((u, index) => ({
        rank: index + 1,
        id: u.id,
        username: u.username,
        avatarStyle: u.avatar_style || 'lorelei',
        avatarSeed: u.avatar_seed || u.username,
        bio: u.bio,
        createdAt: u.created_at,
        completedCount: u.completed_count || 0,
        totalAnimes: u.total_animes || 0,
        episodesWatched: u.episodes_watched || 0,
        watchedHours: u.watched_hours || 0.0,
      })),
      dashboards: {
        totalUsers: globalStats[0]?.total_users || 0,
        uniqueAnimes: globalStats[0]?.community_unique_animes || 0,
        totalHours: globalStats[0]?.community_total_hours || 0.0,
        topAnimes: topAnimes.map(a => ({
          mediaId: a.anilist_id,
          title: a.anime_sama_title || a.title_romaji || 'Anime',
          coverUrl: a.cover_url,
          trackingUsers: a.tracking_users || 0,
        })),
      }
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

export default app;
