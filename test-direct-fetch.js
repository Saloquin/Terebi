import axios from 'axios';

// Test simple sans FlareSolverr
async function testDirectFetch() {
    try {
        console.log('🧪 Test Direct fetch sans FlareSolverr...\n');
        
        const url = 'https://anime-sama.to/catalogue/dr-stone/';
        console.log(`Accès à: ${url}\n`);
        
        const response = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
            timeout: 10000
        });
        
        console.log(`✅ Status: ${response.status}`);
        console.log(`📏 Content length: ${response.data.length}`);
        console.log(`\n📄 Premier 800 caractères:`);
        console.log(response.data.substring(0, 800));
        
    } catch (error) {
        console.error('❌ Erreur:', error.message);
        if (error.response) {
            console.error('Status:', error.response.status);
            console.error('Headers:', error.response.headers);
        }
    }
}

testDirectFetch();
