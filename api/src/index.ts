import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import animeRoutes from './routes/anime.routes';
import configRoutes from './routes/config.routes';

const app = express();
const PORT = parseInt(process.env.API_PORT || '3001', 10);

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/animes', animeRoutes);
app.use('/api/config', configRoutes);

// Health check
app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Démarrage
const server = app.listen(PORT, () => {
    console.log('========================================');
    console.log(`🚀 API démarrée sur http://localhost:${PORT}`);
    console.log(`📺 Extension du site: ${process.env.SITE_EXTENSION || 'tv'}`);
    console.log('========================================');
    console.log('Routes disponibles:');
    console.log(`  GET  /api/animes         - Tous les animes`);
    console.log(`  GET  /api/animes/today   - Animes du jour`);
    console.log(`  GET  /api/animes/day/:d  - Animes par jour`);
    console.log(`  POST /api/animes/refresh - Rafraîchir le cache`);
    console.log(`  GET  /api/config         - Config actuelle`);
    console.log(`  PUT  /api/config         - Changer l'extension`);
    console.log(`  GET  /api/health         - Health check`);
    console.log('========================================');
});

server.on('error', (err: any) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`❌ Le port ${PORT} est déjà utilisé !`);
    } else {
        console.error('❌ Erreur serveur:', err);
    }
    process.exit(1);
});

process.on('uncaughtException', (err) => {
    console.error('❌ Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason) => {
    console.error('❌ Unhandled Rejection:', reason);
});
