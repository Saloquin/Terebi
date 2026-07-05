import type {
  AniListMedia,
  ApiResponse,
  SeasonPageData,
  SamaResolveResult,
  UserListEntry,
  UserSettings,
} from '../types/anilist';

const BASE = '/api';

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly code?: string
  ) {
    super(message);
    this.name = 'ApiError';
  }

  get isAnilistAuth(): boolean {
    return this.status === 401 && this.code === 'ANILIST_AUTH';
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, init);
  const json = (await res.json()) as ApiResponse<T>;
  if (!json.success || json.data === null) {
    throw new ApiError(json.error || `Erreur API ${res.status}`, res.status, json.code);
  }
  return json.data;
}

export const api = {
  getCurrentSeason: () =>
    request<{ season: string; year: number }>('/anilist/current-season'),

  getSeason: (season: string, year: number, page = 1) =>
    request<SeasonPageData>(
      `/anilist/season?season=${season}&year=${year}&page=${page}`
    ),

  search: (q: string, page = 1) =>
    request<SeasonPageData>(`/anilist/search?q=${encodeURIComponent(q)}&page=${page}`),

  getAnime: (id: number) => request<AniListMedia>(`/anilist/anime/${id}`),

  resolveSama: (title: string, season?: number) => {
    const params = new URLSearchParams({ title });
    if (season !== undefined) params.set('season', String(season));
    return request<SamaResolveResult>(`/sama/resolve?${params}`);
  },

  getSettings: () => request<UserSettings>('/user/settings'),

  saveSettings: (settings: Partial<UserSettings>) =>
    request<UserSettings>('/user/settings', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(settings),
    }),

  getHidden: () => request<number[]>('/user/hidden'),
  hideAnime: (id: number) =>
    request<number[]>(`/user/hidden/${id}`, { method: 'POST' }),
  unhideAnime: (id: number) =>
    request<number[]>(`/user/hidden/${id}`, { method: 'DELETE' }),

  getToWatch: () => request<UserListEntry[]>('/user/towatch'),
  addToWatch: (id: number) =>
    request<UserListEntry[]>(`/user/towatch/${id}`, { method: 'POST' }),
  removeFromWatch: (id: number) =>
    request<UserListEntry[]>(`/user/towatch/${id}`, { method: 'DELETE' }),

  getViewed: () => request<UserListEntry[]>('/user/viewed'),
  addViewed: (id: number) =>
    request<UserListEntry[]>(`/user/viewed/${id}`, { method: 'POST' }),
  removeViewed: (id: number) =>
    request<UserListEntry[]>(`/user/viewed/${id}`, { method: 'DELETE' }),
};
