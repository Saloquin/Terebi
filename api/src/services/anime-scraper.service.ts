import { parse, HTMLElement } from 'node-html-parser';
import { AnimePlanning } from '../types/anime.types';

class AnimeScraperService {
    private extension: string;
    private flareSolverrUrl: string;
    private cache: AnimePlanning[] | null = null;
    private cacheTimestamp: Date | null = null;
    private cacheDuration = 10 * 60 * 1000; // 10 minutes

    constructor() {
        this.extension = process.env.SITE_EXTENSION || 'to';
        this.flareSolverrUrl = process.env.FLARESOLVERR_URL || 'http://localhost:8191/v1';
    }

    private get baseUrl(): string {
        return `https://anime-sama.${this.extension}`;
    }

    getExtension(): string {
        return this.extension;
    }

    setExtension(ext: string): void {
        if (ext !== this.extension) {
            console.log(`🔄 Extension changée: ${this.extension} → ${ext}`);
            this.extension = ext;
            this.clearCache();
        }
    }

    private isCacheValid(): boolean {
        if (!this.cache || !this.cacheTimestamp) return false;
        return Date.now() - this.cacheTimestamp.getTime() < this.cacheDuration;
    }

    private isValidAnimeEntry(nom: string, type: string): boolean {
        if (!nom || nom.trim().length === 0) return false;
        if (type === 'VF') return false;
        
        const normalizedName = nom.trim().toLowerCase();
        const hasReasonableLength = normalizedName.length >= 2;
        const hasLetter = /[a-zA-Zà-ÿ]/.test(normalizedName);
        
        return hasReasonableLength && hasLetter;
    }

    async fetchPlanning(): Promise<AnimePlanning[]> {
        // Vérifier le cache
        if (this.isCacheValid() && this.cache) {
            console.log('📦 Utilisation du cache');
            return this.cache;
        }

        const url = `${this.baseUrl}/planning/`;
        console.log('🌐 Récupération via FlareSolverr...');
        console.log(`📍 URL: ${url}`);
        
        try {
            const response = await fetch(this.flareSolverrUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    cmd: 'request.get',
                    url,
                    maxTimeout: 60000,
                }),
            });

            if (!response.ok) {
                throw new Error(`FlareSolverr HTTP error: ${response.status}`);
            }

            const data = await response.json() as any;
            
            if (data.status !== 'ok') {
                throw new Error(`FlareSolverr error: ${data.message || 'Unknown error'}`);
            }

            const html = data.solution.response;
            console.log(`✅ HTML reçu (${html.length} caractères)`);

            const animes = this.parsePlanning(html);
            
            // Mettre en cache
            this.cache = animes;
            this.cacheTimestamp = new Date();
            
            console.log(`✅ ${animes.length} animes récupérés`);
            return animes;

        } catch (error) {
            console.error('❌ Erreur de scraping:', error);
            throw error;
        }
    }

    private parsePlanning(html: string): AnimePlanning[] {
        const root = parse(html);
        const animes: AnimePlanning[] = [];
        
        const dayIds = ['0', '1', '2', '3', '4', '5', '6'];
        const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
        
        dayIds.forEach((dayId, dayIndex) => {
            const daySection = root.querySelector(`[id="${dayId}"]`);
            
            if (daySection) {
                let dayTitle = dayNames[dayIndex];
                const titleElement = daySection.querySelector('.titreJours');
                if (titleElement) {
                    const text = titleElement.text.trim();
                    const dayMatch = text.match(/Sorties du (\w+)/i);
                    if (dayMatch) {
                        dayTitle = dayMatch[1];
                    }
                }
                
                const animeCards = daySection.querySelectorAll('.anime-card-premium, .scan-card-premium');
                
                animeCards.forEach((card: HTMLElement) => {
                    const anchor = card.querySelector('a');
                    if (!anchor) return;
                    
                    const url = anchor.getAttribute('href') || '';
                    const title = card.querySelector('.card-title')?.text.trim() || '';
                    const imageElement = card.querySelector('.card-image');
                    const imageUrl = imageElement?.getAttribute('src') || '';
                    
                    const isAnime = card.classNames.includes('anime-card-premium');
                    const contentType = isAnime ? 'Anime' : 'Scan';
                    
                    // Détecter la langue
                    const flagImg = card.querySelector('.flag-icon');
                    let language = 'VOSTFR';
                    if (flagImg) {
                        const flagSrc = flagImg.getAttribute('src') || '';
                        if (flagSrc.includes('flag_fr.png')) {
                            language = 'VF';
                        }
                    }
                    
                    // Récupérer l'heure
                    let time = '';
                    const timeElements = card.querySelectorAll('.info-text');
                    timeElements.forEach((elem: HTMLElement) => {
                        const text = elem.text.trim();
                        if (text.match(/^\d+h\d+$/) || text === '?') {
                            time = text;
                        }
                    });
                    
                    // Récupérer la saison
                    let seasonInfo = '';
                    timeElements.forEach((elem: HTMLElement) => {
                        const text = elem.text.trim();
                        if (text.startsWith('Saison ')) {
                            seasonInfo = text;
                        }
                    });
                    
                    if (this.isValidAnimeEntry(title, language)) {
                        const stableId = `${dayTitle.toLowerCase()}-${title.toLowerCase().replace(/[^a-z0-9]/g, '')}-${time || 'no-time'}-${language}`;
                        
                        // Déterminer le type final
                        let type: 'VOSTFR' | 'VF' | 'Scan' | 'ScanVF';
                        if (contentType === 'Scan') {
                            type = language === 'VF' ? 'ScanVF' : 'Scan';
                        } else {
                            type = language as 'VOSTFR' | 'VF';
                        }
                        
                        animes.push({
                            id: stableId,
                            title,
                            image: imageUrl || 'https://via.placeholder.com/300x400?text=No+Image',
                            imageUrl: imageUrl || undefined,
                            dayOfWeek: dayTitle,
                            time: time || undefined,
                            type,
                            season: seasonInfo || undefined,
                            status: `${contentType} ${language}${seasonInfo ? ` - ${seasonInfo}` : ''}`,
                            url: url.startsWith('/') ? url.substring(1) : url,
                            fullUrl: url ? `${this.baseUrl}${url}` : undefined
                        });
                    }
                });
            }
        });
        
        return animes;
    }

    getAnimesByDay(day: string): AnimePlanning[] {
        if (!this.cache) return [];
        return this.cache.filter(
            anime => anime.dayOfWeek.toLowerCase() === day.toLowerCase()
        );
    }

    getTodayAnimes(): AnimePlanning[] {
        const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
        const today = dayNames[new Date().getDay()];
        return this.getAnimesByDay(today);
    }

    /**
     * Scrape anime-sama.pw via FlareSolverr pour détecter l'extension active.
     * Cherche dans le tableau de statuts la ligne marquée "en cours" / "actif".
     */
    async detectActiveExtension(): Promise<string | null> {
        const url = 'https://anime-sama.pw';
        console.log('🔍 Détection de l\'extension active depuis', url);

        try {
            const response = await fetch(this.flareSolverrUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    cmd: 'request.get',
                    url,
                    maxTimeout: 60000,
                }),
            });

            if (!response.ok) throw new Error(`FlareSolverr HTTP error: ${response.status}`);

            const data = await response.json() as any;
            if (data.status !== 'ok') throw new Error(`FlareSolverr error: ${data.message}`);

            const html: string = data.solution.response;
            const root = parse(html);
            const activeKeywords = ['adresse en cours', 'en cours', 'actif', 'active'];
            const inactiveKeywords = ['inactif', 'inactive', 'redirection', 'redirig'];

            // Stratégie 1 : source de vérité dynamique, comme la page JS (endpoint ?check=...)
            const checkDomains = [
                'anime-sama.si',
                'anime-sama.tv',
                'anime-sama.to',
                'anime-sama.org',
                'anime-sama.fr',
                'anime-sama.eu',
            ];

            for (const domain of checkDomains) {
                try {
                    const checkUrl = `${url}/?check=${encodeURIComponent(domain)}&_=${Date.now()}`;
                    const checkResponse = await fetch(checkUrl, {
                        redirect: 'follow',
                        headers: {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                            'Accept': 'application/json,text/plain,*/*',
                        },
                    });

                    if (!checkResponse.ok) continue;

                    const checkData = await checkResponse.json() as { status?: string; code?: number };
                    if (checkData?.status === 'online') {
                        const extMatch = domain.match(/anime-sama\.([a-z]{2,10})/i);
                        if (extMatch) {
                            console.log(`✅ Extension détectée (?check online): .${extMatch[1]} (${checkData.code || 'n/a'})`);
                            return extMatch[1].toLowerCase();
                        }
                    }
                } catch {
                    // ignore et continuer les domaines suivants
                }
            }

            // Stratégie 1 : chercher dans le tableau de statuts une ligne explicitement active.
            // On ignore volontairement le bouton "ACCÉDER" car son href peut être stale.
            const rows = root.querySelectorAll('tr, .domain-row, [class*="domain"], [class*="status"], li');
            for (const row of rows) {
                const text = row.text.toLowerCase();
                const isActive = activeKeywords.some(keyword => text.includes(keyword));
                const isInactive = inactiveKeywords.some(keyword => text.includes(keyword));

                if (isActive && !isInactive) {
                    const extMatch = row.text.match(/anime-sama\.([a-z]{2,10})/i)
                        || row.text.match(/\.([a-z]{2,10})/);
                    if (extMatch) {
                        console.log(`✅ Extension détectée (tableau): .${extMatch[1]}`);
                        return extMatch[1].toLowerCase();
                    }
                }
            }

            // Stratégie 3 : fallback regex robuste sur le HTML (actif oui, redirection/inactif non).
            const activeRegexes = [
                /anime-sama\.([a-z]{2,10})[\s\S]{0,140}?(adresse en cours|en cours|actif|active)/ig,
                /(adresse en cours|en cours|actif|active)[\s\S]{0,140}?anime-sama\.([a-z]{2,10})/ig,
            ];

            for (const regex of activeRegexes) {
                const matches = Array.from(html.matchAll(regex));
                for (const match of matches) {
                    const candidates = [match[1], match[2]].map(value => (value || '').toLowerCase());
                    const ext = candidates.find(value => /^[a-z]{2,10}$/.test(value) && !activeKeywords.includes(value));
                    if (!ext) continue;

                    const context = match[0].toLowerCase();
                    const isInactive = inactiveKeywords.some(keyword => context.includes(keyword));
                    if (!isInactive) {
                        console.log(`✅ Extension détectée (fallback regex): .${ext}`);
                        return ext;
                    }
                }
            }

            // Stratégie 4 : suivre la redirection réelle du bouton principal pour obtenir le domaine d'arrivée.
            const accessButton = root.querySelector('a.btn-primary[href*="anime-sama."]')
                || root.querySelector('a[href*="anime-sama."]');
            if (accessButton) {
                const href = accessButton.getAttribute('href') || '';
                if (href.startsWith('http')) {
                    try {
                        const landingResponse = await fetch(href, {
                            redirect: 'follow',
                            headers: {
                                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                            },
                        });

                        const finalUrl = landingResponse.url || href;
                        const finalHost = new URL(finalUrl).hostname.toLowerCase();
                        const finalMatch = finalHost.match(/anime-sama\.([a-z]{2,10})$/i);
                        if (finalMatch) {
                            console.log(`✅ Extension détectée (landing redirect): .${finalMatch[1]} via ${href} → ${finalUrl}`);
                            return finalMatch[1].toLowerCase();
                        }
                    } catch {
                        // ignore et laisser tomber sur null
                    }
                }
            }

            console.warn('⚠️ Impossible de détecter l\'extension depuis', url);
            return null;

        } catch (error) {
            console.error('❌ Erreur détection extension:', error);
            return null;
        }
    }

    clearCache(): void {
        this.cache = null;
        this.cacheTimestamp = null;
        console.log('🗑️ Cache vidé');
    }
}

export const animeScraperService = new AnimeScraperService();
