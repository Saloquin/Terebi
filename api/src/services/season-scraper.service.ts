const axios = require('axios');

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

/**
 * Scrape l'information des saisons d'un anime depuis sa page catalogue
 * Extrait les données du script JavaScript panneauAnime()
 */
async function scrapeAnimeSeasons(animeSlug: string): Promise<AnimeInfo> {
    const animeUrl = `https://anime-sama.to/catalogue/${animeSlug}/`;
    
    try {
        console.log(`🔍 Scraping ${animeUrl}...`);
        
        // Récupérer le HTML
        const response = await axios.get(animeUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Referer': 'https://anime-sama.to/',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'fr-FR,fr;q=0.9',
                'Cache-Control': 'no-cache',
            },
            timeout: 15000,
        });

        const html = response.data;
        const seasons: Season[] = [];

        // Pattern: panneauAnime("Saison 1", "saison1/vostfr");
        // ou panneauAnime("OAV", "oav/vostfr");
        const panneauPattern = /panneauAnime\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*\)/g;
        let match;
        
        while ((match = panneauPattern.exec(html)) !== null) {
            const seasonName = match[1];
            const seasonPath = match[2];
            
            // Ignorer les entrées "exemple" dans les commentaires
            if (seasonName.toLowerCase() === 'nom' || seasonPath.toLowerCase() === 'url') {
                continue;
            }
            
            // Classifier le type de saison
            let type: 'regular' | 'oav' | 'special' | 'film' = 'regular';
            if (seasonName.toLowerCase().includes('oav') || seasonName.toLowerCase().includes('ova')) {
                type = 'oav';
            } else if (seasonName.toLowerCase().includes('film')) {
                type = 'film';
            } else if (seasonName.toLowerCase().includes('special')) {
                type = 'special';
            }
            
            // Ignorer les mangasscan/scans
            if (!seasonPath.includes('scan')) {
                seasons.push({
                    name: seasonName,
                    url: `https://anime-sama.to/catalogue/${animeSlug}/${seasonPath}`,
                    type,
                });
            }
        }

        const info: AnimeInfo = {
            title: animeSlug.replace(/-/g, ' ').toUpperCase(),
            slug: animeSlug,
            seasons,
            totalSeasons: seasons.filter(s => s.type === 'regular').length,
        };

        console.log(`✅ ${info.totalSeasons} saisons trouvées pour ${info.title}`);
        if (seasons.length > 0) {
            console.log(`   - Saisons: ${seasons.map(s => `${s.name}(${s.type})`).join(', ')}`);
        }
        return info;

    } catch (error: any) {
        console.error(`❌ Erreur scraping ${animeSlug}:`, error.message);
        throw error;
    }
}

/**
 * Scrape les épisodes d'une saison spécifique
 * Note: Les épisodes sont générés dynamiquement côté client, impossible à scraper
 */
async function scrapeSeasonEpisodes(seasonUrl: string): Promise<number> {
    try {
        console.log(`📺 Scraping episodes de ${seasonUrl}... (non disponible)`);
        // Les épisodes sont chargés via JavaScript côté client, impossible à scraper
        return 0;
    } catch (error: any) {
        console.error(`⚠️  Scraping épisodes non disponible:`, error.message);
        return 0;
    }
}

// Export pour utilisation dans le service
export { scrapeAnimeSeasons, scrapeSeasonEpisodes, AnimeInfo, Season };
