import { Router, Request, Response } from 'express';

import { anilistService, AniListApiError } from '../services/anilist.service';
import { AniListSeason, MediaListStatus } from '../types/anilist.types';
import { ApiResponse } from '../types/anime.types';

const router = Router();

const ok = <T>(res: Response, data: T) =>
    res.json({ success: true, data, timestamp: new Date().toISOString() } satisfies ApiResponse<T>);

const fail = (res: Response, status: number, error: string, code?: string) =>
    res.status(status).json({
        success: false,
        data: null,
        error,
        code,
        timestamp: new Date().toISOString(),
    } satisfies ApiResponse<null>);

const handle = (res: Response, error: unknown) => {
    if (error instanceof AniListApiError) {
        if (error.retryAfter) {
            res.set('Retry-After', String(error.retryAfter));
        }
        fail(res, error.status, error.message, error.code);
        return;
    }
    fail(res, 500, error instanceof Error ? error.message : 'Erreur inconnue');
};

const getBearerToken = (req: Request): string | undefined => {
    const auth = req.headers.authorization;
    if (!auth?.startsWith('Bearer ')) return undefined;
    const token = auth.slice(7).trim();
    return token.length > 10 ? token : undefined;
};

const requireAuth = (req: Request, res: Response): string | false => {
    const token = getBearerToken(req);
    if (!token) {
        fail(res, 401, 'Token AniList requis. Connectez votre compte.', 'ANILIST_AUTH');
        return false;
    }
    return token;
};

const parseSeason = (v: unknown): AniListSeason | null => {
    const s = String(v || '').toUpperCase();
    return ['WINTER', 'SPRING', 'SUMMER', 'FALL'].includes(s) ? (s as AniListSeason) : null;
};

const VALID: MediaListStatus[] = ['CURRENT', 'PLANNING', 'COMPLETED', 'PAUSED', 'DROPPED', 'REPEATING'];

const parseStatuses = (v: unknown) =>
    String(v || '')
        .split(',')
        .map(s => s.trim().toUpperCase())
        .map(s => (s === 'WATCHING' ? 'CURRENT' : s) as MediaListStatus)
        .filter(s => VALID.includes(s));

router.post('/auth/url', (req, res) => {
    try {
        const clientId = typeof req.body?.clientId === 'string' ? req.body.clientId.trim() : '';
        if (!clientId) return fail(res, 400, 'Client ID requis', 'ANILIST_CONFIG');
        const redirectUri =
            typeof req.body?.redirectUri === 'string' && req.body.redirectUri.trim()
                ? req.body.redirectUri.trim()
                : anilistService.getRedirectUri();
        ok(res, {
            url: anilistService.buildAuthorizationUrl(clientId, redirectUri, 'code'),
            redirectUri,
        });
    } catch (e) {
        handle(res, e);
    }
});

router.post('/auth/token', async (req, res) => {
    try {
        const code = typeof req.body?.code === 'string' ? req.body.code.trim() : '';
        const clientId = typeof req.body?.clientId === 'string' ? req.body.clientId.trim() : '';
        const clientSecret = typeof req.body?.clientSecret === 'string' ? req.body.clientSecret.trim() : '';
        if (!code) return fail(res, 400, 'Code OAuth requis');
        if (!clientId || !clientSecret) {
            return fail(res, 400, 'Client ID et Client Secret requis', 'ANILIST_CONFIG');
        }
        const redirectUri =
            typeof req.body?.redirectUri === 'string' && req.body.redirectUri.trim()
                ? req.body.redirectUri.trim()
                : anilistService.getRedirectUri();
        const accessToken = await anilistService.exchangeCodeForToken(code, clientId, clientSecret, redirectUri);
        ok(res, { accessToken });
    } catch (e) {
        handle(res, e);
    }
});

router.get('/auth/url', (_req, res) => {
    try {
        ok(res, { url: anilistService.getAuthorizationUrl(), redirectUri: anilistService.getRedirectUri() });
    } catch (e) {
        handle(res, e);
    }
});

router.get('/auth/callback', async (req, res) => {
    const frontend = anilistService.getFrontendUrl();
    const callbackPath = `${frontend}/settings/callback`;
    const settingsPath = `${frontend}/settings`;
    try {
        const code = typeof req.query.code === 'string' ? req.query.code.trim() : '';
        if (!code) {
            res.redirect(`${settingsPath}?anilist=error&message=${encodeURIComponent('Code OAuth manquant')}`);
            return;
        }
        if (anilistService.hasEnvCredentials()) {
            const token = await anilistService.exchangeCodeWithEnv(code);
            res.redirect(`${settingsPath}#anilist_token=${encodeURIComponent(token)}`);
            return;
        }
        res.redirect(`${callbackPath}?code=${encodeURIComponent(code)}`);
    } catch (e) {
        res.redirect(
            `${settingsPath}?anilist=error&message=${encodeURIComponent(e instanceof Error ? e.message : 'Erreur OAuth')}`,
        );
    }
});

router.get('/oauth/authorize-url', (req, res) => {
    try {
        const clientId =
            typeof req.query.clientId === 'string'
                ? req.query.clientId.trim()
                : typeof req.body?.clientId === 'string'
                  ? req.body.clientId.trim()
                  : '';
        if (clientId) {
            ok(res, {
                url: anilistService.buildAuthorizationUrl(clientId, anilistService.getRedirectUri(), 'code'),
                redirectUri: anilistService.getRedirectUri(),
            });
            return;
        }
        ok(res, {
            url: anilistService.getAuthorizationUrl(),
            redirectUri: anilistService.getRedirectUri(),
        });
    } catch (e) {
        handle(res, e);
    }
});

router.get('/oauth/status', async (req, res) => {
    const token = getBearerToken(req);
    if (!token) {
        ok(res, { connected: false });
        return;
    }
    try {
        const viewer = await anilistService.getViewer(token);
        ok(res, { connected: true, username: viewer.name, userId: viewer.id });
    } catch (e) {
        if (e instanceof AniListApiError && (e.status === 401 || e.status === 403)) {
            ok(res, { connected: false, expired: true });
            return;
        }
        handle(res, e);
    }
});

router.get('/me', async (req, res) => {
    const token = requireAuth(req, res);
    if (!token) return;
    try {
        ok(res, await anilistService.getViewer(token));
    } catch (e) {
        handle(res, e);
    }
});

router.get('/lists', async (req, res) => {
    const token = requireAuth(req, res);
    if (!token) return;
    try {
        const s = parseStatuses(req.query.status);
        if (!s.length) return fail(res, 400, 'Paramètre status requis');
        ok(res, { entries: await anilistService.getMediaListEntries(token, s) });
    } catch (e) {
        handle(res, e);
    }
});

router.post('/lists/:mediaId', async (req, res) => {
    const token = requireAuth(req, res);
    if (!token) return;
    try {
        const mediaId = parseInt(req.params.mediaId, 10);
        if (!Number.isFinite(mediaId)) return fail(res, 400, 'ID invalide');
        const raw = String(req.body?.status || '').toUpperCase();
        const status = (raw === 'WATCHING' ? 'CURRENT' : raw) as MediaListStatus;
        if (!VALID.includes(status)) return fail(res, 400, 'Statut invalide');
        const progress =
            req.body?.progress !== undefined ? parseInt(String(req.body.progress), 10) : undefined;
        ok(
            res,
            await anilistService.saveMediaListEntry(
                token,
                mediaId,
                status,
                Number.isFinite(progress) ? progress : undefined,
            ),
        );
    } catch (e) {
        handle(res, e);
    }
});

router.delete('/lists/:mediaId', async (req, res) => {
    const token = requireAuth(req, res);
    if (!token) return;
    try {
        const id = parseInt(req.params.mediaId, 10);
        if (!Number.isFinite(id)) return fail(res, 400, 'ID invalide');
        ok(res, { deleted: await anilistService.deleteMediaListEntry(token, id) });
    } catch (e) {
        handle(res, e);
    }
});

router.get('/season', async (req, res) => {
    try {
        const c = anilistService.getCurrentSeason();
        const season = parseSeason(req.query.season) || c.season;
        const year = parseInt(String(req.query.year || c.year), 10) || c.year;
        ok(res, {
            season,
            year,
            ...(await anilistService.getSeason(
                season,
                year,
                parseInt(String(req.query.page || '1'), 10) || 1,
                parseInt(String(req.query.perPage || '50'), 10) || 50,
            )),
        });
    } catch (e) {
        handle(res, e);
    }
});

router.get('/search', async (req, res) => {
    try {
        const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
        if (!q) return fail(res, 400, 'Paramètre q requis');
        ok(res, await anilistService.search(q, parseInt(String(req.query.page || '1'), 10) || 1));
    } catch (e) {
        handle(res, e);
    }
});

router.get('/anime/:id', async (req, res) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (!Number.isFinite(id)) return fail(res, 400, 'ID invalide');
        const m = await anilistService.getAnime(id);
        if (!m) return fail(res, 404, 'Introuvable');
        ok(res, m);
    } catch (e) {
        handle(res, e);
    }
});

router.get('/planning', async (req, res) => {
    try {
        const c = anilistService.getCurrentSeason();
        const season = parseSeason(req.query.season) || c.season;
        const year = parseInt(String(req.query.year || c.year), 10) || c.year;
        anilistService.resetRequestCount();
        const media = await anilistService.getPlanningMedia(season, year);
        const anilistRequests = anilistService.getRequestCount();
        console.log(`📊 Planning ${season} ${year}: ${anilistRequests} requête(s) AniList`);
        ok(res, { season, year, media, anilistRequests });
    } catch (e) {
        handle(res, e);
    }
});

router.get('/current-season', (_req, res) => ok(res, anilistService.getCurrentSeason()));

export default router;
