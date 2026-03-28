const https = require('https');
const { parse } = require('node-html-parser');

async function fetchHTML(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve(data));
        }).on('error', reject);
    });
}

async function analyzeAnime(animeName) {
    const catalogUrl = `https://anime-sama.to/catalogue/${animeName}/`;
    
    console.log(`\n📚 Analyse de: ${catalogUrl}\n`);
    
    try {
        const html = await fetchHTML(catalogUrl);
        const root = parse(html);
        
        // Chercher les liens de saisons
        const animeSection = html.match(/## ANIME([\s\S]*?)## MANGA/);
        if (animeSection) {
            const links = animeSection[1].match(/\[([^\]]+)\]\(([^)]+)\)/g);
            console.log('🎬 Saisons trouvées:');
            if (links) {
                links.forEach((link, idx) => {
                    const match = link.match(/\[([^\]]+)\]\(([^)]+)\)/);
                    console.log(`  ${idx + 1}. ${match[1]}`);
                    console.log(`     URL: ${match[2]}`);
                });
            }
        }
        
        // Chercher les épisodes
        const episodeSection = html.match(/DERNIER ÉPISODE/);
        console.log('\n📺 Episodes disponibles:', episodeSection ? 'Oui' : 'Non');
        
    } catch (error) {
        console.error('Erreur:', error.message);
    }
}

analyzeAnime('dr-stone');
