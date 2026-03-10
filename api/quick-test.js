// Quick test - run in a separate process
const http = require('http');
const req = http.get('http://localhost:3001/api/health', (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
        console.log('Status:', res.statusCode);
        console.log('Body:', data);
    });
});
req.on('error', (e) => console.error('Error:', e.message));
req.setTimeout(5000, () => { console.log('Timeout!'); req.destroy(); });
