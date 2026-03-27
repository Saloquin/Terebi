import { AnimePlanning } from '../types/anime.types';
import { animeScraperService } from './anime-scraper.service';
import { parserService } from './parser.service';

class PlanningService {
    private flareSolverrUrl: string;
    private cache: AnimePlanning[] | null = null;
    private cacheTimestamp: Date | null = null;
    private cacheDuration = 10 * 60 * 1000;

    constructor() {
        this.flareSolverrUrl = process.env.FLARESOLVERR_URL || 'http://localhost:8191/v1';
    }

    private get baseUrl(): string {
        return `https://anime-sama.${animeScraperService.getExtension()}`;
    }

    private isCacheValid(): boolean {
        if (!this.cache || !this.cacheTimestamp) return false;
        return Date.now() - this.cacheTimestamp.getTime() < this.cacheDuration;
    }

    async getPlanning(options?: { forceRefresh?: boolean }): Promise<AnimePlanning[]> {
        const forceRefresh = options?.forceRefresh ?? false;

        if (!forceRefresh && this.isCacheValid() && this.cache) {
            console.log('📦 Utilisation du cache planning');
            return this.cache;
        }

        const url = `${this.baseUrl}/planning/`;
        console.log('🌐 Récupération planning via FlareSolverr...');
        console.log(`📍 URL: ${url}`);

        const response = await fetch(this.flareSolverrUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                cmd: 'request.get',
                url,
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
        const animes = parserService.parsePlanningFromSource(html, url);

        this.cache = animes;
        this.cacheTimestamp = new Date();

        console.log(`✅ ${animes.length} animes récupérés`);
        return animes;
    }

    async getAnimesByDay(day: string): Promise<AnimePlanning[]> {
        const animes = await this.getPlanning();
        return animes.filter(anime => anime.dayOfWeek.toLowerCase() === day.toLowerCase());
    }

    async getTodayAnimes(): Promise<AnimePlanning[]> {
        const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
        const today = dayNames[new Date().getDay()];
        return this.getAnimesByDay(today);
    }

    clearCache(): void {
        this.cache = null;
        this.cacheTimestamp = null;
        console.log('🗑️ Cache planning vidé');
    }
}

export const planningService = new PlanningService();
