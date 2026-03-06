import { Router, Request, Response } from 'express';
import { animeScraperService } from '../services/anime-scraper.service';
import { ApiResponse, AnimePlanning } from '../types/anime.types';

const router = Router();

// GET /api/animes - Récupérer tous les animes
router.get('/', async (_req: Request, res: Response) => {
    try {
        const animes = await animeScraperService.fetchPlanning();
        const response: ApiResponse<AnimePlanning[]> = {
            success: true,
            data: animes,
            timestamp: new Date().toISOString()
        };
        res.json(response);
    } catch (error) {
        const response: ApiResponse<null> = {
            success: false,
            data: null,
            error: error instanceof Error ? error.message : 'Erreur inconnue',
            timestamp: new Date().toISOString()
        };
        res.status(500).json(response);
    }
});

// GET /api/animes/today - Animes d'aujourd'hui
router.get('/today', async (_req: Request, res: Response) => {
    try {
        await animeScraperService.fetchPlanning();
        const animes = animeScraperService.getTodayAnimes();
        const response: ApiResponse<AnimePlanning[]> = {
            success: true,
            data: animes,
            timestamp: new Date().toISOString()
        };
        res.json(response);
    } catch (error) {
        const response: ApiResponse<null> = {
            success: false,
            data: null,
            error: error instanceof Error ? error.message : 'Erreur inconnue',
            timestamp: new Date().toISOString()
        };
        res.status(500).json(response);
    }
});

// GET /api/animes/day/:day - Animes d'un jour spécifique
router.get('/day/:day', async (req: Request, res: Response) => {
    try {
        await animeScraperService.fetchPlanning();
        const animes = animeScraperService.getAnimesByDay(req.params.day);
        const response: ApiResponse<AnimePlanning[]> = {
            success: true,
            data: animes,
            timestamp: new Date().toISOString()
        };
        res.json(response);
    } catch (error) {
        const response: ApiResponse<null> = {
            success: false,
            data: null,
            error: error instanceof Error ? error.message : 'Erreur inconnue',
            timestamp: new Date().toISOString()
        };
        res.status(500).json(response);
    }
});

// POST /api/animes/refresh - Forcer le rafraîchissement du cache
router.post('/refresh', async (_req: Request, res: Response) => {
    try {
        animeScraperService.clearCache();
        const animes = await animeScraperService.fetchPlanning();
        const response: ApiResponse<AnimePlanning[]> = {
            success: true,
            data: animes,
            timestamp: new Date().toISOString()
        };
        res.json(response);
    } catch (error) {
        const response: ApiResponse<null> = {
            success: false,
            data: null,
            error: error instanceof Error ? error.message : 'Erreur inconnue',
            timestamp: new Date().toISOString()
        };
        res.status(500).json(response);
    }
});

export default router;
