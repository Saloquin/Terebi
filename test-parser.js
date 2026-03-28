import axios from 'axios';

async function testParser() {
    try {
        const url = 'https://anime-sama.to/catalogue/dr-stone/';
        const response = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            }
        });

        const html = response.data;

        console.log('🧪 Test du parseur regex\n');
        
        // Chercher tous les liens href avec /dr-stone/
        const linkPattern = /href=['"]\/catalogue\/dr-stone\/([^'"]+)['"]\s*[^>]*>([^<]+)</g;
        let match;
        const links = [];
        
        while ((match = linkPattern.exec(html)) !== null) {
            const path = match[1];
            const text = match[2].trim();
            links.push({ path, text });
        }
        
        console.log(`✅ ${links.length} liens trouvés:\n`);
        links.slice(0, 20).forEach((link, idx) => {
            console.log(`  ${idx+1}. [${link.text}] -> /catalogue/dr-stone/${link.path}`);
        });
        
    } catch (e) {
        console.error('Erreur:', e.message);
    }
}

testParser();
