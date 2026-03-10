// Test script pour l'API
async function test() {
    try {
        console.log('Testing health...');
        const health = await fetch('http://localhost:3001/api/health');
        console.log('Health status:', health.status);
        const healthData = await health.json();
        console.log('Health:', JSON.stringify(healthData));
        
        console.log('\nTesting /api/animes (this may take ~60s with FlareSolverr)...');
        const animes = await fetch('http://localhost:3001/api/animes');
        console.log('Animes status:', animes.status);
        const animesData = await animes.json();
        console.log('Success:', animesData.success);
        console.log('Count:', animesData.data?.length || 0);
        
        if (animesData.data && animesData.data.length > 0) {
            console.log('\nPremiers animes:');
            animesData.data.slice(0, 10).forEach(a => {
                console.log(`  ${a.dayOfWeek} | ${a.title} | ${a.type} | ${a.time || '?'}`);
            });
        } else if (animesData.error) {
            console.log('Error:', animesData.error);
        }
    } catch (e) {
        console.error('Connection error:', e.message);
    }
}
test();
