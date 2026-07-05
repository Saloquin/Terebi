import { AniListMedia, AniListPageResult, AniListSeason } from '../types/anilist.types';

const ANILIST_URL = 'https://graphql.anilist.co';

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

class AniListService {
    private async query<T>(query: string, variables: Record<string, unknown>): Promise<T> {
        const response = await fetch(ANILIST_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
            body: JSON.stringify({ query, variables }),
        });

        if (!response.ok) {
            throw new Error(`AniList API error: ${response.status}`);
        }

        const json = (await response.json()) as { data?: T; errors?: Array<{ message: string }> };
        if (json.errors?.length) {
            throw new Error(json.errors.map(e => e.message).join(', '));
        }
        if (!json.data) {
            throw new Error('AniList API returned no data');
        }
        return json.data;
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
        perPage = 50
    ): Promise<AniListPageResult> {
        const data = await this.query<{ Page: AniListPageResult }>(
            `query ($season: MediaSeason, $year: Int, $page: Int, $perPage: Int) {
                Page(page: $page, perPage: $perPage) {
                    pageInfo { total currentPage lastPage hasNextPage }
                    media(season: $season, seasonYear: $year, type: ANIME, sort: POPULARITY_DESC, isAdult: false) {
                        ${MEDIA_FIELDS}
                    }
                }
            }`,
            { season, year, page, perPage }
        );
        return {
            ...data.Page,
            page,
            perPage,
        };
    }

    async search(query: string, page = 1, perPage = 25): Promise<AniListPageResult> {
        const data = await this.query<{ Page: AniListPageResult }>(
            `query ($search: String, $page: Int, $perPage: Int) {
                Page(page: $page, perPage: $perPage) {
                    pageInfo { total currentPage lastPage hasNextPage }
                    media(search: $search, type: ANIME, sort: SEARCH_MATCH, isAdult: false) {
                        ${MEDIA_FIELDS}
                    }
                }
            }`,
            { search: query, page, perPage }
        );
        return {
            ...data.Page,
            page,
            perPage,
        };
    }

    async getAnime(id: number): Promise<AniListMedia | null> {
        const data = await this.query<{ Media: AniListMedia | null }>(
            `query ($id: Int) {
                Media(id: $id, type: ANIME) {
                    ${MEDIA_FIELDS}
                }
            }`,
            { id }
        );
        return data.Media;
    }
}

export const anilistService = new AniListService();
