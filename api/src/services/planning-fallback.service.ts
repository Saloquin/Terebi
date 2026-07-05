import { AniListMedia, AniListSeason } from '../types/anilist.types';
import { AniListApiError, anilistService } from './anilist.service';
import { jikanService } from './jikan.service';
import { kitsuService } from './kitsu.service';

export type PlanningSource = 'anilist' | 'jikan' | 'kitsu';

export interface PlanningResult {
    source: PlanningSource;
    media: AniListMedia[];
    anilistRequests?: number;
}

export function isAnilistPlanningUnavailable(error: unknown): boolean {
    if (error instanceof AniListApiError) {
        if (error.code === 'ANILIST_DISABLED') return true;
        if (error.status === 403) return true;
        if (error.status >= 500) return true;
        return false;
    }
    return true;
}

export async function getPlanningWithFallback(
    season: AniListSeason,
    year: number
): Promise<PlanningResult> {
    anilistService.resetRequestCount();

    try {
        const media = await anilistService.getPlanningMedia(season, year);
        return {
            source: 'anilist',
            media,
            anilistRequests: anilistService.getRequestCount(),
        };
    } catch (error) {
        if (!isAnilistPlanningUnavailable(error)) {
            throw error;
        }

        console.warn(
            `⚠️ AniList indisponible pour le planning (${season} ${year}), fallback Jikan…`,
            error instanceof Error ? error.message : error
        );

        try {
            const media = await jikanService.getSeasonMedia(season, year);
            console.log(`📊 Planning ${season} ${year}: fallback Jikan (${media.length} anime)`);
            return { source: 'jikan', media };
        } catch (jikanError) {
            console.warn('⚠️ Jikan indisponible, fallback Kitsu…', jikanError);
            const media = await kitsuService.getSeasonMedia(season, year);
            console.log(`📊 Planning ${season} ${year}: fallback Kitsu (${media.length} anime)`);
            return { source: 'kitsu', media };
        }
    }
}
