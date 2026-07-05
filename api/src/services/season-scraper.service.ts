import { animeScraperService } from './anime-scraper.service';

interface Season {
    name: string;
    url: string;
    type: 'regular' | 'oav' | 'special' | 'film';
}

interface AnimeInfo {
    title: string;
    slug: string;
    seasons: Season[];
    totalSeasons: number;
}

class SeasonScraperService {
    private flareSolverrUrl: string;

    constructor() {
        this.flareSolverrUrl = process.env.FLARESOLVERR_URL || 'http://localhost:8191/v1';
    }

    private get baseUrl(): string {
        return `https://anime-sama.${animeScraperService.getExtension()}`;
    }

    private async fetchHtml(url: string): Promise<string> {
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

        const data = await response.json() as { status: string; message?: string; solution?: { response: string } };
        if (data.status !== 'ok') {
            throw new Error(`FlareSolverr error: ${data.message || 'Unknown error'}`);
        }

        return data.solution?.response || '';
    }

    private parseSeasonsFromHtml(html: string, animeSlug: string): Season[] {
        const seasons: Season[] = [];
        const panneauPattern = /panneauAnime\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*\)/g;
        let match;

        while ((match = panneauPattern.exec(html)) !== null) {
            const seasonName = match[1];
            const seasonPath = match[2];

            if (seasonName.toLowerCase() === 'nom' || seasonPath.toLowerCase() === 'url') {
                continue;
            }

            let type: Season['type'] = 'regular';
            const nameLower = seasonName.toLowerCase();
            if (nameLower.includes('oav') || nameLower.includes('ova')) {
                type = 'oav';
            } else if (nameLower.includes('film')) {
                type = 'film';
            } else if (nameLower.includes('special')) {
                type = 'special';
            }

            if (!seasonPath.includes('scan')) {
                seasons.push({
                    name: seasonName,
                    url: `${this.baseUrl}/catalogue/${animeSlug}/${seasonPath}`,
                    type,
                });
            }
        }

        return seasons;
    }

    async scrapeAnimeSeasons(animeSlug: string): Promise<AnimeInfo> {
        const animeUrl = `${this.baseUrl}/catalogue/${animeSlug}/`;

        console.log(`🔍 Scraping seasons via FlareSolverr: ${animeUrl}...`);

        const html = await this.fetchHtml(animeUrl);
        const seasons = this.parseSeasonsFromHtml(html, animeSlug);

        const titleMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
        const title = titleMatch?.[1]?.trim() || animeSlug.replace(/-/g, ' ');

        const info: AnimeInfo = {
            title,
            slug: animeSlug,
            seasons,
            totalSeasons: seasons.filter(s => s.type === 'regular').length,
        };

        console.log(`✅ ${info.totalSeasons} saisons trouvées pour ${info.title}`);
        return info;
    }

    async scrapeSeasonEpisodes(seasonUrl: string): Promise<number> {
        console.log(`📺 Scraping episodes via FlareSolverr: ${seasonUrl}...`);

        const html = await this.fetchHtml(seasonUrl);

        const episodeConstructorMatches = html.match(/new\s+Episode\s*\(/g);
        if (episodeConstructorMatches) {
            return episodeConstructorMatches.length;
        }

        const episodeLinkMatches = html.match(/panneauAnime\s*\(\s*["'][^"']*["']\s*,\s*["'][^"']*["']\s*\)/g);
        if (episodeLinkMatches && episodeLinkMatches.length > 1) {
            return episodeLinkMatches.length;
        }

        const epNumberMatches = html.match(/(?:episode|ep\.?)\s*(\d+)/gi);
        if (epNumberMatches) {
            const numbers = epNumberMatches
                .map(m => parseInt(m.replace(/\D/g, ''), 10))
                .filter(n => !Number.isNaN(n) && n > 0);
            return numbers.length > 0 ? Math.max(...numbers) : 0;
        }

        return 0;
    }
}

const seasonScraperService = new SeasonScraperService();

async function scrapeAnimeSeasons(animeSlug: string): Promise<AnimeInfo> {
    return seasonScraperService.scrapeAnimeSeasons(animeSlug);
}

async function scrapeSeasonEpisodes(seasonUrl: string): Promise<number> {
    return seasonScraperService.scrapeSeasonEpisodes(seasonUrl);
}

export { scrapeAnimeSeasons, scrapeSeasonEpisodes, AnimeInfo, Season };
