import { AniListMedia, AniListSeason } from '../types/anilist.types';
import { anilistCache } from './anilist-cache';

const JIKAN_BASE = 'https://api.jikan.moe/v4';
const CACHE_TTL_MS = 20 * 60 * 1000;
const USER_AGENT = 'Dashboard-sama-scrapper/1.0';

const SEASON_ORDER: AniListSeason[] = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];

const JIKAN_SEASON: Record<AniListSeason, string> = {
    WINTER: 'winter',
    SPRING: 'spring',
    SUMMER: 'summer',
    FALL: 'fall',
};

const JIKAN_DAY_INDEX: Record<string, number> = {
    mondays: 0,
    tuesdays: 1,
    wednesdays: 2,
    thursdays: 3,
    fridays: 4,
    saturdays: 5,
    sundays: 6,
};

interface JikanBroadcast {
    day?: string | null;
    time?: string | null;
    timezone?: string | null;
}

interface JikanAnime {
    mal_id: number;
    url?: string;
    images?: {
        jpg?: { image_url?: string; small_image_url?: string; large_image_url?: string };
        webp?: { image_url?: string; small_image_url?: string; large_image_url?: string };
    };
    title?: string;
    title_english?: string | null;
    title_japanese?: string | null;
    synopsis?: string | null;
    status?: string | null;
    episodes?: number | null;
    score?: number | null;
    broadcast?: JikanBroadcast | null;
    aired?: { from?: string | null; to?: string | null };
    genres?: Array<{ name: string }>;
    season?: string | null;
    year?: number | null;
}

interface JikanSeasonResponse {
    data?: JikanAnime[];
}

function prevSeason(season: AniListSeason, year: number): { season: AniListSeason; year: number } {
    const idx = SEASON_ORDER.indexOf(season);
    if (idx <= 0) return { season: 'FALL', year: year - 1 };
    return { season: SEASON_ORDER[idx - 1], year };
}

function mapJikanStatus(status?: string | null): string | undefined {
    if (!status) return undefined;
    const s = status.toLowerCase();
    if (s.includes('currently airing')) return 'RELEASING';
    if (s.includes('finished')) return 'FINISHED';
    if (s.includes('not yet')) return 'NOT_YET_RELEASED';
    return status.toUpperCase().replace(/\s+/g, '_');
}

function weekdayIndexInTz(date: Date, timeZone: string): number {
    const weekday = new Intl.DateTimeFormat('en-US', { timeZone, weekday: 'short' }).format(date);
    const map: Record<string, number> = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };
    return map[weekday] ?? 0;
}

function ymdInTz(date: Date, timeZone: string): { year: number; month: number; day: number } {
    const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
    }).formatToParts(date);
    return {
        year: parseInt(parts.find(p => p.type === 'year')?.value || '0', 10),
        month: parseInt(parts.find(p => p.type === 'month')?.value || '0', 10),
        day: parseInt(parts.find(p => p.type === 'day')?.value || '0', 10),
    };
}

function unixInTimezone(
    year: number,
    month: number,
    day: number,
    hour: number,
    minute: number,
    timeZone: string
): number {
    const utcGuess = Date.UTC(year, month - 1, day, hour, minute, 0);
    const probe = new Date(utcGuess);
    const utcStr = probe.toLocaleString('en-US', { timeZone: 'UTC' });
    const tzStr = probe.toLocaleString('en-US', { timeZone });
    const offsetMs = new Date(tzStr).getTime() - new Date(utcStr).getTime();
    return Math.floor((utcGuess - offsetMs) / 1000);
}

export function computeNextAiringFromBroadcast(
    broadcast?: JikanBroadcast | null
): { airingAt: number; episode: number } | undefined {
    const day = broadcast?.day?.trim();
    const time = broadcast?.time?.trim();
    if (!day || !time || day.toLowerCase() === 'unknown') return undefined;

    const targetDay = JIKAN_DAY_INDEX[day.toLowerCase()];
    if (targetDay === undefined) return undefined;

    const [hourStr, minuteStr] = time.split(':');
    const hour = parseInt(hourStr, 10);
    const minute = parseInt(minuteStr, 10);
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) return undefined;

    const timeZone = broadcast?.timezone?.trim() || 'Asia/Tokyo';
    const nowSec = Math.floor(Date.now() / 1000);

    for (let offsetDays = 0; offsetDays <= 7; offsetDays++) {
        const probe = new Date(Date.now() + offsetDays * 86400000);
        if (weekdayIndexInTz(probe, timeZone) !== targetDay) continue;

        const { year, month, day: dom } = ymdInTz(probe, timeZone);
        const airingAt = unixInTimezone(year, month, dom, hour, minute, timeZone);
        if (airingAt >= nowSec - 3600) {
            return { airingAt, episode: 0 };
        }
    }

    return undefined;
}

function mapJikanAnime(anime: JikanAnime): AniListMedia {
    const cover =
        anime.images?.webp?.large_image_url ||
        anime.images?.jpg?.large_image_url ||
        anime.images?.webp?.image_url ||
        anime.images?.jpg?.image_url;

    const nextAiring = computeNextAiringFromBroadcast(anime.broadcast);
    const seasonUpper = anime.season?.toUpperCase() as AniListSeason | undefined;

    return {
        id: anime.mal_id,
        idMal: anime.mal_id,
        title: {
            romaji: anime.title || undefined,
            english: anime.title_english || undefined,
            native: anime.title_japanese || undefined,
        },
        coverImage: cover ? { large: cover, medium: cover } : undefined,
        description: anime.synopsis || undefined,
        status: mapJikanStatus(anime.status),
        episodes: anime.episodes ?? undefined,
        averageScore: anime.score != null ? Math.round(anime.score * 10) : undefined,
        season: seasonUpper && SEASON_ORDER.includes(seasonUpper) ? seasonUpper : undefined,
        seasonYear: anime.year ?? undefined,
        genres: anime.genres?.map(g => g.name),
        nextAiringEpisode: nextAiring,
        siteUrl: anime.url || `https://myanimelist.net/anime/${anime.mal_id}`,
    };
}

async function fetchJikanSeason(year: number, season: string): Promise<JikanAnime[]> {
    const cacheKey = `jikan:season:${year}:${season}`;
    const cached = anilistCache.get<JikanAnime[]>(cacheKey);
    if (cached) return cached;

    const url = `${JIKAN_BASE}/seasons/${year}/${season}`;
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT } });
    if (!res.ok) {
        throw new Error(`Jikan API error: ${res.status}`);
    }
    const json = (await res.json()) as JikanSeasonResponse;
    const data = json.data ?? [];
    anilistCache.set(cacheKey, data, CACHE_TTL_MS);
    return data;
}

function isCurrentlyAiring(anime: JikanAnime): boolean {
    return (anime.status || '').toLowerCase().includes('currently airing');
}

export class JikanService {
    async getSeasonMedia(season: AniListSeason, year: number): Promise<AniListMedia[]> {
        const jikanSeason = JIKAN_SEASON[season];
        const cacheKey = `jikan:planning:${season}:${year}`;
        const cached = anilistCache.get<AniListMedia[]>(cacheKey);
        if (cached) return cached;

        const current = getCurrentSeason();
        const isCurrentSeason = season === current.season && year === current.year;

        const currentRaw = await fetchJikanSeason(year, jikanSeason);
        const byMalId = new Map<number, AniListMedia>();

        for (const anime of currentRaw) {
            byMalId.set(anime.mal_id, mapJikanAnime(anime));
        }

        if (isCurrentSeason) {
            const prev = prevSeason(season, year);
            const prevRaw = await fetchJikanSeason(prev.year, JIKAN_SEASON[prev.season]);
            for (const anime of prevRaw) {
                if (isCurrentlyAiring(anime) && !byMalId.has(anime.mal_id)) {
                    byMalId.set(anime.mal_id, mapJikanAnime(anime));
                }
            }
        }

        const result = Array.from(byMalId.values());
        anilistCache.set(cacheKey, result, CACHE_TTL_MS);
        return result;
    }
}

function getCurrentSeason(): { season: AniListSeason; year: number } {
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

export const jikanService = new JikanService();
