import { AniListMedia, AniListSeason } from '../types/anilist.types';
import { anilistCache } from './anilist-cache';

const KITSU_BASE = 'https://kitsu.io/api/edge';
const CACHE_TTL_MS = 20 * 60 * 1000;
const USER_AGENT = 'Dashboard-sama-scrapper/1.0';

const SEASON_ORDER: AniListSeason[] = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];

const KITSU_SEASON: Record<AniListSeason, string> = {
    WINTER: 'winter',
    SPRING: 'spring',
    SUMMER: 'summer',
    FALL: 'fall',
};

interface KitsuAnimeAttributes {
    canonicalTitle?: string;
    titles?: { en_us?: string; en_jp?: string; ja_jp?: string };
    posterImage?: { large?: string; medium?: string; small?: string };
    synopsis?: string;
    status?: string;
    episodeCount?: number | null;
    averageRating?: string | null;
    startDate?: string | null;
    youtubeVideoId?: string | null;
}

interface KitsuAnime {
    id: string;
    attributes: KitsuAnimeAttributes;
}

interface KitsuResponse {
    data?: KitsuAnime[];
}

function prevSeason(season: AniListSeason, year: number): { season: AniListSeason; year: number } {
    const idx = SEASON_ORDER.indexOf(season);
    if (idx <= 0) return { season: 'FALL', year: year - 1 };
    return { season: SEASON_ORDER[idx - 1], year };
}

function mapKitsuStatus(status?: string): string | undefined {
    if (!status) return undefined;
    const map: Record<string, string> = {
        current: 'RELEASING',
        finished: 'FINISHED',
        upcoming: 'NOT_YET_RELEASED',
        unreleased: 'NOT_YET_RELEASED',
        tba: 'NOT_YET_RELEASED',
    };
    return map[status] || status.toUpperCase();
}

function mapKitsuAnime(anime: KitsuAnime): AniListMedia {
    const attrs = anime.attributes;
    const malId = parseInt(anime.id, 10);
    const poster = attrs.posterImage?.large || attrs.posterImage?.medium;
    const rating = attrs.averageRating ? parseFloat(attrs.averageRating) : undefined;

    return {
        id: malId,
        title: {
            romaji: attrs.titles?.en_jp || attrs.canonicalTitle,
            english: attrs.titles?.en_us || attrs.canonicalTitle,
            native: attrs.titles?.ja_jp,
        },
        coverImage: poster ? { large: poster, medium: poster } : undefined,
        description: attrs.synopsis,
        status: mapKitsuStatus(attrs.status),
        episodes: attrs.episodeCount ?? undefined,
        averageScore: rating != null ? Math.round(rating * 10) : undefined,
        siteUrl: `https://kitsu.io/anime/${anime.id}`,
    };
}

async function fetchKitsuSeason(season: AniListSeason, year: number, status?: string): Promise<KitsuAnime[]> {
    const statusKey = status ? `:status:${status}` : '';
    const cacheKey = `kitsu:season:${season}:${year}${statusKey}`;
    const cached = anilistCache.get<KitsuAnime[]>(cacheKey);
    if (cached) return cached;

    const params = new URLSearchParams({
        'filter[season]': KITSU_SEASON[season],
        'filter[seasonYear]': String(year),
        'page[limit]': '500',
    });
    if (status) params.set('filter[status]', status);

    const url = `${KITSU_BASE}/anime?${params}`;
    const res = await fetch(url, { headers: { Accept: 'application/vnd.api+json', 'User-Agent': USER_AGENT } });
    if (!res.ok) {
        throw new Error(`Kitsu API error: ${res.status}`);
    }
    const json = (await res.json()) as KitsuResponse;
    const data = json.data ?? [];
    anilistCache.set(cacheKey, data, CACHE_TTL_MS);
    return data;
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

export class KitsuService {
    async getSeasonMedia(season: AniListSeason, year: number): Promise<AniListMedia[]> {
        const cacheKey = `kitsu:planning:${season}:${year}`;
        const cached = anilistCache.get<AniListMedia[]>(cacheKey);
        if (cached) return cached;

        const current = getCurrentSeason();
        const isCurrentSeason = season === current.season && year === current.year;

        const currentRaw = await fetchKitsuSeason(season, year);
        const byId = new Map<number, AniListMedia>();

        for (const anime of currentRaw) {
            const mapped = mapKitsuAnime(anime);
            byId.set(mapped.id, mapped);
        }

        if (isCurrentSeason) {
            const prev = prevSeason(season, year);
            const prevRaw = await fetchKitsuSeason(prev.season, prev.year, 'current');
            for (const anime of prevRaw) {
                const mapped = mapKitsuAnime(anime);
                if (!byId.has(mapped.id)) {
                    byId.set(mapped.id, mapped);
                }
            }
        }

        const result = Array.from(byId.values());
        anilistCache.set(cacheKey, result, CACHE_TTL_MS);
        return result;
    }
}

export const kitsuService = new KitsuService();
