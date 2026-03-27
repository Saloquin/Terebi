import { CatalogResult } from '../types/anime.types';
import { animeScraperService } from './anime-scraper.service';
import { parserService } from './parser.service';

class CatalogService {
    private flareSolverrUrl: string;

    constructor() {
        this.flareSolverrUrl = process.env.FLARESOLVERR_URL || 'http://localhost:8191/v1';
    }

    private get baseUrl(): string {
        return `https://anime-sama.${animeScraperService.getExtension()}`;
    }

    async search(search: string = '', page: number = 1): Promise<CatalogResult> {
        const normalizedSearch = (search || '').trim();
        const normalizedPage = Number.isFinite(page) && page > 0 ? Math.floor(page) : 1;

        // Build URL with type and langue filters for Anime VOSTFR only
        let sourceUrl: string;
        
        if (normalizedSearch) {
            sourceUrl = `${this.baseUrl}/catalogue/?type%5B%5D=Anime&langue%5B%5D=VOSTFR&search=${encodeURIComponent(normalizedSearch)}&page=${normalizedPage}`;
        } else {
            sourceUrl = `${this.baseUrl}/catalogue/?type%5B%5D=Anime&langue%5B%5D=VOSTFR&page=${normalizedPage}`;
        }

        console.log(`🔎 Recherche catalogue: ${sourceUrl}`);

        const response = await fetch(this.flareSolverrUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                cmd: 'request.get',
                url: sourceUrl,
                maxTimeout: 60000,
            }),
        });

        if (!response.ok) {
            throw new Error(`FlareSolverr HTTP error: ${response.status}`);
        }

        const data = await response.json() as any;
        if (data.status !== 'ok') {
            throw new Error(`FlareSolverr error: ${data.message || 'Unknown error'}`);
        }

        const html = data.solution.response as string;
        const items = parserService.parseCatalogFromSource(html, sourceUrl);

        return {
            search: normalizedSearch,
            page: normalizedPage,
            sourceUrl,
            items,
        };
    }
}

export const catalogService = new CatalogService();
