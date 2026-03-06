import { useState, useEffect, useCallback } from 'react';
import { AnimePlanning, PlanningResult, animePlanningService } from '../services/api/anime-planning';

interface UseAnimePlanningOptions {
    autoFetch?: boolean;
    day?: string; // Si spécifié, récupère seulement ce jour
}

export function useAnimePlanning(options: UseAnimePlanningOptions = {}) {
    const { autoFetch = false, day } = options;
    
    const [data, setData] = useState<AnimePlanning[] | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [lastFetch, setLastFetch] = useState<Date | null>(null);

    const fetchPlanning = useCallback(async () => {
        setLoading(true);
        setError(null);

        try {
            let result: PlanningResult;
            
            if (day) {
                result = await animePlanningService.getAnimesByDay(day);
            } else {
                result = await animePlanningService.getPlanning();
            }

            if (result.success && result.data) {
                setData(result.data);
                setLastFetch(new Date());
            } else {
                setError(result.error || 'Erreur inconnue');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur de réseau');
        } finally {
            setLoading(false);
        }
    }, [day]);

    const fetchTodayAnimes = useCallback(async () => {
        setLoading(true);
        setError(null);

        try {
            const result = await animePlanningService.getTodayAnimes();
            
            if (result.success && result.data) {
                setData(result.data);
                setLastFetch(new Date());
            } else {
                setError(result.error || 'Erreur inconnue');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur de réseau');
        } finally {
            setLoading(false);
        }
    }, []);

    // Auto-fetch au montage
    useEffect(() => {
        if (autoFetch) {
            fetchPlanning();
        }
    }, [autoFetch, fetchPlanning]);

    return {
        data,
        loading,
        error,
        lastFetch,
        fetchPlanning,
        fetchTodayAnimes,
        refresh: fetchPlanning,
        // Helpers
        isEmpty: !loading && !error && (!data || data.length === 0),
        hasData: !loading && !error && data && data.length > 0,
    };
}
