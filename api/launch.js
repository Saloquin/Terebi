// Launcher for the API
process.chdir(__dirname);

process.on('exit', (code) => {
    console.error('Process exiting with code:', code);
    console.error('Stack:', new Error().stack);
});

console.log('CWD:', process.cwd());
console.log('Loading ts-node...');
require('ts-node').register({ project: './tsconfig.json' });
console.log('Loading index.ts...');
try {
    require('./src/index.ts');
    console.log('Module loaded, server should be listening...');
} catch(e) {
    console.error('FATAL ERROR:', e);
    process.exit(1);
}
