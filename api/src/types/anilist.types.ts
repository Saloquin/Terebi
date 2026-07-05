export type AniListSeason = 'WINTER' | 'SPRING' | 'SUMMER' | 'FALL';

export interface AniListMediaTitle {
    romaji?: string;
    english?: string;
    native?: string;
}

export interface AniListMedia {
    id: number;
    idMal?: number;
    title: AniListMediaTitle;
    coverImage?: { large?: string; medium?: string };
    bannerImage?: string;
    description?: string;
    format?: string;
    status?: string;
    episodes?: number;
    duration?: number;
    season?: AniListSeason;
    seasonYear?: number;
    genres?: string[];
    averageScore?: number;
    startDate?: { year?: number; month?: number; day?: number };
    nextAiringEpisode?: { airingAt: number; episode: number };
    siteUrl?: string;
    studios?: { nodes: Array<{ name: string }> };
}

export interface AniListPageResult {
    page: number;
    perPage: number;
    pageInfo: {
        total?: number;
        currentPage: number;
        lastPage: number;
        hasNextPage: boolean;
    };
    media: AniListMedia[];
}

export interface SamaResolveResult {
    title: string;
    matchedTitle?: string;
    slug?: string;
    url: string;
    cached: boolean;
}
