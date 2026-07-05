import { Router, Request, Response } from 'express';
import { samaResolveService } from '../services/sama-resolve.service';
import { ApiResponse } from '../types/anime.types';
import { SamaResolveResult } from '../types/anilist.types';

const router = Router();

const ok = (res: Response, data: SamaResolveResult): void => {
    res.json({ success: true, data, timestamp: new Date().toISOString() } satisfies ApiResponse<SamaResolveResult>);
};

const fail = (res: Response, status: number, error: string): void => {
    res.status(status).json({
        success: false,
        data: null,
        error,
        timestamp: new Date().toISOString(),
    } satisfies ApiResponse<null>);
};

// GET /api/sama/resolve?title=...&season=N
router.get('/resolve', async (req: Request, res: Response) => {
    try {
        const title = typeof req.query.title === 'string' ? req.query.title.trim() : '';
        if (!title) {
            fail(res, 400, 'Paramètre title requis');
            return;
        }

        const seasonParam = req.query.season;
        if (seasonParam !== undefined) {
            const season = parseInt(String(seasonParam), 10);
            if (!Number.isFinite(season) || season < 1) {
                fail(res, 400, 'Paramètre season invalide');
                return;
            }
            const result = await samaResolveService.resolveSeason(title, season);
            ok(res, result);
            return;
        }

        const result = await samaResolveService.resolveCatalog(title);
        ok(res, result);
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

export default router;
