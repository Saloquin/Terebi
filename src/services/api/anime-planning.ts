/**
 * Service simple pour récupérer le planning des animes
 */

export interface AnimePlanning {
    id: string;
    title: string;
    imageUrl?: string;
    dayOfWeek: string; 
    time?: string;     
    status?: string;   
    url?: string;      
    fullUrl?: string;  
}

export interface PlanningResult {
    success: boolean;
    data: AnimePlanning[] | null;
    error?: string;
}

class AnimePlanningService {
    private baseUrl = `https://anime-sama.${process.env.REACT_APP_SITE_EXTENSION}`;
    private corsProxy = 'https://corsproxy.io/?'; // Proxy CORS alternatif
    private animeCache: AnimePlanning[] | null = null;
    private cacheTimestamp: Date | null = null;
    private cacheDuration = 10 * 60 * 1000; // 10 minutes en millisecondes

    /**
     * Récupérer le HTML d'une page
     */
    async fetchPageHTML(endpoint: string): Promise<{ success: boolean; html?: string; error?: string }> {
        try {
            // Utiliser un proxy CORS pour contourner les restrictions
            const targetUrl = encodeURIComponent(`${this.baseUrl}${endpoint}`);
            const response = await fetch(`${this.corsProxy}${targetUrl}`, {
                method: 'GET',
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            // corsproxy.io retourne directement le HTML, pas un JSON
            const html = await response.text();
            return { success: true, html };

        } catch (error) {
            return {
                success: false,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }    /**
     * Parser le planning des animes depuis le HTML (nouvelle structure avec cartes)
     */
    parsePlanning(html: string): AnimePlanning[] {
        try {
            const parser = new DOMParser();
            const doc = parser.parseFromString(html, 'text/html');
            const animes: AnimePlanning[] = [];
            
            // Nouvelle mapping des IDs pour les jours (0-6)
            const dayIds = ['0', '1', '2', '3', '4', '5', '6']; // 0 = Lundi, 1 = Mardi, etc.
            const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
            
            dayIds.forEach((dayId, dayIndex) => {
                const daySection = doc.querySelector(`[id="${dayId}"]`);
                
                if (daySection) {
                    // Récupérer le titre du jour depuis l'élément h2
                    let dayTitle = daySection.querySelector('.titreJours')?.textContent?.trim() || dayNames[dayIndex];
                    
                    // Nettoyer le format "Sorties du Lundi - 05/01" pour extraire juste "Lundi"
                    const dayMatch = dayTitle.match(/Sorties du (\w+)/i);
                    if (dayMatch) {
                        dayTitle = dayMatch[1]; // Extraire juste le jour (ex: "Lundi")
                    }
                    
                    // Chercher toutes les cartes d'anime et de scan
                    const animeCards = daySection.querySelectorAll('.anime-card-premium, .scan-card-premium');
                    
                    animeCards.forEach((card) => {
                        const anchor = card.querySelector('a');
                        if (!anchor) return;
                        
                        // Extraire les informations de base
                        const url = anchor.getAttribute('href') || '';
                        const title = card.querySelector('.card-title')?.textContent?.trim() || '';
                        const imageElement = card.querySelector('.card-image') as HTMLImageElement;
                        const imageUrl = imageElement?.src || '';
                        
                        // Détecter le type (Anime ou Scan)
                        const isAnime = card.classList.contains('anime-card-premium');
                        const contentType = isAnime ? 'Anime' : 'Scan';
                        
                        // Détecter la langue via le flag
                        const flagImg = card.querySelector('.flag-icon') as HTMLImageElement;
                        let language = 'VOSTFR'; // Par défaut
                        if (flagImg) {
                            const flagSrc = flagImg.src;
                            if (flagSrc.includes('flag_fr.png')) {
                                language = 'VF';
                            } else if (flagSrc.includes('flag_jp.png')) {
                                language = 'VOSTFR';
                            }
                        }
                        
                        // Récupérer l'heure
                        const timeElements = card.querySelectorAll('.info-text');
                        let time = '';
                        timeElements.forEach(elem => {
                            const text = elem.textContent?.trim() || '';
                            // Chercher un pattern d'heure (XXhXX ou ?)
                            if (text.match(/^\d+h\d+$/) || text === '?') {
                                time = text;
                            }
                        });
                        
                        // Récupérer les informations de saison
                        let seasonInfo = '';
                        timeElements.forEach(elem => {
                            const text = elem.textContent?.trim() || '';
                            if (text.startsWith('Saison ')) {
                                seasonInfo = text;
                            }
                        });
                        
                        // Validation de base
                        if (this.isValidAnimeEntry(title, url, language)) {
                            // Créer un ID stable
                            const stableId = `${dayTitle.toLowerCase()}-${title.toLowerCase().replace(/[^a-z0-9]/g, '')}-${time || 'no-time'}-${language}`;
                            
                            animes.push({
                                id: stableId,
                                title: title,
                                imageUrl: imageUrl || undefined,
                                dayOfWeek: dayTitle,
                                time: time || undefined,
                                status: `${contentType} ${language}${seasonInfo ? ` - ${seasonInfo}` : ''}`,
                                url: url.startsWith('/') ? url.substring(1) : url,
                                fullUrl: url ? `${this.baseUrl}${url}` : undefined
                            });
                            
                            console.log(`✅ ${contentType} ajouté: ${title} (${dayTitle}) [${language}] [ID: ${stableId}]`);
                        } else {
                            console.log(`❌ ${contentType} invalide ignoré: ${title} (langue: ${language})`);
                        }
                    });
                }
            });
            
            console.log(`📊 Total d'animes/scans parsés: ${animes.length}`);
            console.table(animes.map(a => ({ 
                titre: a.title, 
                jour: a.dayOfWeek, 
                heure: a.time, 
                type: a.status 
            })));
            
            return animes;

        } catch (error) {
            console.error('Erreur lors du parsing du planning:', error);
            return [];
        }
    }    /**
     * Valider si une entrée est un vrai anime (pas un commentaire ou élément indésirable)
     * Ignore tous les contenus VF (animes et scans)
     */
    private isValidAnimeEntry(nom: string, url: string, type: string): boolean {
        if (!nom || nom.trim().length === 0) {
            return false;
        }
        const normalizedName = nom.trim().toLowerCase();
        
        // Ignorer tous les contenus VF (animes et scans)
        if (type === 'VF') {
            return false;
        }
        
        // Types valides pour les animes (seulement VOSTFR maintenant)
        const validTypes = ['VOSTFR'];
        const hasValidType = !type || validTypes.includes(type);

        const minLength = 2; // Au moins 2 caractères
        const hasReasonableLength = normalizedName.length >= minLength;
        const hasLetter = /[a-zA-Zà-ÿ]/.test(normalizedName);
        
        return hasValidType && hasReasonableLength && hasLetter;
    }
    
    /**
     * Vérifier si le cache est encore valide
     */
    private isCacheValid(): boolean {
        return this.animeCache !== null && 
               this.cacheTimestamp !== null && 
               (Date.now() - this.cacheTimestamp.getTime()) < this.cacheDuration;
    }

    /**
     * Récupérer le planning complet avec cache
     */
    async getPlanning(endpoint = '/planning/'): Promise<PlanningResult> {
        // Vérifier le cache d'abord
        if (this.isCacheValid() && this.animeCache) {
            return {
                success: true,
                data: this.animeCache
            };
        }
        // Sinon, récupérer depuis le site
        const fetchResult = await this.fetchPageHTML(endpoint);
        if (!fetchResult.success || !fetchResult.html) {
            return {
                success: false,
                data: null,
                error: fetchResult.error || 'Impossible de récupérer la page'
            };
        }
        const animes = this.parsePlanning(fetchResult.html);
        this.animeCache = animes;
        this.cacheTimestamp = new Date();
        
        return {
            success: true,
            data: animes
        };
    }

    /**
     * Forcer le rechargement du cache
     */
    async refreshCache(): Promise<PlanningResult> {
        this.animeCache = null;
        this.cacheTimestamp = null;
        return this.getPlanning();
    }

    /**
     * Récupérer les animes d'un jour spécifique
     */
    async getAnimesByDay(day: string): Promise<PlanningResult> {
        const planningResult = await this.getPlanning();
        
        if (!planningResult.success || !planningResult.data) {
            return planningResult;
        }

        const filteredAnimes = planningResult.data.filter(
            anime => anime.dayOfWeek.toLowerCase() === day.toLowerCase()
        );

        return {
            success: true,
            data: filteredAnimes
        };
    }    /**
     * Récupérer les animes d'aujourd'hui
     */
    async getTodayAnimes(): Promise<PlanningResult> {
        const today = new Date();
        const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
        const todayName = dayNames[today.getDay()];
        
        return this.getAnimesByDay(todayName);
    }

    // Fonctions get spécifiques pour chaque jour
    async getLundiAnimes(): Promise<PlanningResult> {
        return this.getAnimesByDay('Lundi');
    }

    async getMardiAnimes(): Promise<PlanningResult> {
        return this.getAnimesByDay('Mardi');
    }

    async getMercrediAnimes(): Promise<PlanningResult> {
        return this.getAnimesByDay('Mercredi');
    }

    async getJeudiAnimes(): Promise<PlanningResult> {
        return this.getAnimesByDay('Jeudi');
    }

    async getVendrediAnimes(): Promise<PlanningResult> {
        return this.getAnimesByDay('Vendredi');
    }

    async getSamediAnimes(): Promise<PlanningResult> {
        return this.getAnimesByDay('Samedi');
    }

    async getDimancheAnimes(): Promise<PlanningResult> {
        return this.getAnimesByDay('Dimanche');
    }

    /**
     * Obtenir des statistiques sur le planning
     */
    async getPlanningStats(): Promise<{
        totalAnimes: number;
        animesByDay: Record<string, number>;
        nextAirings: AnimePlanning[];
    }> {
        const planningResult = await this.getPlanning();
        
        if (!planningResult.success || !planningResult.data) {
            return {
                totalAnimes: 0,
                animesByDay: {},
                nextAirings: []
            };
        }

        const animes = planningResult.data;
        const animesByDay: Record<string, number> = {};
        
        // Compter les animes par jour
        animes.forEach(anime => {
            animesByDay[anime.dayOfWeek] = (animesByDay[anime.dayOfWeek] || 0) + 1;
        });

        // Trouver les prochaines diffusions (aujourd'hui et demain)
        const today = new Date();
        const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
        const todayName = dayNames[today.getDay()];
        const tomorrowName = dayNames[(today.getDay() + 1) % 7];

        const nextAirings = animes.filter(anime => 
            anime.dayOfWeek === todayName || anime.dayOfWeek === tomorrowName
        ).slice(0, 5);

        return {
            totalAnimes: animes.length,
            animesByDay,
            nextAirings
        };
    }
}

// Instance singleton
export const animePlanningService = new AnimePlanningService();

// Fonctions d'export simples
export const getAnimePlanning = () => animePlanningService.getPlanning();
export const refreshAnimePlanning = () => animePlanningService.refreshCache();
export const getTodayAnimes = () => animePlanningService.getTodayAnimes();
export const getAnimesByDay = (day: string) => animePlanningService.getAnimesByDay(day);

// Fonctions pour chaque jour spécifique
export const getLundiAnimes = () => animePlanningService.getLundiAnimes();
export const getMardiAnimes = () => animePlanningService.getMardiAnimes();
export const getMercrediAnimes = () => animePlanningService.getMercrediAnimes();
export const getJeudiAnimes = () => animePlanningService.getJeudiAnimes();
export const getVendrediAnimes = () => animePlanningService.getVendrediAnimes();
export const getSamediAnimes = () => animePlanningService.getSamediAnimes();
export const getDimancheAnimes = () => animePlanningService.getDimancheAnimes();

// Fonctions utilitaires
export const getPlanningStats = () => animePlanningService.getPlanningStats();
