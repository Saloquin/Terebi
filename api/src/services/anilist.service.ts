import { AniListMedia, AniListPageResult, AniListSeason, MediaListEntry, MediaListStatus } from '../types/anilist.types';
import { anilistCache } from './anilist-cache';
import { anilistQueue } from './anilist-queue';

const ANILIST_URL = 'https://graphql.anilist.co';
const ANILIST_AUTH_URL = 'https://anilist.co/api/v2/oauth/authorize';
const ANILIST_TOKEN_URL = 'https://anilist.co/api/v2/oauth/token';
const USER_AGENT = 'Dashboard-sama-scrapper/1.0';

const MAX_RETRIES = 3;
const CACHE_TTL_MS = 20 * 60 * 1000;
const SEASON_MAX_PAGES = 2;
const API_DISABLED_MARKER = 'temporarily disabled';

const API_DISABLED_MESSAGE =
    "L'API AniList est temporairement désactivée pour maintenance. Consultez le Discord officiel AniList pour plus d'informations.";

const DEFAULT_REDIRECT_URI = 'http://localhost:5173/settings/callback';
const DEFAULT_FRONTEND_URL = 'http://localhost:5173';

export class AniListApiError extends Error {
    constructor(
        message: string,
        public readonly status: number,
        public readonly code?: string,
        public readonly retryAfter?: number
    ) {
        super(message);
        this.name = 'AniListApiError';
    }
}

const MEDIA_FIELDS = `
    id
    idMal
    title { romaji english native }
    coverImage { large medium }
    bannerImage
    description(asHtml: false)
    format
    status
    episodes
    duration
    season
    seasonYear
    genres
    averageScore
    startDate { year month day }
    nextAiringEpisode { airingAt episode }
    siteUrl
    studios(isMain: true) { nodes { name } }
`;

const PLANNING_MEDIA_FIELDS = `
    id
    title { romaji english native }
    coverImage { large medium }
    nextAiringEpisode { airingAt episode }
    status
`;

const LIST_ENTRY_FIELDS = `
    id
    mediaId
    status
    progress
    updatedAt
    media { ${MEDIA_FIELDS} }
`;

const SEASON_ORDER: AniListSeason[] = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];

function prevSeason(season: AniListSeason, year: number): { season: AniListSeason; year: number } {
    const idx = SEASON_ORDER.indexOf(season);
    if (idx <= 0) return { season: 'FALL', year: year - 1 };
    return { season: SEASON_ORDER[idx - 1], year };
}

function sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function parseRetryAfter(response: Response): number {
    const header = response.headers.get('Retry-After');
    if (!header) return 60;
    const seconds = parseInt(header, 10);
    return Number.isFinite(seconds) && seconds > 0 ? seconds : 60;
}

function isApiDisabledText(text: string): boolean {
    return text.toLowerCase().includes(API_DISABLED_MARKER);
}

function throwIfApiDisabled(text: string): void {
    if (isApiDisabledText(text)) {
        throw new AniListApiError(API_DISABLED_MESSAGE, 503, 'ANILIST_DISABLED');
    }
}

function getClientId(): string {
    const id = process.env.ANILIST_CLIENT_ID?.trim();
    if (!id) {
        throw new AniListApiError(
            'ANILIST_CLIENT_ID manquant. Configurez-le dans .env.',
            500,
            'ANILIST_CONFIG'
        );
    }
    return id;
}

function getClientSecret(): string {
    const secret = process.env.ANILIST_CLIENT_SECRET?.trim();
    if (!secret) {
        throw new AniListApiError(
            'ANILIST_CLIENT_SECRET manquant. Configurez-le dans .env.',
            500,
            'ANILIST_CONFIG'
        );
    }
    return secret;
}

class AniListService {
    private planningInflight = new Map<string, Promise<AniListMedia[]>>();
    private requestCount = 0;

    getRequestCount(): number {
        return this.requestCount;
    }

    resetRequestCount(): void {
        this.requestCount = 0;
    }

    getRedirectUri(): string {
        return process.env.ANILIST_REDIRECT_URI?.trim() || DEFAULT_REDIRECT_URI;
    }

    getFrontendUrl(): string {
        return process.env.FRONTEND_URL?.trim() || DEFAULT_FRONTEND_URL;
    }

    hasEnvCredentials(): boolean {
        return Boolean(
            process.env.ANILIST_CLIENT_ID?.trim() && process.env.ANILIST_CLIENT_SECRET?.trim()
        );
    }

    buildAuthorizationUrl(
        clientId: string,
        redirectUri: string,
        responseType: 'code' | 'token' = 'code'
    ): string {
        const params = new URLSearchParams({
            client_id: clientId.trim(),
            redirect_uri: redirectUri.trim(),
            response_type: responseType,
        });
        return `${ANILIST_AUTH_URL}?${params.toString()}`;
    }

    getAuthorizationUrl(): string {
        return this.buildAuthorizationUrl(getClientId(), this.getRedirectUri(), 'code');
    }

    async exchangeCodeForToken(
        code: string,
        clientId?: string,
        clientSecret?: string,
        redirectUri?: string
    ): Promise<string> {
        const response = await fetch(ANILIST_TOKEN_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
                'User-Agent': USER_AGENT,
            },
            body: JSON.stringify({
                grant_type: 'authorization_code',
                client_id: clientId?.trim() || getClientId(),
                client_secret: clientSecret?.trim() || getClientSecret(),
                redirect_uri: redirectUri?.trim() || this.getRedirectUri(),
                code: code.trim(),
            }),
        });

        if (!response.ok) {
            const body = await response.text().catch(() => '');
            throw new AniListApiError(
                `Échec de l'échange OAuth AniList (${response.status})${body ? `: ${body}` : ''}`,
                response.status,
                'ANILIST_OAUTH'
            );
        }

        const json = (await response.json()) as { access_token?: string };
        if (!json.access_token?.trim()) {
            throw new AniListApiError(
                'Réponse OAuth AniList invalide : access_token manquant.',
                500,
                'ANILIST_OAUTH'
            );
        }

        return json.access_token.trim();
    }

    async exchangeCodeWithEnv(code: string): Promise<string> {
        return this.exchangeCodeForToken(code);
    }

    private buildPublicHeaders(): Record<string, string> {
        return {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            'User-Agent': USER_AGENT,
        };
    }

    private buildAuthHeaders(accessToken: string): Record<string, string> {
        return {
            ...this.buildPublicHeaders(),
            Authorization: `Bearer ${accessToken.trim()}`,
        };
    }

    private handleHttpError(status: number, retryAfter?: number, bodyText?: string): never {
        if (bodyText) throwIfApiDisabled(bodyText);
        if (status === 401) {
            throw new AniListApiError(
                'Authentification AniList refusée. Token invalide ou expiré — reconnectez votre compte.',
                401,
                'ANILIST_AUTH'
            );
        }
        if (status === 403) {
            throw new AniListApiError(
                'Accès AniList refusé (403). Réessayez plus tard.',
                403,
                'ANILIST_FORBIDDEN'
            );
        }
        if (status === 429) {
            throw new AniListApiError(
                `Limite de requêtes AniList atteinte. Réessayez dans ${retryAfter ?? 60} secondes.`,
                429,
                'ANILIST_RATE_LIMIT',
                retryAfter
            );
        }
        throw new AniListApiError(`Erreur AniList API: ${status}`, status);
    }

    private async executeGraphql<T>(
        queryStr: string,
        variables: Record<string, unknown>,
        headers: Record<string, string>,
        cacheKey?: string
    ): Promise<T> {
        if (cacheKey) {
            const cached = anilistCache.get<T>(cacheKey);
            if (cached !== undefined) return cached;
        }

        let lastError: AniListApiError | null = null;

        for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            const response = await anilistQueue.enqueue(() =>
                fetch(ANILIST_URL, {
                    method: 'POST',
                    headers,
                    body: JSON.stringify({ query: queryStr, variables }),
                })
            );

            this.requestCount++;

            const bodyText = await response.text();
            throwIfApiDisabled(bodyText);

            if (response.status === 429) {
                const retryAfter = parseRetryAfter(response);
                lastError = new AniListApiError(
                    `Limite de requêtes AniList atteinte. Réessayez dans ${retryAfter} secondes.`,
                    429,
                    'ANILIST_RATE_LIMIT',
                    retryAfter
                );
                if (attempt < MAX_RETRIES) {
                    await sleep(retryAfter * 1000);
                    continue;
                }
                throw lastError;
            }

            if (response.status === 401) {
                throw new AniListApiError(
                    'Authentification AniList refusée. Token invalide ou expiré — reconnectez votre compte.',
                    401,
                    'ANILIST_AUTH'
                );
            }

            if (response.status === 403) {
                if (headers.Authorization) {
                    throw new AniListApiError(
                        'Accès AniList refusé (403). Token invalide — reconnectez votre compte ou déconnectez-vous.',
                        403,
                        'ANILIST_FORBIDDEN'
                    );
                }
                this.handleHttpError(403, undefined, bodyText);
            }

            if (!response.ok) {
                this.handleHttpError(response.status, undefined, bodyText);
            }

            let json: { data?: T; errors?: Array<{ message: string; status?: number }> };
            try {
                json = JSON.parse(bodyText) as typeof json;
            } catch {
                throw new AniListApiError('Réponse AniList invalide.', 502, 'ANILIST_BAD_RESPONSE');
            }

            if (json.errors?.length) {
                const messages = json.errors.map(e => e.message).join(', ');
                throwIfApiDisabled(messages);

                const authError = json.errors.find(e => e.status === 401);
                if (authError) {
                    throw new AniListApiError(
                        'Authentification AniList refusée. Token invalide ou expiré — reconnectez votre compte.',
                        401,
                        'ANILIST_AUTH'
                    );
                }

                const forbiddenError = json.errors.find(e => e.status === 403);
                if (forbiddenError) {
                    throw new AniListApiError(
                        'Accès AniList refusé (403). Token invalide — reconnectez votre compte ou déconnectez-vous.',
                        403,
                        'ANILIST_FORBIDDEN'
                    );
                }

                const rateLimitError = json.errors.find(e => e.status === 429);
                if (rateLimitError) {
                    const retryAfter = parseRetryAfter(response);
                    lastError = new AniListApiError(
                        `Limite de requêtes AniList atteinte. Réessayez dans ${retryAfter} secondes.`,
                        429,
                        'ANILIST_RATE_LIMIT',
                        retryAfter
                    );
                    if (attempt < MAX_RETRIES) {
                        await sleep(retryAfter * 1000);
                        continue;
                    }
                    throw lastError;
                }
                throw new Error(messages);
            }

            if (!json.data) {
                throw new Error('AniList API returned no data');
            }

            if (cacheKey) {
                anilistCache.set(cacheKey, json.data, CACHE_TTL_MS);
            }
            return json.data;
        }

        throw lastError ?? new AniListApiError('Erreur AniList API', 500);
    }

    private queryPublic<T>(
        queryStr: string,
        variables: Record<string, unknown>,
        cacheKey?: string
    ): Promise<T> {
        return this.executeGraphql<T>(queryStr, variables, this.buildPublicHeaders(), cacheKey);
    }

    private queryAuth<T>(
        queryStr: string,
        variables: Record<string, unknown>,
        accessToken: string,
        cacheKey?: string
    ): Promise<T> {
        const token = accessToken.trim();
        if (!token) {
            throw new AniListApiError(
                'Token AniList requis. Connectez votre compte.',
                401,
                'ANILIST_AUTH'
            );
        }
        return this.executeGraphql<T>(queryStr, variables, this.buildAuthHeaders(token), cacheKey);
    }

    async getViewer(accessToken: string): Promise<{ id: number; name: string }> {
        const data = await this.queryAuth<{ Viewer: { id: number; name: string } | null }>(
            `query { Viewer { id name } }`,
            {},
            accessToken
        );
        if (!data.Viewer) {
            throw new AniListApiError('Non authentifié', 401, 'ANILIST_AUTH');
        }
        return data.Viewer;
    }

    async getMediaListEntries(
        accessToken: string,
        statuses: MediaListStatus[]
    ): Promise<MediaListEntry[]> {
        const viewer = await this.getViewer(accessToken);
        const all: MediaListEntry[] = [];

        for (const status of statuses) {
            let page = 1;
            let hasNext = true;
            while (hasNext) {
                const data = await this.queryAuth<{
                    Page: {
                        pageInfo: { hasNextPage: boolean };
                        mediaList: MediaListEntry[];
                    };
                }>(
                    `query ($userId: Int, $status: MediaListStatus, $page: Int) {
                        Page(page: $page, perPage: 50) {
                            pageInfo { hasNextPage }
                            mediaList(userId: $userId, type: ANIME, status: $status, sort: UPDATED_TIME_DESC) {
                                ${LIST_ENTRY_FIELDS}
                            }
                        }
                    }`,
                    { userId: viewer.id, status, page },
                    accessToken
                );
                all.push(...data.Page.mediaList);
                hasNext = data.Page.pageInfo.hasNextPage;
                page++;
                if (page > 20) break;
            }
        }

        all.sort((a, b) => b.updatedAt - a.updatedAt);
        return all;
    }

    async saveMediaListEntry(
        accessToken: string,
        mediaId: number,
        status: MediaListStatus,
        progress?: number
    ): Promise<MediaListEntry> {
        anilistCache.delete(`lists:${accessToken.slice(0, 8)}`);
        const data = await this.queryAuth<{ SaveMediaListEntry: MediaListEntry }>(
            `mutation ($mediaId: Int, $status: MediaListStatus, $progress: Int) {
                SaveMediaListEntry(mediaId: $mediaId, status: $status, progress: $progress) {
                    ${LIST_ENTRY_FIELDS}
                }
            }`,
            { mediaId, status, progress: progress ?? null },
            accessToken
        );
        return data.SaveMediaListEntry;
    }

    async deleteMediaListEntry(accessToken: string, mediaId: number): Promise<boolean> {
        const data = await this.queryAuth<{ DeleteMediaListEntry: { deleted: boolean } | null }>(
            `mutation ($mediaId: Int) {
                DeleteMediaListEntry(mediaId: $mediaId) { deleted }
            }`,
            { mediaId },
            accessToken
        );
        return data.DeleteMediaListEntry?.deleted ?? false;
    }

    getCurrentSeason(): { season: AniListSeason; year: number } {
        const now = new Date();
        const month = now.getMonth() + 1;
        const year = now.getFullYear();
        let season: AniListSeason;
        if (month >= 1 && month <= 3) season = 'WINTER';
        else if (month >= 4 && month <= 6) season = 'SPRING';
        else if (month >= 7 && month <= 9) season = 'SUMMER';
        else season = 'FALL';
        return { season, year };
    }

    async getSeason(
        season: AniListSeason,
        year: number,
        page = 1,
        perPage = 50,
        status?: string
    ): Promise<AniListPageResult> {
        const cacheKey = status
            ? `season:${season}:${year}:${status}:${page}:${perPage}`
            : `season:${season}:${year}:${page}:${perPage}`;

        const statusFilter = status ? ', status: $status' : '';
        const data = await this.queryPublic<{ Page: AniListPageResult }>(
            `query ($season: MediaSeason, $year: Int, $page: Int, $perPage: Int${status ? ', $status: MediaStatus' : ''}) {
                Page(page: $page, perPage: $perPage) {
                    pageInfo { total currentPage lastPage hasNextPage }
                    media(season: $season, seasonYear: $year, type: ANIME, sort: POPULARITY_DESC, isAdult: false${statusFilter}) {
                        ${MEDIA_FIELDS}
                    }
                }
            }`,
            status ? { season, year, page, perPage, status } : { season, year, page, perPage },
            cacheKey
        );
        return { ...data.Page, page, perPage };
    }

    private isStillAiring(media: AniListMedia): boolean {
        return media.status === 'RELEASING' || Boolean(media.nextAiringEpisode?.airingAt);
    }

    private async fetchPlanningPage(
        season: AniListSeason,
        year: number,
        page: number,
        includePrevReleasing: boolean
    ): Promise<{
        currentSeasonMedia: AniListMedia[];
        prevReleasingMedia: AniListMedia[];
        hasNextPage: boolean;
    }> {
        const prev = prevSeason(season, year);
        const cacheKey = includePrevReleasing
            ? `planning-page:${season}:${year}:${page}:prev`
            : `planning-page:${season}:${year}:${page}`;

        if (includePrevReleasing) {
            const data = await this.queryPublic<{
                currentSeason: {
                    pageInfo: { hasNextPage: boolean };
                    media: AniListMedia[];
                };
                prevReleasing: { media: AniListMedia[] };
            }>(
                `query ($season: MediaSeason, $year: Int, $prevSeason: MediaSeason, $prevYear: Int, $page: Int) {
                    currentSeason: Page(page: $page, perPage: 50) {
                        pageInfo { hasNextPage lastPage }
                        media(season: $season, seasonYear: $year, type: ANIME, sort: POPULARITY_DESC, isAdult: false) {
                            ${PLANNING_MEDIA_FIELDS}
                        }
                    }
                    prevReleasing: Page(page: 1, perPage: 50) {
                        media(season: $prevSeason, seasonYear: $prevYear, type: ANIME, status: RELEASING, sort: POPULARITY_DESC, isAdult: false) {
                            ${PLANNING_MEDIA_FIELDS}
                        }
                    }
                }`,
                { season, year, prevSeason: prev.season, prevYear: prev.year, page },
                page === 1 ? cacheKey : undefined
            );
            return {
                currentSeasonMedia: data.currentSeason.media,
                prevReleasingMedia: data.prevReleasing.media,
                hasNextPage: data.currentSeason.pageInfo.hasNextPage,
            };
        }

        const data = await this.queryPublic<{
            currentSeason: {
                pageInfo: { hasNextPage: boolean };
                media: AniListMedia[];
            };
        }>(
            `query ($season: MediaSeason, $year: Int, $page: Int) {
                currentSeason: Page(page: $page, perPage: 50) {
                    pageInfo { hasNextPage lastPage }
                    media(season: $season, seasonYear: $year, type: ANIME, sort: POPULARITY_DESC, isAdult: false) {
                        ${PLANNING_MEDIA_FIELDS}
                    }
                }
            }`,
            { season, year, page },
            cacheKey
        );
        return {
            currentSeasonMedia: data.currentSeason.media,
            prevReleasingMedia: [],
            hasNextPage: data.currentSeason.pageInfo.hasNextPage,
        };
    }

    private async fetchPlanningMedia(season: AniListSeason, year: number): Promise<AniListMedia[]> {
        this.resetRequestCount();
        const current = this.getCurrentSeason();
        const isCurrentSeason = season === current.season && year === current.year;

        const byId = new Map<number, AniListMedia>();
        let page = 1;
        let hasNext = true;

        while (hasNext && page <= SEASON_MAX_PAGES) {
            const result = await this.fetchPlanningPage(season, year, page, isCurrentSeason && page === 1);
            for (const m of result.currentSeasonMedia) {
                byId.set(m.id, m);
            }
            if (isCurrentSeason && page === 1) {
                for (const m of result.prevReleasingMedia) {
                    if (this.isStillAiring(m) && !byId.has(m.id)) {
                        byId.set(m.id, m);
                    }
                }
            }
            hasNext = result.hasNextPage;
            page++;
        }

        return Array.from(byId.values());
    }

    async getPlanningMedia(season: AniListSeason, year: number): Promise<AniListMedia[]> {
        const cacheKey = `planning:${season}:${year}`;
        const cached = anilistCache.get<AniListMedia[]>(cacheKey);
        if (cached) {
            this.requestCount = 0;
            return cached;
        }

        const inflight = this.planningInflight.get(cacheKey);
        if (inflight) return inflight;

        const promise = this.fetchPlanningMedia(season, year)
            .then(result => {
                anilistCache.set(cacheKey, result, CACHE_TTL_MS);
                return result;
            })
            .finally(() => {
                this.planningInflight.delete(cacheKey);
            });

        this.planningInflight.set(cacheKey, promise);
        return promise;
    }

    async search(query: string, page = 1, perPage = 25): Promise<AniListPageResult> {
        const cacheKey = `search:${query}:${page}:${perPage}`;
        const data = await this.queryPublic<{ Page: AniListPageResult }>(
            `query ($search: String, $page: Int, $perPage: Int) {
                Page(page: $page, perPage: $perPage) {
                    pageInfo { total currentPage lastPage hasNextPage }
                    media(search: $search, type: ANIME, sort: SEARCH_MATCH, isAdult: false) {
                        ${MEDIA_FIELDS}
                    }
                }
            }`,
            { search: query, page, perPage },
            cacheKey
        );
        return { ...data.Page, page, perPage };
    }

    async getAnime(id: number): Promise<AniListMedia | null> {
        const cacheKey = `anime:${id}`;
        const data = await this.queryPublic<{ Media: AniListMedia | null }>(
            `query ($id: Int) {
                Media(id: $id, type: ANIME) { ${MEDIA_FIELDS} }
            }`,
            { id },
            cacheKey
        );
        return data.Media;
    }
}

export const anilistService = new AniListService();
