import { SamaResolveResult } from '../types/anilist.types';
import { animeCatalogService } from './anime-catalog.service';
import { scrapeAnimeSeasons } from './season-scraper.service';

const normalize = (s: string): string =>
    s
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[^a-z0-9\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

const fuzzyScore = (query: string, candidate: string): number => {
    const q = normalize(query);
    const c = normalize(candidate);
    if (!q || !c) return 0;
    if (c === q) return 100;
    if (c.includes(q) || q.includes(c)) return 80;
    const qTokens = q.split(' ');
    const cTokens = new Set(c.split(' '));
    const matched = qTokens.filter(t => cTokens.has(t)).length;
    return Math.round((matched / qTokens.length) * 70);
};

class SamaResolveService {
    async resolveCatalog(title: string): Promise<SamaResolveResult> {
        const result = await animeCatalogService.search(title, 1);
        if (!result.items.length) {
            throw new Error(`Aucun résultat anime-sama pour "${title}"`);
        }

        let best = result.items[0];
        let bestScore = fuzzyScore(title, best.title);
        for (const item of result.items.slice(1, 10)) {
            const score = fuzzyScore(title, item.title);
            if (score > bestScore) {
                bestScore = score;
                best = item;
            }
        }

        const slugMatch = best.fullUrl.match(/\/catalogue\/([^/]+)/);
        const slug = slugMatch?.[1] || best.url.replace(/\/$/, '').split('/').pop() || '';

        return {
            title,
            matchedTitle: best.title,
            slug,
            url: best.fullUrl,
            cached: false,
        };
    }

    async resolveSeason(title: string, seasonNumber: number): Promise<SamaResolveResult> {
        const catalog = await this.resolveCatalog(title);
        if (!catalog.slug) {
            throw new Error(`Impossible de résoudre le slug pour "${title}"`);
        }

        const animeInfo = await scrapeAnimeSeasons(catalog.slug);
        const regularSeasons = animeInfo.seasons.filter(s => s.type === 'regular');

        let seasonUrl: string | undefined;
        if (seasonNumber <= regularSeasons.length) {
            seasonUrl = regularSeasons[seasonNumber - 1]?.url;
        }

        if (!seasonUrl) {
            const byName = animeInfo.seasons.find(s => {
                const numMatch = s.name.match(/(\d+)/);
                return numMatch && parseInt(numMatch[1], 10) === seasonNumber;
            });
            seasonUrl = byName?.url;
        }

        if (!seasonUrl && regularSeasons.length === 1) {
            seasonUrl = regularSeasons[0].url;
        }

        if (!seasonUrl) {
            throw new Error(`Saison ${seasonNumber} introuvable pour "${title}"`);
        }

        return {
            title,
            matchedTitle: catalog.matchedTitle,
            slug: catalog.slug,
            url: seasonUrl,
            cached: false,
        };
    }
}

export const samaResolveService = new SamaResolveService();
