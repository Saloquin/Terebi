/**
 * Hook React pour utiliser uniquement les données locales d'anime (localStorage)
 * Les cartes utilisent ce hook pour afficher les données locales
 * Le Dashboard se charge de faire les requêtes API globales
 */

import { useState, useEffect, useCallback } from 'react';
import { AnimePlanning } from '../services/api/anime-planning';
import { 
    getCurrentAnimes, 
    getCurrentAnimesByDay,
    getNewAnimes,
    addToDoNotDisplay,
    removeFromDoNotDisplay,
    markNewAnimeAsSeen
} from '../services/api/animeStorage';

export interface UseLocalAnimeDataOptions {
    fetchTodayOnly?: boolean;
    autoRefresh?: boolean;
}

export interface UseLocalAnimeDataReturn {
    // Données principales
    data: AnimePlanning[] | null;
    newAnimes: AnimePlanning[] | null;
    loading: boolean;
    error: string | null;
    
    // Actions de gestion
    hideAnime: (animeId: string) => Promise<{ success: boolean; message: string }>;
    restoreAnime: (animeId: string) => Promise<{ success: boolean; message: string }>;
    markAsViewed: (animeId: string) => Promise<{ success: boolean; message: string }>;
    
    // Rafraîchissement manuel
    refresh: () => void;
}

export const useLocalAnimeData = (options: UseLocalAnimeDataOptions = {}): UseLocalAnimeDataReturn => {
    const { fetchTodayOnly = false, autoRefresh = true } = options;
    
    const [data, setData] = useState<AnimePlanning[] | null>(null);
    const [newAnimes, setNewAnimes] = useState<AnimePlanning[] | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Fonction pour charger les données depuis localStorage
    const loadLocalData = useCallback(() => {
        try {
            setError(null);
            
            if (fetchTodayOnly) {
                const today = new Date();
                const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
                const todayName = dayNames[today.getDay()];
                
                const result = getCurrentAnimesByDay(todayName);
                if (result.success) {
                    setData(result.data || []);
                } else {
                    setData([]);
                }
            } else {
                const result = getCurrentAnimes();
                if (result.success) {
                    setData(result.data || []);
                } else {
                    setData([]);
                }
            }

            // Charger les nouveaux animes
            const newResult = getNewAnimes();
            if (newResult.success) {
                setNewAnimes(newResult.data || []);
            } else {
                setNewAnimes([]);
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur lors du chargement des données locales');
        }
    }, [fetchTodayOnly]);

    // Fonction de rafraîchissement
    const refresh = useCallback(() => {
        loadLocalData();
    }, [loadLocalData]);

    // Actions de gestion des animes
    const hideAnime = useCallback(async (animeId: string) => {
        try {
            const result = addToDoNotDisplay(animeId);
            if (result.success) {
                loadLocalData(); // Recharger après modification
            }
            return result;
        } catch (err) {
            return {
                success: false,
                message: err instanceof Error ? err.message : 'Erreur inconnue'
            };
        }
    }, [loadLocalData]);

    const restoreAnime = useCallback(async (animeId: string) => {
        try {
            const result = removeFromDoNotDisplay(animeId);
            if (result.success) {
                loadLocalData(); // Recharger après modification
            }
            return result;
        } catch (err) {
            return {
                success: false,
                message: err instanceof Error ? err.message : 'Erreur inconnue'
            };
        }
    }, [loadLocalData]);

    const markAsViewed = useCallback(async (animeId: string) => {
        try {
            const result = markNewAnimeAsSeen(animeId);
            if (result.success) {
                loadLocalData(); // Recharger après modification
            }
            return result;
        } catch (err) {
            return {
                success: false,
                message: err instanceof Error ? err.message : 'Erreur inconnue'
            };
        }
    }, [loadLocalData]);

    // Chargement initial
    useEffect(() => {
        loadLocalData();
    }, [loadLocalData]);    // Auto-refresh sur les changements de localStorage et les mises à jour du Dashboard
    useEffect(() => {
        if (autoRefresh) {
            const handleStorageChange = () => {
                loadLocalData();
            };

            const handleAnimeDataUpdate = () => {
                loadLocalData();
            };

            // Écouter les changements de localStorage
            window.addEventListener('storage', handleStorageChange);
            
            // Écouter les mises à jour depuis le Dashboard
            window.addEventListener('animeDataUpdated', handleAnimeDataUpdate);
            
            return () => {
                window.removeEventListener('storage', handleStorageChange);
                window.removeEventListener('animeDataUpdated', handleAnimeDataUpdate);
            };
        }
    }, [autoRefresh, loadLocalData]);

    return {
        data,
        newAnimes,
        loading,
        error,
        hideAnime,
        restoreAnime,
        markAsViewed,
        refresh
    };
};
