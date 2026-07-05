import type {
  AniListMedia,
  ApiResponse,
  MediaListEntry,
  MediaListStatus,
  PlanningPageData,
  SeasonPageData,
  SamaResolveResult,
} from '../types/anilist';
import { getAnilistToken, clearAnilistToken } from '../lib/storage';

const BASE = '/api';
const PLANNING_CACHE_TTL_MS = 5 * 60 * 1000;

const planningCache = new Map<string, { data: PlanningPageData; expiresAt: number }>();

export class ApiError extends Error {
  constructor(message: string, public readonly status: number, public readonly code?: string) {
    super(message);
    this.name = 'ApiError';
  }

  get isAnilistAuth() {
    return this.status === 401 && this.code === 'ANILIST_AUTH';
  }

  get isAnilistForbidden() {
    return this.status === 403 && this.code === 'ANILIST_FORBIDDEN';
  }

  get isAnilistDisabled() {
    return this.code === 'ANILIST_DISABLED';
  }

  get isRateLimit() {
    return this.status === 429 && this.code === 'ANILIST_RATE_LIMIT';
  }
}

function authHeaders(): Record<string, string> {
  const token = getAnilistToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

function handleApiFailure<T>(res: Response, json: ApiResponse<T>): never {
  if (
    getAnilistToken() &&
    (json.code === 'ANILIST_AUTH' || json.code === 'ANILIST_FORBIDDEN')
  ) {
    clearAnilistToken();
  }
  throw new ApiError(json.error || `Erreur API ${res.status}`, res.status, json.code);
}

async function publicRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, init);
  const json = (await res.json()) as ApiResponse<T>;
  if (!json.success || json.data === null) {
    handleApiFailure(res, json);
  }
  return json.data;
}

async function authRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const headers: Record<string, string> = {
    ...authHeaders(),
    ...(init?.headers as Record<string, string> | undefined),
  };
  const res = await fetch(`${BASE}${path}`, { ...init, headers });
  const json = (await res.json()) as ApiResponse<T>;
  if (!json.success || json.data === null) {
    handleApiFailure(res, json);
  }
  return json.data;
}

function planningCacheKey(season: string, year: number): string {
  return `${season}:${year}`;
}

export const api = {
  getCurrentSeason: () => publicRequest<{ season: string; year: number }>('/anilist/current-season'),

  getOAuthAuthorizeUrl: (clientId?: string) => {
    const q = clientId ? `?clientId=${encodeURIComponent(clientId)}` : '';
    return publicRequest<{ url: string; redirectUri: string }>(`/anilist/oauth/authorize-url${q}`);
  },

  buildOAuthUrl: (clientId: string, redirectUri?: string) =>
    publicRequest<{ url: string; redirectUri: string }>('/anilist/auth/url', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ clientId, redirectUri }),
    }),

  exchangeAuthCode: (code: string, clientId: string, clientSecret: string, redirectUri?: string) =>
    publicRequest<{ accessToken: string }>('/anilist/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code, clientId, clientSecret, redirectUri }),
    }),

  getOAuthStatus: () =>
    authRequest<{ connected: boolean; username?: string; userId?: number; expired?: boolean }>(
      '/anilist/oauth/status'
    ),

  disconnectOAuth: () => {
    clearAnilistToken();
    return Promise.resolve({ disconnected: true as const });
  },

  getMe: () => authRequest<{ id: number; name: string }>('/anilist/me'),

  getLists: (statuses: MediaListStatus[]) =>
    authRequest<{ entries: MediaListEntry[] }>(`/anilist/lists?status=${statuses.join(',')}`),

  addToList: (mediaId: number, status: MediaListStatus, progress?: number) =>
    authRequest<MediaListEntry>(`/anilist/lists/${mediaId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status, progress }),
    }),

  removeFromList: (mediaId: number) =>
    authRequest<{ deleted: boolean }>(`/anilist/lists/${mediaId}`, { method: 'DELETE' }),

  getSeason: (season: string, year: number, page = 1) =>
    publicRequest<SeasonPageData>(`/anilist/season?season=${season}&year=${year}&page=${page}`),

  getPlanning: async (season: string, year: number, signal?: AbortSignal) => {
    const key = planningCacheKey(season, year);
    const cached = planningCache.get(key);
    if (cached && Date.now() < cached.expiresAt) {
      return cached.data;
    }
    const data = await publicRequest<PlanningPageData & { anilistRequests?: number }>(
      `/anilist/planning?season=${season}&year=${year}`,
      { signal }
    );
    planningCache.set(key, { data, expiresAt: Date.now() + PLANNING_CACHE_TTL_MS });
    return data;
  },

  invalidatePlanningCache: () => {
    planningCache.clear();
  },

  search: (q: string, page = 1) =>
    publicRequest<SeasonPageData>(`/anilist/search?q=${encodeURIComponent(q)}&page=${page}`),

  getAnime: (id: number) => publicRequest<AniListMedia>(`/anilist/anime/${id}`),

  resolveSama: (title: string, season?: number) => {
    const params = new URLSearchParams({ title });
    if (season !== undefined) params.set('season', String(season));
    return publicRequest<SamaResolveResult>(`/sama/resolve?${params}`);
  },

  getConfig: () =>
    publicRequest<{ extension: string; baseUrl: string }>('/config'),

  setExtension: (extension: string) =>
    publicRequest<{ extension: string; baseUrl: string }>('/config/extension', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ extension }),
    }),
};
