import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import animeRoutes from './routes/anime.routes';

const app = express();
const PORT = process.env.API_PORT || 3001;

// Middleware
app.use(cors({
    origin: ['http://localhost:3000', 'http://localhost:5173'],
    credentials: true
}));
app.use(express.json());

// Routes
app.use('/api/animes', animeRoutes);

// Health check
app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Démarrage
app.listen(PORT, () => {
    console.log('========================================');
    console.log(`🚀 API démarrée sur http://localhost:${PORT}`);
    console.log(`📺 Extension du site: ${process.env.SITE_EXTENSION || 'tv'}`);
    console.log('========================================');
    console.log('Routes disponibles:');
    console.log(`  GET  /api/animes         - Tous les animes`);
    console.log(`  GET  /api/animes/today   - Animes du jour`);
    console.log(`  GET  /api/animes/day/:d  - Animes par jour`);
    console.log(`  POST /api/animes/refresh - Rafraîchir le cache`);
    console.log(`  GET  /api/health         - Health check`);
    console.log('========================================');
});
