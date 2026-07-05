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
        const seenUrls = new Set<string>(); // Track unique URLs to avoid duplicates

        // Remove all JavaScript comments (/* ... */) and line comments (// ...)
        let cleanHtml = html.replace(/\/\*[\s\S]*?\*\//g, ''); // Remove /* */ comments
        cleanHtml = cleanHtml.replace(/\/\/.*$/gm, ''); // Remove // comments

        // First try: Look for panneauAnime calls
        const panneauPattern = /panneauAnime\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']\s*\)/g;
        let match;
        let foundViapanneau = false;
        
        while ((match = panneauPattern.exec(cleanHtml)) !== null) {
            foundViapanneau = true;
            const seasonName = match[1];
            const seasonPath = match[2];
            
            // Ignorer les entrées "exemple" dans les commentaires
            if (seasonName.toLowerCase() === 'nom' || seasonPath.toLowerCase() === 'url') {
                continue;
            }
            
            // Skip if we've already seen this URL
            if (seenUrls.has(seasonPath)) {
                continue;
            }
            seenUrls.add(seasonPath);
            
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

        // Second try: If panneauAnime didn't work, look for direct season links
        if (!foundViapanneau || seasons.length === 0) {
            console.log(`⚠️  panneauAnime pattern failed, trying direct link pattern...`);
            
            // Look for patterns like /catalogue/slug/saison1/vostfr or /catalogue/slug/saison2/vostfr etc.
            const linkPattern = new RegExp(`/catalogue/${animeSlug}/(saison\\d+|film|oav|special)(?:/vostfr)?`, 'gi');
            let linkMatch;
            
            while ((linkMatch = linkPattern.exec(cleanHtml)) !== null) {
                const fullPath = linkMatch[0];
                const seasonPath = linkMatch[1].toLowerCase();
                
                if (seenUrls.has(fullPath)) {
                    continue;
                }
                seenUrls.add(fullPath);
                
                // Extract season number or type
                let seasonName = '';
                let type: 'regular' | 'oav' | 'special' | 'film' = 'regular';
                
                if (seasonPath.startsWith('saison')) {
                    const num = seasonPath.match(/\d+/)?.[0];
                    seasonName = `Saison ${num}`;
                    type = 'regular';
                } else if (seasonPath === 'film') {
                    seasonName = 'Film';
                    type = 'film';
                } else if (seasonPath === 'oav' || seasonPath === 'ova') {
                    seasonName = 'OAV';
                    type = 'oav';
                } else if (seasonPath === 'special') {
                    seasonName = 'Spécial';
                    type = 'special';
                }
                
                if (seasonName) {
                    seasons.push({
                        name: seasonName,
                        url: `https://anime-sama.to${fullPath}/vostfr`,
                        type,
                    });
                }
            }
        }

        // Sort by season number for regular seasons
        seasons.sort((a, b) => {
            if (a.type === b.type && a.type === 'regular') {
                const aNum = parseInt(a.name.match(/\d+/)?.[0] || '0');
                const bNum = parseInt(b.name.match(/\d+/)?.[0] || '0');
                return aNum - bNum;
            }
            return 0;
        });

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
