import { useState, useEffect, useCallback } from 'react';
import { AnimePlanning, AnimeStats, ViewMode, DayFilter, AnimeViewed } from '../types/anime.types';
import { animeApi } from '../services/api/anime.api';
import { animeStorage } from '../services/api/anime.storage';
import { getToWatchAnime, markAsToWatch, removeFromToWatch as removeFromToWatchUtil, isInToWatch as isInToWatchUtil } from '../utils/tabLogic/towatch.logic';

interface UseAnimeDataReturn {
    // Données
    current: AnimePlanning[];
    newAnimes: AnimePlanning[];
    old: AnimePlanning[];
    hidden: AnimePlanning[];
    towatch: AnimePlanning[];
    inProgress: AnimePlanning[];
    toWatchCompleted: AnimePlanning[];
    toWatchNotStarted: AnimePlanning[];
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
    reclassifyAndRefresh: (animeId: string) => void;
    updateFromLocalStorage: () => void;
    
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
    const [inProgress, setInProgress] = useState<AnimePlanning[]>([]);
    const [toWatchCompleted, setToWatchCompleted] = useState<AnimePlanning[]>([]);
    const [toWatchNotStarted, setToWatchNotStarted] = useState<AnimePlanning[]>([]);
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
        const hiddenAnimes = animeStorage.getHidden();
        const uniqueHiddenAnimes = Array.from(new Map(hiddenAnimes.map(item => [item.id, item])).values());
        setHidden(uniqueHiddenAnimes);
        setToWatch(animeStorage.getToWatch());
        setInProgress(animeStorage.getInProgress());
        setToWatchCompleted(animeStorage.getCompleted());
        setToWatchNotStarted(animeStorage.getToWatchNotStarted());
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

    // Reclassifier un anime spécifique et recharger les données
    const reclassifyAndRefresh = useCallback((animeId: string) => {
        try {
            animeStorage.reclassifyAnime(animeId);
            loadLocal();
            console.log(`🔄 Anime ${animeId} reclassifié et données rechargées`);
        } catch (err) {
            console.error('Erreur lors de la reclassification:', err);
        }
    }, [loadLocal]);

    // Sauvegarder et mettre à jour localStorage
    const updateFromLocalStorage = useCallback(() => {
        try {
            const raw = localStorage.getItem('anime_dashboard_v2');
            if (raw) {
                // Reclassifier TOUS les animes avant de charger
                animeStorage.reclassifyAllAnimes();
                loadLocal();
                console.log('🔄 Données mises à jour et reclassifiées depuis localStorage');
            }
        } catch (err) {
            console.error('Erreur lors de la mise à jour:', err);
        }
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
        // Reclassifier automatiquement au démarrage
        animeStorage.reclassifyViewedAnimes();
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
        towatch,
        inProgress,
        toWatchCompleted,
        toWatchNotStarted,
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
        reclassifyAndRefresh,
        updateFromLocalStorage,
        filterByDay,
        filterBySearch,
        getAnimesByViewMode,
    };
};
