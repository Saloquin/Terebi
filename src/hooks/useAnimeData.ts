import { useState, useEffect, useCallback } from 'react';
import { AnimePlanning, AnimeStats, ViewMode, DayFilter } from '../types/anime.types';
import { animeApi } from '../services/api/anime.api';
import { animeStorage } from '../services/api/anime.storage';

interface UseAnimeDataReturn {
    // Données
    current: AnimePlanning[];
    newAnimes: AnimePlanning[];
    old: AnimePlanning[];
    hidden: AnimePlanning[];
    stats: AnimeStats;
    
    // États
    loading: boolean;
    error: string | null;
    
    // Actions
    refresh: () => Promise<void>;
    hideAnime: (id: string) => void;
    restoreAnime: (id: string) => void;
    markAsSeen: (id: string) => void;
    clearNew: () => void;
    clearOld: () => void;
    clearAll: () => void;
    
    // Filtres
    filterByDay: (animes: AnimePlanning[], day: DayFilter) => AnimePlanning[];
    filterBySearch: (animes: AnimePlanning[], search: string) => AnimePlanning[];
    getAnimesByViewMode: (mode: ViewMode) => AnimePlanning[];
}

export const useAnimeData = (): UseAnimeDataReturn => {
    const [current, setCurrent] = useState<AnimePlanning[]>([]);
    const [newAnimes, setNewAnimes] = useState<AnimePlanning[]>([]);
    const [old, setOld] = useState<AnimePlanning[]>([]);
    const [hidden, setHidden] = useState<AnimePlanning[]>([]);
    const [stats, setStats] = useState<AnimeStats>({
        totalCurrent: 0,
        totalNew: 0,
        totalOld: 0,
        totalHidden: 0,
        byDay: {},
    });
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Charger les données locales
    const loadLocal = useCallback(() => {
        console.log('📂 Chargement des données locales...');
        setCurrent(animeStorage.getCurrent());
        setNewAnimes(animeStorage.getNew());
        setOld(animeStorage.getOld());
        setHidden(animeStorage.getHidden());
        setStats(animeStorage.getStats());
    }, []);

    // Rafraîchir depuis l'API
    const refresh = useCallback(async () => {
        setLoading(true);
        setError(null);

        try {
            console.log('🔄 Rafraîchissement depuis l\'API...');
            const response = await animeApi.getAll();
            
            if (response.success && response.data) {
                animeStorage.syncWithApi(response.data);
                loadLocal();
            } else {
                setError(response.error || 'Erreur lors de la récupération');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur inconnue');
        } finally {
            setLoading(false);
        }
    }, [loadLocal]);

    // Actions
    const hideAnime = useCallback((id: string) => {
        if (animeStorage.hideAnime(id)) {
            loadLocal();
        }
    }, [loadLocal]);

    const restoreAnime = useCallback((id: string) => {
        if (animeStorage.restoreAnime(id)) {
            loadLocal();
        }
    }, [loadLocal]);

    const markAsSeen = useCallback((id: string) => {
        if (animeStorage.markAsSeen(id)) {
            loadLocal();
        }
    }, [loadLocal]);

    const clearNew = useCallback(() => {
        animeStorage.clearNew();
        loadLocal();
    }, [loadLocal]);

    const clearOld = useCallback(() => {
        animeStorage.clearOld();
        loadLocal();
    }, [loadLocal]);

    const clearAll = useCallback(() => {
        animeStorage.clearAll();
        loadLocal();
    }, [loadLocal]);

    // Filtres
    const filterByDay = useCallback((animes: AnimePlanning[], day: DayFilter): AnimePlanning[] => {
        if (day === 'tous') return animes;
        
        if (day === 'aujourd\'hui') {
            const dayNames = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
            const today = dayNames[new Date().getDay()];
            return animes.filter(a => a.dayOfWeek.toLowerCase() === today);
        }
        
        return animes.filter(a => a.dayOfWeek.toLowerCase() === day);
    }, []);

    const filterBySearch = useCallback((animes: AnimePlanning[], search: string): AnimePlanning[] => {
        if (!search.trim()) return animes;
        
        const searchLower = search.toLowerCase();
        return animes.filter(a =>
            a.title.toLowerCase().includes(searchLower) ||
            a.dayOfWeek.toLowerCase().includes(searchLower) ||
            a.time?.toLowerCase().includes(searchLower)
        );
    }, []);

    const getAnimesByViewMode = useCallback((mode: ViewMode): AnimePlanning[] => {
        switch (mode) {
            case 'planning': return current;
            case 'nouveaux': return newAnimes;
            case 'anciens': return old;
            case 'masques': return hidden;
            default: return [];
        }
    }, [current, newAnimes, old, hidden]);

    // Chargement initial
    useEffect(() => {
        loadLocal();
        refresh();
        
        // Rafraîchissement auto toutes les 5 minutes
        const interval = setInterval(refresh, 5 * 60 * 1000);
        return () => clearInterval(interval);
    }, [loadLocal, refresh]);

    return {
        current,
        newAnimes,
        old,
        hidden,
        stats,
        loading,
        error,
        refresh,
        hideAnime,
        restoreAnime,
        markAsSeen,
        clearNew,
        clearOld,
        clearAll,
        filterByDay,
        filterBySearch,
        getAnimesByViewMode,
    };
};
