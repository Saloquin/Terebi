import { Router, Request, Response } from 'express';
import { anilistService, AniListApiError } from '../services/anilist.service';
import { AniListSeason } from '../types/anilist.types';
import { ApiResponse } from '../types/anime.types';

const router = Router();

const ok = <T>(res: Response, data: T): void => {
    res.json({ success: true, data, timestamp: new Date().toISOString() } satisfies ApiResponse<T>);
};

const fail = (res: Response, status: number, error: string, code?: string): void => {
    res.status(status).json({
        success: false,
        data: null,
        error,
        code,
        timestamp: new Date().toISOString(),
    } satisfies ApiResponse<null>);
};

const handleAnilistError = (res: Response, error: unknown): void => {
    if (error instanceof AniListApiError && error.status === 401) {
        fail(res, 401, error.message, 'ANILIST_AUTH');
        return;
    }
    fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
};

const parseSeason = (value: unknown): AniListSeason | null => {
    const s = String(value || '').toUpperCase();
    if (['WINTER', 'SPRING', 'SUMMER', 'FALL'].includes(s)) return s as AniListSeason;
    return null;
};

// GET /api/anilist/season?season=WINTER&year=2026&page=1
router.get('/season', async (req: Request, res: Response) => {
    try {
        const current = anilistService.getCurrentSeason();
        const season = parseSeason(req.query.season) || current.season;
        const yearParam = parseInt(String(req.query.year || current.year), 10);
        const year = Number.isFinite(yearParam) ? yearParam : current.year;
        const page = parseInt(String(req.query.page || '1'), 10) || 1;
        const perPage = parseInt(String(req.query.perPage || '50'), 10) || 50;

        const result = await anilistService.getSeason(season, year, page, perPage);
        ok(res, { season, year, ...result });
    } catch (error) {
        handleAnilistError(res, error);
    }
});

// GET /api/anilist/search?q=...&page=1
router.get('/search', async (req: Request, res: Response) => {
    try {
        const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
        if (!q) {
            fail(res, 400, 'Paramètre q requis');
            return;
        }
        const page = parseInt(String(req.query.page || '1'), 10) || 1;
        const result = await anilistService.search(q, page);
        ok(res, result);
    } catch (error) {
        handleAnilistError(res, error);
    }
});

// GET /api/anilist/anime/:id
router.get('/anime/:id', async (req: Request, res: Response) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (!Number.isFinite(id)) {
            fail(res, 400, 'ID invalide');
            return;
        }
        const media = await anilistService.getAnime(id);
        if (!media) {
            fail(res, 404, 'Anime introuvable');
            return;
        }
        ok(res, media);
    } catch (error) {
        handleAnilistError(res, error);
    }
});

// GET /api/anilist/current-season
router.get('/current-season', (_req: Request, res: Response) => {
    ok(res, anilistService.getCurrentSeason());
});

export default router;
