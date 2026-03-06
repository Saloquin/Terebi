/**
 * Hook React pour utiliser le système d'animes intégré avec filtrage automatique des doNotDisplay
 */

import { useState, useEffect, useCallback } from 'react';
import { AnimePlanning } from '../services/api/anime-planning';
import { 
    getAnimesWithFastDisplay, 
    getTodayAnimesWithCache,
    forceAnimeUpdate 
} from '../services/api/animeIntegrated';
import { 
    getCurrentAnimesByDay, 
    getCurrentStats,
    addToDoNotDisplay,
    removeFromDoNotDisplay,
    markNewAnimeAsSeen,
    getNewAnimes
} from '../services/api/animeStorage';

export interface UseAnimeIntegratedOptions {
    autoFetch?: boolean;
    fetchTodayOnly?: boolean;
}

export interface UseAnimeIntegratedReturn {
    // Données principales
    data: AnimePlanning[] | null;
    newAnimes: AnimePlanning[] | null;
    loading: boolean;
    error: string | null;
    
    // Informations de cache
    fromCache: boolean;
    needsUpdate: boolean;
    
    // Actions de récupération
    fetchAnimes: () => Promise<void>;
    fetchTodayAnimes: () => Promise<void>;
    forceUpdate: () => Promise<void>;
    fetchByDay: (day: string) => Promise<void>;
    
    // Actions de gestion
    hideAnime: (animeId: string) => Promise<{ success: boolean; message: string }>;
    restoreAnime: (animeId: string) => Promise<{ success: boolean; message: string }>;
    markAsViewed: (animeId: string) => Promise<{ success: boolean; message: string }>;
    
    // Statistiques
    stats: {
        totalCurrent: number;
        totalNew: number;
        totalOld: number;
        totalDoNotDisplay: number;
        animesByDay: Record<string, number>;
        newAnimesByDay: Record<string, number>;
        lastUpdate?: string;
    } | null;
    refreshStats: () => void;
}

export const useAnimeIntegratedFiltered = (options: UseAnimeIntegratedOptions = {}): UseAnimeIntegratedReturn => {
    const { autoFetch = true, fetchTodayOnly = false } = options;
    
    const [data, setData] = useState<AnimePlanning[] | null>(null);
    const [newAnimes, setNewAnimes] = useState<AnimePlanning[] | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [fromCache, setFromCache] = useState(false);
    const [needsUpdate, setNeedsUpdate] = useState(false);
    const [stats, setStats] = useState<UseAnimeIntegratedReturn['stats']>(null);

    // Rafraîchir les statistiques
    const refreshStats = useCallback(() => {
        const currentStats = getCurrentStats();
        setStats(currentStats);
    }, []);

    // Récupérer les nouveaux animes
    const refreshNewAnimes = useCallback(() => {
        const newAnimesResult = getNewAnimes();
        if (newAnimesResult.success) {
            setNewAnimes(newAnimesResult.data);
        }
    }, []);

    // Récupérer tous les animes avec affichage rapide
    const fetchAnimes = useCallback(async () => {
        setLoading(true);
        setError(null);
        
        try {
            const result = await getAnimesWithFastDisplay();
            
            if (result.success && result.data) {
                setData(result.data);
                setFromCache(result.fromCache);
                setNeedsUpdate(result.needsUpdate || false);
            } else {
                setError(result.error || 'Erreur lors de la récupération');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur inconnue');
        } finally {
            setLoading(false);
            refreshStats();
            refreshNewAnimes();
        }
    }, [refreshStats, refreshNewAnimes]);    // Récupérer les animes d'aujourd'hui
    const fetchTodayAnimes = useCallback(async () => {
        setLoading(true);
        setError(null);
        
        try {
            // Forcer un délai minimum pour montrer l'état de chargement
            const [result] = await Promise.all([
                getTodayAnimesWithCache(),
                new Promise(resolve => setTimeout(resolve, 300)) // 300ms minimum
            ]);
            
            if (result.success && result.data) {
                setData(result.data);
                setFromCache(result.fromCache);
                setNeedsUpdate(result.needsUpdate || false);
            } else {
                setError(result.error || 'Erreur lors de la récupération');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur inconnue');
        } finally {
            setLoading(false);
            refreshStats();
            refreshNewAnimes();
        }
    }, [refreshStats, refreshNewAnimes]);

    // Forcer la mise à jour depuis le réseau
    const forceUpdate = useCallback(async () => {
        setLoading(true);
        setError(null);
        
        try {
            const result = await forceAnimeUpdate();
            
            if (result.success && result.data) {
                setData(result.data);
                setFromCache(false);
                setNeedsUpdate(false);
            } else {
                setError(result.error || 'Erreur lors de la mise à jour forcée');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur inconnue');
        } finally {
            setLoading(false);
            refreshStats();
            refreshNewAnimes();
        }
    }, [refreshStats, refreshNewAnimes]);

    // Récupérer les animes d'un jour spécifique
    const fetchByDay = useCallback(async (day: string) => {
        setLoading(true);
        setError(null);
        
        try {
            const result = getCurrentAnimesByDay(day);
            
            if (result.success) {
                setData(result.data);
                setFromCache(true);
                setNeedsUpdate(false);
            } else {
                setError(result.error || 'Erreur lors de la récupération par jour');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur inconnue');
        } finally {
            setLoading(false);
            refreshStats();
        }
    }, [refreshStats]);

    // Cacher un anime (l'ajouter à doNotDisplay)
    const hideAnime = useCallback(async (animeId: string) => {
        const result = addToDoNotDisplay(animeId);
        
        if (result.success) {
            // Rafraîchir les données pour refléter le changement
            if (data) {
                setData(data.filter(anime => anime.id !== animeId));
            }
            refreshStats();
            refreshNewAnimes();
        }
        
        return result;
    }, [data, refreshStats, refreshNewAnimes]);

    // Restaurer un anime (le retirer de doNotDisplay)
    const restoreAnime = useCallback(async (animeId: string) => {
        const result = removeFromDoNotDisplay(animeId);
        
        if (result.success) {
            // Recharger les données pour inclure l'anime restauré
            await fetchAnimes();
        }
        
        return result;
    }, [fetchAnimes]);

    // Marquer un nouvel anime comme vu
    const markAsViewed = useCallback(async (animeId: string) => {
        const result = markNewAnimeAsSeen(animeId);
        
        if (result.success) {
            refreshNewAnimes();
            refreshStats();
            
            // Rafraîchir les données principales si nécessaire
            if (data) {
                await fetchAnimes();
            }
        }
        
        return result;
    }, [data, fetchAnimes, refreshNewAnimes, refreshStats]);    // Auto-fetch au montage
    useEffect(() => {
        if (autoFetch) {
            if (fetchTodayOnly) {
                fetchTodayAnimes();
            } else {
                fetchAnimes();
            }
        }
    }, [autoFetch, fetchTodayOnly, fetchAnimes, fetchTodayAnimes]);    // Auto-refresh géré maintenant par le Dashboard via useDashboardAnimeManager

    // Initialiser les stats
    useEffect(() => {
        refreshStats();
        refreshNewAnimes();
    }, [refreshStats, refreshNewAnimes]);

    return {
        // Données principales
        data,
        newAnimes,
        loading,
        error,
        
        // Informations de cache
        fromCache,
        needsUpdate,
        
        // Actions de récupération
        fetchAnimes,
        fetchTodayAnimes,
        forceUpdate,
        fetchByDay,
        
        // Actions de gestion
        hideAnime,
        restoreAnime,
        markAsViewed,
        
        // Statistiques
        stats,
        refreshStats
    };
};
