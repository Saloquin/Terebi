import { Router, Request, Response } from 'express';
import { planningService } from '../services/planning.service';
import { catalogService } from '../services/catalog.service';
import { ApiResponse, AnimePlanning, CatalogResult } from '../types/anime.types';

const router = Router();

// GET /api/animes - Récupérer tous les animes
router.get('/', async (_req: Request, res: Response) => {
    try {
        const animes = await planningService.getPlanning();
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
        const animes = await planningService.getTodayAnimes();
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
        const animes = await planningService.getAnimesByDay(req.params.day);
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
        planningService.clearCache();
        const animes = await planningService.getPlanning({ forceRefresh: true });
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

// GET /api/animes/catalogue?search=query&page=1 - Recherche catalogue
router.get('/catalogue', async (req: Request, res: Response) => {
    try {
        const search = typeof req.query.search === 'string' ? req.query.search : '';
        const pageParam = typeof req.query.page === 'string' ? Number(req.query.page) : 1;
        const page = Number.isFinite(pageParam) ? pageParam : 1;

        const result = await catalogService.search(search, page);
        const response: ApiResponse<CatalogResult> = {
            success: true,
            data: result,
            timestamp: new Date().toISOString(),
        };

        res.json(response);
    } catch (error) {
        const response: ApiResponse<null> = {
            success: false,
            data: null,
            error: error instanceof Error ? error.message : 'Erreur inconnue',
            timestamp: new Date().toISOString(),
        };
        res.status(500).json(response);
    }
});

export default router;
