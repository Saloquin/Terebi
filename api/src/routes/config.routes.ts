import { Router, Request, Response } from 'express';
import { animeScraperService } from '../services/anime-scraper.service';
import { planningService } from '../services/planning.service';

const router = Router();

// GET /api/config - Récupérer la config actuelle
router.get('/', (_req: Request, res: Response) => {
    res.json({
        success: true,
        data: {
            extension: animeScraperService.getExtension(),
            baseUrl: `https://anime-sama.${animeScraperService.getExtension()}`,
        },
        timestamp: new Date().toISOString(),
    });
});

// GET /api/config/detect - Détecter automatiquement l'extension active depuis anime-sama.pw
router.get('/detect', async (_req: Request, res: Response) => {
    const detected = await animeScraperService.detectActiveExtension();

    if (!detected) {
        res.status(502).json({
            success: false,
            data: null,
            error: 'Impossible de détecter l\'extension active',
            timestamp: new Date().toISOString(),
        });
        return;
    }

    const previousExtension = animeScraperService.getExtension();
    if (detected !== previousExtension) {
        animeScraperService.setExtension(detected);
        planningService.clearCache();
        console.log(`🔄 Extension auto-mise à jour: ${previousExtension} → ${detected}`);
    }

    res.json({
        success: true,
        data: {
            extension: detected,
            previousExtension,
            changed: detected !== previousExtension,
            baseUrl: `https://anime-sama.${detected}`,
        },
        timestamp: new Date().toISOString(),
    });
});

// PUT /api/config/extension — mettre à jour l'extension anime-sama (mémoire serveur)
router.put('/extension', (req: Request, res: Response) => {
    const extension = typeof req.body?.extension === 'string' ? req.body.extension.trim() : '';
    if (!extension) {
        res.status(400).json({
            success: false,
            data: null,
            error: 'Extension requise',
            timestamp: new Date().toISOString(),
        });
        return;
    }
    animeScraperService.setExtension(extension);
    planningService.clearCache();
    res.json({
        success: true,
        data: {
            extension: animeScraperService.getExtension(),
            baseUrl: `https://anime-sama.${animeScraperService.getExtension()}`,
        },
        timestamp: new Date().toISOString(),
    });
});

export default router;
