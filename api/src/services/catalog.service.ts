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

    async search(search: string = '', page: number = 1, type: string = 'all'): Promise<CatalogResult> {
        const normalizedSearch = (search || '').trim();
        const normalizedPage = Number.isFinite(page) && page > 0 ? Math.floor(page) : 1;

        let allItems: any[] = [];
        let pagination = parserService.parseCatalogPagination('', normalizedPage, 0);

        // Helper function to fetch from anime-sama with specific type filter
        const fetchWithType = async (typeFilter: string, typeLabel: string) => {
            let sourceUrl: string;
            
            if (normalizedSearch) {
                sourceUrl = `${this.baseUrl}/catalogue/?${typeFilter}&langue%5B%5D=VOSTFR&search=${encodeURIComponent(normalizedSearch)}&page=${normalizedPage}`;
            } else {
                sourceUrl = `${this.baseUrl}/catalogue/?${typeFilter}&langue%5B%5D=VOSTFR&page=${normalizedPage}`;
            }

            console.log(`🔎 Recherche catalogue (${typeLabel}): ${sourceUrl}`);

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
            const pageInfo = parserService.parseCatalogPagination(html, normalizedPage, items.length);
            pagination = {
                totalPages: Math.max(pagination.totalPages, pageInfo.totalPages),
                hasNextPage: pagination.hasNextPage || pageInfo.hasNextPage,
            };
            
            console.log(`✅ Fetched ${typeLabel}: found ${items.length} items`);
            if (items.length > 0) {
                const animeCount = items.filter(i => i.type === 'Anime').length;
                const filmCount = items.filter(i => i.type === 'Film').length;
                console.log(`  Breakdown: Anime=${animeCount}, Film=${filmCount}`);
                console.log(`  First 3: ${items.slice(0, 3).map(i => `"${i.title}"(${i.type})`).join(', ')}`);
            }
            
            return items;
        };

        // Fetch the appropriate types
        if (type === 'anime') {
            allItems = await fetchWithType('type%5B%5D=Anime', 'Anime');
        } else if (type === 'film') {
            allItems = await fetchWithType('type%5B%5D=Film', 'Film');
        } else {
            // For 'all', fetch both separately
            const animes = await fetchWithType('type%5B%5D=Anime', 'Anime');
            const films = await fetchWithType('type%5B%5D=Film', 'Film');
            allItems = [...animes, ...films];
        }

        return {
            search: normalizedSearch,
            page: normalizedPage,
            totalPages: pagination.totalPages,
            hasNextPage: pagination.hasNextPage,
            sourceUrl: `${this.baseUrl}/catalogue/`,
            items: allItems,
        };
    }
}

export const catalogService = new CatalogService();
