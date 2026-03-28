import http from 'http';

function testAPI(path) {
    return new Promise((resolve, reject) => {
        http.get(`http://localhost:3001${path}`, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    resolve(JSON.parse(data));
                } catch {
                    resolve(data);
                }
            });
        }).on('error', reject);
    });
}

(async () => {
    console.log('🧪 Test API Saisons\n');
    
    try {
        console.log('Test 1: /api/animes/seasons/dr-stone');
        const res = await testAPI('/api/animes/seasons/dr-stone');
        console.log(JSON.stringify(res, null, 2));
    } catch (e) {
        console.error('❌', e.message);
    }
})();
