/**
 * Hook React pour utiliser le système d'animes intégré
 */

import { useState, useEffect, useCallback } from 'react';
import { AnimePlanning } from '../services/api/anime-planning';
import { 
    getAnimesWithFastDisplay, 
    getTodayAnimesWithCache, 
    forceAnimeUpdate,
    getAnimeCacheStatus 
} from '../services/api/animeIntegrated';
import { 
    getCurrentStats, 
    getNewAnimes, 
    addToDoNotDisplay, 
    removeFromDoNotDisplay, 
    markNewAnimeAsSeen 
} from '../services/api/animeStorage';

interface UseAnimeIntegratedOptions {
    autoFetch?: boolean;
    refreshInterval?: number;
}

interface UseAnimeIntegratedReturn {
    // Données principales
    data: AnimePlanning[] | null;
    loading: boolean;
    error: string | null;
    fromCache: boolean;
    
    // Nouvelles données
    newAnimes: AnimePlanning[] | null;
    stats: ReturnType<typeof getCurrentStats> | null;
    
    // Actions principales
    fetchAnimes: () => Promise<void>;
    fetchTodayAnimes: () => Promise<void>;
    forceUpdate: () => Promise<void>;
    refresh: () => Promise<void>;
    
    // Actions de gestion
    hideAnime: (animeId: string) => Promise<{ success: boolean; message: string }>;
    restoreAnime: (animeId: string) => Promise<{ success: boolean; message: string }>;
    markAseSeen: (animeId: string) => Promise<{ success: boolean; message: string }>;
    
    // Utilitaires
    getFilteredData: (day?: string) => AnimePlanning[];
    getTodayName: () => string;
    refreshStats: () => void;
}

export const useAnimeIntegrated = (options: UseAnimeIntegratedOptions = {}): UseAnimeIntegratedReturn => {
    const { autoFetch = true, refreshInterval = 5 * 60 * 1000 } = options; // 5 minutes par défaut
    
    // États principaux
    const [data, setData] = useState<AnimePlanning[] | null>(null);
    const [newAnimes, setNewAnimes] = useState<AnimePlanning[] | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [fromCache, setFromCache] = useState(false);
    const [stats, setStats] = useState<ReturnType<typeof getCurrentStats> | null>(null);

    // Récupération des statistiques
    const refreshStats = useCallback(() => {
        try {
            const currentStats = getCurrentStats();
            setStats(currentStats);
            
            // Récupérer les nouveaux animes
            const newAnimesResult = getNewAnimes();
            if (newAnimesResult.success) {
                setNewAnimes(newAnimesResult.data);
            }
        } catch (error) {
            console.error('Erreur lors de la récupération des stats:', error);
        }
    }, []);

    // Fonction principale de récupération avec affichage rapide
    const fetchAnimes = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);

            const result = await getAnimesWithFastDisplay();
            
            if (result.success && result.data) {
                setData(result.data);
                setFromCache(result.fromCache || false);
                refreshStats();
            } else {
                setError(result.error || 'Erreur lors du chargement des animes');
            }
        } catch (error) {
            setError(error instanceof Error ? error.message : 'Erreur inattendue');
        } finally {
            setLoading(false);
        }
    }, [refreshStats]);

    // Fonction pour récupérer les animes d'aujourd'hui
    const fetchTodayAnimes = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);

            const result = await getTodayAnimesWithCache();
            
            if (result.success && result.data) {
                setData(result.data);
                setFromCache(result.fromCache || false);
                refreshStats();
            } else {
                setError(result.error || 'Erreur lors du chargement des animes d\'aujourd\'hui');
            }
        } catch (error) {
            setError(error instanceof Error ? error.message : 'Erreur inattendue');
        } finally {
            setLoading(false);
        }
    }, [refreshStats]);

    // Forcer une mise à jour depuis le réseau
    const forceUpdate = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);

            const result = await forceAnimeUpdate();
            
            if (result.success && result.data) {
                setData(result.data);
                setFromCache(false);
                refreshStats();
            } else {
                setError(result.error || 'Erreur lors de la mise à jour forcée');
            }
        } catch (error) {
            setError(error instanceof Error ? error.message : 'Erreur inattendue');
        } finally {
            setLoading(false);
        }
    }, [refreshStats]);

    // Alias pour refresh
    const refresh = useCallback(() => forceUpdate(), [forceUpdate]);

    // Actions de gestion
    const hideAnime = useCallback(async (animeId: string) => {
        const result = addToDoNotDisplay(animeId);
        refreshStats();
        
        // Retirer de la liste affichée si présente
        if (result.success && data) {
            setData(prev => prev ? prev.filter(anime => anime.id !== animeId) : prev);
        }
        
        return result;
    }, [data, refreshStats]);

    const restoreAnime = useCallback(async (animeId: string) => {
        const result = removeFromDoNotDisplay(animeId);
        refreshStats();
        
        // Recharger les données pour inclure l'anime restauré
        if (result.success) {
            await fetchAnimes();
        }
        
        return result;
    }, [fetchAnimes, refreshStats]);

    const markAseSeen = useCallback(async (animeId: string) => {
        const result = markNewAnimeAsSeen(animeId);
        refreshStats();
        
        return result;
    }, [refreshStats]);

    // Utilitaires
    const getFilteredData = useCallback((day?: string): AnimePlanning[] => {
        if (!data) return [];
        
        if (!day) return data;
        
        return data.filter(anime => 
            anime.dayOfWeek.toLowerCase() === day.toLowerCase()
        );
    }, [data]);

    const getTodayName = useCallback((): string => {
        const today = new Date();
        const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
        return dayNames[today.getDay()];
    }, []);

    // Auto-fetch au montage
    useEffect(() => {
        if (autoFetch) {
            fetchAnimes();
        }
    }, [autoFetch, fetchAnimes]);    // Refresh interval
    useEffect(() => {
        if (!refreshInterval || refreshInterval <= 0) return;

        const interval = setInterval(() => {
            // Vérifier le statut du cache
            const cacheStatus = getAnimeCacheStatus();
            // Déclencher un refresh si pas de cache ou si une mise à jour n'est pas en cours
            if (!cacheStatus.hasCache && !cacheStatus.updateInProgress) {
                fetchAnimes();
            }
        }, refreshInterval);

        return () => clearInterval(interval);
    }, [refreshInterval, fetchAnimes]);

    return {
        // Données
        data,
        newAnimes,
        loading,
        error,
        fromCache,
        stats,
        
        // Actions principales
        fetchAnimes,
        fetchTodayAnimes,
        forceUpdate,
        refresh,
        
        // Actions de gestion
        hideAnime,
        restoreAnime,
        markAseSeen,
        
        // Utilitaires
        getFilteredData,
        getTodayName,
        refreshStats
    };
};

export default useAnimeIntegrated;
