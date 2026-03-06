/**
 * Service intégré pour gérer les animes avec cache rapide + requêtes réseau
 */

import { AnimePlanning, getAnimePlanning as fetchFromNetwork } from './anime-planning';
import { 
    animeStorageService, 
    saveAnimes, 
    getCurrentAnimes, 
    getCurrentAnimesByDay,
    hasAnimeCache 
} from './animeStorage';

export interface IntegratedAnimeResult {
    success: boolean;
    data: AnimePlanning[] | null;
    error?: string;
    fromCache: boolean;
    needsUpdate?: boolean;
}

class IntegratedAnimeService {
    private updateInProgress = false;

    /**
     * Récupérer les animes avec affichage rapide du cache puis mise à jour réseau
     */
    async getAnimesWithFastDisplay(): Promise<IntegratedAnimeResult> {
        try {
            // Si on a un cache, l'afficher immédiatement sinon requete
            const cacheResult = getCurrentAnimes();
            if (cacheResult.success && cacheResult.data && cacheResult.data.length > 0) {
                this.updateCacheInBackground();
                return {
                    success: true,
                    data: cacheResult.data,
                    fromCache: true,
                    needsUpdate: !this.updateInProgress
                };
            }
            return await this.fetchAndCache();

        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur inconnue',
                fromCache: false
            };
        }
    }

    /**
     * Forcer la mise à jour depuis le réseau
     */
    async forceUpdate(): Promise<IntegratedAnimeResult> {
        return await this.fetchAndCache();
    }

    /**
     * Récupérer depuis le réseau et mettre en cache
     */
    private async fetchAndCache(): Promise<IntegratedAnimeResult> {
        try {
            const networkResult = await fetchFromNetwork();
            
            if (networkResult.success && networkResult.data) {
                // Sauvegarder dans le cache
                saveAnimes(networkResult.data);
                
                return {
                    success: true,
                    data: networkResult.data,
                    fromCache: false
                };
            } else {
                return {
                    success: false,
                    data: null,
                    error: networkResult.error || 'Erreur réseau',
                    fromCache: false
                };
            }
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur réseau',
                fromCache: false
            };
        }
    }

    /**
     * Mettre à jour le cache en arrière-plan
     */
    private async updateCacheInBackground(): Promise<void> {
        if (this.updateInProgress) return;
        
        this.updateInProgress = true;
        
        try {
            const networkResult = await fetchFromNetwork();
            
            if (networkResult.success && networkResult.data) {
                saveAnimes(networkResult.data);
                console.log('✅ Cache anime mis à jour en arrière-plan');
            }
        } catch (error) {
            console.warn('⚠️ Échec de la mise à jour en arrière-plan:', error);
        } finally {
            this.updateInProgress = false;
        }
    }

    /**
     * Récupérer les animes d'un jour avec cache rapide
     */    async getAnimesByDayWithCache(day: string): Promise<IntegratedAnimeResult> {
        try {
            // Affichage rapide depuis le cache
            const cacheResult = getCurrentAnimesByDay(day);
              if (cacheResult.success && cacheResult.data && cacheResult.data.length > 0) {
                // Lancer la mise à jour en arrière-plan
                this.updateCacheInBackground();
                
                return {
                    success: true,
                    data: cacheResult.data,
                    fromCache: true,
                    needsUpdate: !this.updateInProgress
                };
            }

            // Pas de cache pour ce jour, récupérer depuis le réseau
            const networkResult = await this.fetchAndCache();
            
            if (networkResult.success && networkResult.data) {
                const filteredAnimes = networkResult.data.filter(
                    anime => anime.dayOfWeek.toLowerCase() === day.toLowerCase()
                );
                  return {
                    ...networkResult,
                    data: filteredAnimes
                };
            }

            return networkResult;

        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur inconnue',
                fromCache: false
            };
        }
    }

    /**
     * Vérifier l'état du cache
     */
    getCacheStatus(): {
        hasCache: boolean;
        stats: ReturnType<typeof animeStorageService.getCurrentStats>;
        updateInProgress: boolean;
    } {
        return {
            hasCache: hasAnimeCache(),
            stats: animeStorageService.getCurrentStats(),
            updateInProgress: this.updateInProgress
        };
    }
}

// Instance singleton
export const integratedAnimeService = new IntegratedAnimeService();

// Fonctions d'export principales
export const getAnimesWithFastDisplay = () => integratedAnimeService.getAnimesWithFastDisplay();
export const forceAnimeUpdate = () => integratedAnimeService.forceUpdate();
export const getAnimesByDayWithCache = (day: string) => integratedAnimeService.getAnimesByDayWithCache(day);
export const getAnimeCacheStatus = () => integratedAnimeService.getCacheStatus();

// Fonctions rapides pour chaque jour (avec cache)
export const getLundiAnimesWithCache = () => getAnimesByDayWithCache('Lundi');
export const getMardiAnimesWithCache = () => getAnimesByDayWithCache('Mardi');
export const getMercrediAnimesWithCache = () => getAnimesByDayWithCache('Mercredi');
export const getJeudiAnimesWithCache = () => getAnimesByDayWithCache('Jeudi');
export const getVendrediAnimesWithCache = () => getAnimesByDayWithCache('Vendredi');
export const getSamediAnimesWithCache = () => getAnimesByDayWithCache('Samedi');
export const getDimancheAnimesWithCache = () => getAnimesByDayWithCache('Dimanche');

export const getTodayAnimesWithCache = () => {
    const today = new Date();
    const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    const todayName = dayNames[today.getDay()];
    return getAnimesByDayWithCache(todayName);
};
