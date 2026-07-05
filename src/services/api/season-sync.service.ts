import { extractCatalogSlug } from '../../utils/anime.utils';
import { markAsToWatch, isInToWatch } from '../../utils/tabLogic/towatch.logic';
import { AnimeViewed } from '../../types/anime.types';

/**
 * Compare API seasons with locally viewed seasons and auto-add to towatch when new seasons appear.
 */
export async function syncNewSeasonsToWatch(viewed: AnimeViewed[]): Promise<number> {
    let added = 0;

    for (const anime of viewed) {
        const slug = extractCatalogSlug(anime.fullUrl || anime.url);
        if (!slug) continue;

        const viewedSeasons = anime.viewedSeasons || [];
        if (viewedSeasons.length === 0) continue;

        try {
            const response = await fetch(`/api/animes/seasons/${slug}`);
            if (!response.ok) continue;

            const json = await response.json();
            if (!json.success || !json.data?.seasons?.length) continue;

            const apiSeasonNames: string[] = json.data.seasons.map((s: { name: string }) => s.name);
            const hasNewSeasons = apiSeasonNames.some(name => !viewedSeasons.includes(name));

            if (hasNewSeasons && !isInToWatch(anime.title)) {
                markAsToWatch(anime);
                added++;
            }
        } catch {
            // Skip failed season fetches silently
        }
    }

    return added;
}
