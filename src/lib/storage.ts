const TOKEN_KEY = 'anilist_token';
const HIDDEN_KEY = 'hidden_animes';

const LEGACY_KEYS = [
  'anilist_client_id',
  'anilist_client_secret',
  'sama_cache',
  'anilist_refresh_token',
] as const;

const OAUTH_SESSION_ID = 'anilist_oauth_client_id';
const OAUTH_SESSION_SECRET = 'anilist_oauth_client_secret';
const OAUTH_SESSION_REDIRECT = 'anilist_oauth_redirect_uri';

/** @deprecated Use getAnilistRedirectUri() — kept for tests/fallback */
export const DEFAULT_ANILIST_REDIRECT_URI = 'http://localhost:5173/callback';

export function getAnilistRedirectUri(): string {
  if (typeof window !== 'undefined') {
    return `${window.location.origin}/callback`;
  }
  return DEFAULT_ANILIST_REDIRECT_URI;
}

/** Redirect URI matching the current OAuth callback path (supports /callback and /settings/callback). */
export function getOAuthRedirectUriFromPath(): string {
  if (typeof window !== 'undefined') {
    const path = window.location.pathname;
    if (path === '/callback' || path === '/settings/callback') {
      return `${window.location.origin}${path}`;
    }
  }
  return getAnilistRedirectUri();
}

export function purgeLegacyStorage(): void {
  for (const key of LEGACY_KEYS) {
    localStorage.removeItem(key);
  }
}

export function getAnilistToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setAnilistToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearAnilistToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

export function getHiddenIds(): number[] {
  try {
    const raw = localStorage.getItem(HIDDEN_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((id): id is number => typeof id === 'number');
  } catch {
    return [];
  }
}

export function setHiddenIds(ids: number[]): void {
  localStorage.setItem(HIDDEN_KEY, JSON.stringify(ids));
}

export function hideAnime(id: number): number[] {
  const ids = getHiddenIds();
  if (!ids.includes(id)) ids.unshift(id);
  setHiddenIds(ids);
  return ids;
}

export function unhideAnime(id: number): number[] {
  const ids = getHiddenIds().filter(i => i !== id);
  setHiddenIds(ids);
  return ids;
}

export function storeOAuthCredentials(
  clientId: string,
  clientSecret: string,
  redirectUri?: string,
): void {
  sessionStorage.setItem(OAUTH_SESSION_ID, clientId.trim());
  sessionStorage.setItem(OAUTH_SESSION_SECRET, clientSecret.trim());
  if (redirectUri?.trim()) {
    sessionStorage.setItem(OAUTH_SESSION_REDIRECT, redirectUri.trim());
  }
}

export function consumeOAuthCredentials(): {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
} | null {
  const clientId = sessionStorage.getItem(OAUTH_SESSION_ID)?.trim();
  const clientSecret = sessionStorage.getItem(OAUTH_SESSION_SECRET)?.trim();
  const redirectUri =
    sessionStorage.getItem(OAUTH_SESSION_REDIRECT)?.trim() || getOAuthRedirectUriFromPath();
  clearOAuthCredentials();
  if (!clientId || !clientSecret) return null;
  return { clientId, clientSecret, redirectUri };
}

export function clearOAuthCredentials(): void {
  sessionStorage.removeItem(OAUTH_SESSION_ID);
  sessionStorage.removeItem(OAUTH_SESSION_SECRET);
  sessionStorage.removeItem(OAUTH_SESSION_REDIRECT);
}

export function consumeTokenFromHash(): string | null {
  const hash = window.location.hash;
  if (!hash.startsWith('#')) return null;
  const params = new URLSearchParams(hash.slice(1));
  const token = params.get('anilist_token') || params.get('access_token');
  if (!token) return null;
  setAnilistToken(token);
  window.history.replaceState(null, '', window.location.pathname + window.location.search);
  return token;
}
