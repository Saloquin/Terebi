import { Router, Request, Response } from 'express';
import { userDataService } from '../services/user-data.service';
import { ApiResponse } from '../types/anime.types';

const router = Router();

const ok = <T>(res: Response, data: T): void => {
    res.json({ success: true, data, timestamp: new Date().toISOString() } satisfies ApiResponse<T>);
};

const fail = (res: Response, status: number, error: string): void => {
    res.status(status).json({
        success: false,
        data: null,
        error,
        timestamp: new Date().toISOString(),
    } satisfies ApiResponse<null>);
};

// GET /api/user/hidden
router.get('/hidden', (_req: Request, res: Response) => {
    try {
        ok(res, userDataService.getHiddenIds());
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// POST /api/user/hidden/:id
router.post('/hidden/:id', (req: Request, res: Response) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (!Number.isFinite(id)) {
            fail(res, 400, 'ID invalide');
            return;
        }
        ok(res, userDataService.hideAnime(id));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// DELETE /api/user/hidden/:id
router.delete('/hidden/:id', (req: Request, res: Response) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (!Number.isFinite(id)) {
            fail(res, 400, 'ID invalide');
            return;
        }
        ok(res, userDataService.unhideAnime(id));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// GET /api/user/towatch
router.get('/towatch', (_req: Request, res: Response) => {
    try {
        ok(res, userDataService.getList('towatch'));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// POST /api/user/towatch/:id
router.post('/towatch/:id', (req: Request, res: Response) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (!Number.isFinite(id)) {
            fail(res, 400, 'ID invalide');
            return;
        }
        ok(res, userDataService.addToList('towatch', id));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// DELETE /api/user/towatch/:id
router.delete('/towatch/:id', (req: Request, res: Response) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (!Number.isFinite(id)) {
            fail(res, 400, 'ID invalide');
            return;
        }
        ok(res, userDataService.removeFromList('towatch', id));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// GET /api/user/viewed
router.get('/viewed', (_req: Request, res: Response) => {
    try {
        ok(res, userDataService.getList('viewed'));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// POST /api/user/viewed/:id
router.post('/viewed/:id', (req: Request, res: Response) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (!Number.isFinite(id)) {
            fail(res, 400, 'ID invalide');
            return;
        }
        ok(res, userDataService.addToList('viewed', id));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// DELETE /api/user/viewed/:id
router.delete('/viewed/:id', (req: Request, res: Response) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (!Number.isFinite(id)) {
            fail(res, 400, 'ID invalide');
            return;
        }
        ok(res, userDataService.removeFromList('viewed', id));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// GET /api/user/settings
router.get('/settings', (_req: Request, res: Response) => {
    try {
        ok(res, userDataService.getSettings());
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// PUT /api/user/settings
router.put('/settings', (req: Request, res: Response) => {
    try {
        ok(res, userDataService.saveSettings(req.body || {}));
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// GET /api/user/episode-progress
router.get('/episode-progress', (_req: Request, res: Response) => {
    try {
        ok(res, userDataService.getAllEpisodeProgress());
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// PUT /api/user/episode-progress
router.put('/episode-progress', (req: Request, res: Response) => {
    try {
        const { anilistId, seasonNumber, lastEpisode, totalEpisodes } = req.body as {
            anilistId?: number;
            seasonNumber?: number;
            lastEpisode?: number;
            totalEpisodes?: number;
        };
        if (typeof anilistId !== 'number' || typeof lastEpisode !== 'number') {
            fail(res, 400, 'anilistId et lastEpisode requis');
            return;
        }
        ok(
            res,
            userDataService.setEpisodeProgress(
                anilistId,
                seasonNumber ?? 1,
                lastEpisode,
                totalEpisodes
            )
        );
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

// DELETE /api/user/episode-progress
router.delete('/episode-progress', (req: Request, res: Response) => {
    try {
        const { anilistId, seasonNumber } = req.body as {
            anilistId?: number;
            seasonNumber?: number;
        };
        if (typeof anilistId !== 'number') {
            fail(res, 400, 'anilistId requis');
            return;
        }
        ok(res, {
            deleted: userDataService.deleteEpisodeProgress(anilistId, seasonNumber ?? 1),
        });
    } catch (error) {
        fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
    }
});

export default router;
