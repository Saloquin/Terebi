import { useState, useEffect, useCallback } from 'react';
import { AnimePlanning, AnimeStats, ViewMode, DayFilter, AnimeViewed } from '../types/anime.types';
import { animeApi } from '../services/api/anime.api';
import { animeStorage } from '../services/api/anime.storage';
import { syncNewSeasonsToWatch } from '../services/api/season-sync.service';
import { getToWatchAnime, markAsToWatch, removeFromToWatch as removeFromToWatchUtil, isInToWatch as isInToWatchUtil } from '../utils/tabLogic/towatch.logic';
import { STORAGE_CHANGE_EVENT } from '../utils/tabLogic/storage.utils';

interface UseAnimeDataReturn {
    // Données
    current: AnimePlanning[];
    newAnimes: AnimePlanning[];
    old: AnimePlanning[];
    hidden: AnimePlanning[];
    towatch: AnimePlanning[];
    viewed: AnimeViewed[];
    stats: AnimeStats;
    
    // États
    loading: boolean;
    error: string | null;
    
    // Actions
    refresh: () => Promise<void>;
    hideAnime: (id: string) => void;
    restoreAnime: (id: string) => void;
    markAsSeen: (id: string) => void;
    removeFromOld: (id: string) => void;
    removeFromToWatch: (id: string) => void;
    markAsToWatch: (anime: AnimePlanning) => void;
    markAsViewed: (anime: AnimePlanning, viewedSeasons?: string[]) => void;
    removeFromViewed: (id: string) => void;
    isInToWatch: (title: string) => boolean;
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
    const [towatch, setToWatch] = useState<AnimePlanning[]>([]);
    const [viewed, setViewed] = useState<AnimeViewed[]>([]);
    const [stats, setStats] = useState<AnimeStats>({
        totalCurrent: 0,
        totalNew: 0,
        totalOld: 0,
        totalHidden: 0,
        totalToWatch: 0,
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
        setToWatch(getToWatchAnime());
        setViewed(animeStorage.getViewed());
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
                await syncNewSeasonsToWatch(animeStorage.getViewed());
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

    const removeFromOld = useCallback((id: string) => {
        if (animeStorage.removeFromOld(id)) {
            loadLocal();
        }
    }, [loadLocal]);

    const removeFromToWatch = useCallback((id: string) => {
        removeFromToWatchUtil(id);
        loadLocal();
    }, [loadLocal]);

    const markAsToWatchAction = useCallback((anime: AnimePlanning) => {
        markAsToWatch(anime);
        loadLocal();
    }, [loadLocal]);

    const markAsViewedAction = useCallback((anime: AnimePlanning, viewedSeasons?: string[]) => {
        animeStorage.markAsViewed(anime, viewedSeasons);
        loadLocal();
    }, [loadLocal]);

    const removeFromViewedAction = useCallback((id: string) => {
        animeStorage.removeFromViewed(id);
        loadLocal();
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

    // Chargement initial + sync entre composants
    useEffect(() => {
        loadLocal();
        refresh();

        const handleStorageChange = () => loadLocal();
        window.addEventListener(STORAGE_CHANGE_EVENT, handleStorageChange);
        window.addEventListener('storage', handleStorageChange);

        const interval = setInterval(refresh, 5 * 60 * 1000);
        return () => {
            clearInterval(interval);
            window.removeEventListener(STORAGE_CHANGE_EVENT, handleStorageChange);
            window.removeEventListener('storage', handleStorageChange);
        };
    }, [loadLocal, refresh]);

    return {
        current,
        newAnimes,
        old,
        hidden,
        towatch,
        viewed,
        stats,
        loading,
        error,
        refresh,
        hideAnime,
        restoreAnime,
        markAsSeen,
        removeFromOld,
        removeFromToWatch,
        markAsToWatch: markAsToWatchAction,
        markAsViewed: markAsViewedAction,
        removeFromViewed: removeFromViewedAction,
        isInToWatch: isInToWatchUtil,
        clearNew,
        clearOld,
        clearAll,
        filterByDay,
        filterBySearch,
        getAnimesByViewMode,
    };
};
