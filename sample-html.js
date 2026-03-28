import axios from 'axios';

async function sampleHTML() {
    try {
        const url = 'https://anime-sama.to/catalogue/dr-stone/';
        const response = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            }
        });

        const html = response.data;
        console.log('📊 HTML Stats:');
        console.log(`  - Total length: ${html.length} chars`);
        console.log(`  - Contains "Saison": ${html.includes('Saison')}`);
        console.log(`  - Contains "saison": ${html.includes('saison')}`);
        console.log(`  - Contains "ANIME": ${html.includes('ANIME')}`);
        console.log(`  - Contains "</a>": ${(html.match(/<\/a>/g) || []).length} anchors`);
        
        // Chercher du contenu autour de "Saison"
        const saisonIndex = html.indexOf('Saison');
        if (saisonIndex > -1) {
            console.log(`\n🎯 Contexte autour de "Saison":\n`);
            console.log(html.substring(Math.max(0, saisonIndex - 200), saisonIndex + 500));
        }
        
    } catch (e) {
        console.error('Erreur:', e.message);
    }
}

sampleHTML();
