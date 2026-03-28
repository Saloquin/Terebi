import axios from 'axios';

async function analyzeHTML() {
    try {
        const url = 'https://anime-sama.to/catalogue/dr-stone/';
        const response = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            }
        });

        const html = response.data;
        
        // Chercher les liens href vers les saisons
        console.log('🔍 Recherche de liens vers saisons...\n');
        
        // Pattern: /catalogue/dr-stone/saison*/
        const seasonPattern = /href=['"]\/catalogue\/dr-stone\/([^'"]+)\/['"]/g;
        let match;
        const seasons = [];
        
        while ((match = seasonPattern.exec(html)) !== null) {
            seasons.push(match[1]);
        }
        
        if (seasons.length > 0) {
            console.log(`✅ ${seasons.length} liens trouvés:\n`);
            // Unique seulement
            const unique = [...new Set(seasons)];
            unique.forEach(s => console.log(`  - /catalogue/dr-stone/${s}/`));
        } else {
            console.log('❌ Aucun lien trouvé');
        }
        
        // Chercher aussi le texte "Saison"
        console.log('\n🔍 Recherche de texte "Saison" dans le HTML...\n');
        const saisonMatches = html.match(/>Saison\s*\d+[<]/g);
        if (saisonMatches) {
            console.log(`✅ ${saisonMatches.length} mentions trouvées:`);
            saisonMatches.slice(0, 10).forEach(s => console.log(`  - ${s}`));
        }
        
    } catch (e) {
        console.error('Erreur:', e.message);
    }
}

analyzeHTML();
