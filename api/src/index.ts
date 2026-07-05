import express from 'express';
import cors from 'cors';
import configRoutes from './routes/config.routes';
import anilistRoutes from './routes/anilist.routes';
import samaRoutes from './routes/sama.routes';

const app = express();
const PORT = parseInt(process.env.API_PORT || '3001', 10);

app.use(cors());
app.use(express.json());

app.use('/api/anilist', anilistRoutes);
app.use('/api/sama', samaRoutes);
app.use('/api/config', configRoutes);

app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

const server = app.listen(PORT, () => {
    console.log('========================================');
    console.log(`🚀 API démarrée sur http://localhost:${PORT}`);
    console.log('========================================');
    console.log('Routes:');
    console.log('  POST /api/anilist/auth/url');
    console.log('  POST /api/anilist/auth/token');
    console.log('  GET  /api/anilist/auth/callback (Docker .env OAuth)');
    console.log('  GET  /api/anilist/oauth/status');
    console.log('  GET  /api/anilist/season | search | planning');
    console.log('  GET  /api/anilist/lists (Bearer token)');
    console.log('  PUT  /api/config/extension');
    console.log('  GET  /api/sama/resolve?title=&season=');
    console.log('  GET  /api/health');
    console.log('========================================');
});

server.on('error', (err: NodeJS.ErrnoException) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`❌ Le port ${PORT} est déjà utilisé !`);
    } else {
        console.error('❌ Erreur serveur:', err);
    }
    process.exit(1);
});

process.on('uncaughtException', err => {
    console.error('❌ Uncaught Exception:', err);
});

process.on('unhandledRejection', reason => {
    console.error('❌ Unhandled Rejection:', reason);
});
