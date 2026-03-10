import { Router, Request, Response } from 'express';
import { animeScraperService } from '../services/anime-scraper.service';

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

// PUT /api/config - Modifier la config
router.put('/', (req: Request, res: Response) => {
    const { extension } = req.body;

    if (!extension || typeof extension !== 'string') {
        res.status(400).json({
            success: false,
            data: null,
            error: 'Extension manquante ou invalide',
            timestamp: new Date().toISOString(),
        });
        return;
    }

    const cleaned = extension.replace(/^\./, '').trim().toLowerCase();
    if (!/^[a-z]{1,10}$/.test(cleaned)) {
        res.status(400).json({
            success: false,
            data: null,
            error: 'Extension invalide (ex: to, fr, me)',
            timestamp: new Date().toISOString(),
        });
        return;
    }

    animeScraperService.setExtension(cleaned);

    res.json({
        success: true,
        data: {
            extension: cleaned,
            baseUrl: `https://anime-sama.${cleaned}`,
        },
        timestamp: new Date().toISOString(),
    });
});

export default router;
