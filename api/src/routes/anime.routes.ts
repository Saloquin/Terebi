import { Router, Request, Response } from 'express';
import { planningService } from '../services/planning.service';
import { animeCatalogService } from '../services/anime-catalog.service';
import { filmCatalogService } from '../services/film-catalog.service';
import { scrapeAnimeSeasons, scrapeSeasonEpisodes } from '../services/season-scraper.service';
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

// GET /api/animes/catalogue?search=query&page=1&type=anime|film - Recherche catalogue
router.get('/catalogue', async (req: Request, res: Response) => {
    try {
        const search = typeof req.query.search === 'string' ? req.query.search : '';
        const pageParam = typeof req.query.page === 'string' ? Number(req.query.page) : 1;
        const type = typeof req.query.type === 'string' ? req.query.type : 'anime'; // 'anime' or 'film'
        const page = Number.isFinite(pageParam) ? pageParam : 1;

        console.log(`🔍 /catalogue called: search="${search}", page=${page}, type="${type}"`);

        let result: CatalogResult;
        
        if (type === 'film') {
            result = await filmCatalogService.search(search, page);
        } else {
            // Default to anime
            result = await animeCatalogService.search(search, page);
        }

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

// GET /api/animes/seasons/:animeSlug/episodes?url=... - Nombre d'épisodes d'une saison
router.get('/seasons/:animeSlug/episodes', async (req: Request, res: Response) => {
    try {
        const seasonUrl = typeof req.query.url === 'string' ? req.query.url : '';
        if (!seasonUrl) {
            const response: ApiResponse<null> = {
                success: false,
                data: null,
                error: 'Paramètre url requis',
                timestamp: new Date().toISOString(),
            };
            res.status(400).json(response);
            return;
        }

        const episodeCount = await scrapeSeasonEpisodes(seasonUrl);
        const response: ApiResponse<{ episodeCount: number }> = {
            success: true,
            data: { episodeCount },
            timestamp: new Date().toISOString(),
        };
        res.json(response);
    } catch (error) {
        const response: ApiResponse<null> = {
            success: false,
            data: null,
            error: error instanceof Error ? error.message : 'Erreur lors du scraping des épisodes',
            timestamp: new Date().toISOString(),
        };
        res.status(500).json(response);
    }
});

// GET /api/animes/seasons/:animeSlug - Récupérer les saisons d'un anime
router.get('/seasons/:animeSlug', async (req: Request, res: Response) => {
    try {
        const { animeSlug } = req.params;
        const animeInfo = await scrapeAnimeSeasons(animeSlug);
        
        const response: ApiResponse<any> = {
            success: true,
            data: animeInfo,
            timestamp: new Date().toISOString(),
        };
        res.json(response);
    } catch (error) {
        const response: ApiResponse<null> = {
            success: false,
            data: null,
            error: error instanceof Error ? error.message : 'Erreur lors du scraping des saisons',
            timestamp: new Date().toISOString(),
        };
        res.status(500).json(response);
    }
});

export default router;
