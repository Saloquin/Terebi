/**
 * Hook React pour gérer les requêtes API globales depuis le Dashboard
 * Ce hook fait les requêtes réseau et met à jour le localStorage
 */

import { useState, useEffect, useCallback } from 'react';
import { getAnimesWithFastDisplay, forceAnimeUpdate } from '../services/api/animeIntegrated';

export interface UseDashboardAnimeManagerOptions {
    autoRefreshInterval?: number; // en minutes, par défaut 5
    initialFetch?: boolean;
}

export interface UseDashboardAnimeManagerReturn {
    // États
    isUpdating: boolean;
    lastUpdate: Date | null;
    error: string | null;
    
    // Actions
    forceUpdate: () => Promise<void>;
    
    // Info
    totalAnimes: number;
}

export const useDashboardAnimeManager = (options: UseDashboardAnimeManagerOptions = {}): UseDashboardAnimeManagerReturn => {
    const { autoRefreshInterval = 5, initialFetch = true } = options;
    
    const [isUpdating, setIsUpdating] = useState(false);
    const [lastUpdate, setLastUpdate] = useState<Date | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [totalAnimes, setTotalAnimes] = useState(0);

    // Fonction pour effectuer la mise à jour globale
    const performUpdate = useCallback(async () => {
        setIsUpdating(true);
        setError(null);
        
        try {
            const result = await getAnimesWithFastDisplay();
            
            if (result.success && result.data) {
                setTotalAnimes(result.data.length);
                setLastUpdate(new Date());
                
                // Déclencher un événement personnalisé pour notifier les cartes
                window.dispatchEvent(new CustomEvent('animeDataUpdated', { 
                    detail: { 
                        animes: result.data,
                        timestamp: new Date()
                    } 
                }));
            } else {
                setError(result.error || 'Erreur lors de la mise à jour');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur inconnue');
        } finally {
            setIsUpdating(false);
        }
    }, []);

    // Force update (pour bouton manuel)
    const forceUpdate = useCallback(async () => {
        setIsUpdating(true);
        setError(null);
        
        try {
            const result = await forceAnimeUpdate();
            
            if (result.success && result.data) {
                setTotalAnimes(result.data.length);
                setLastUpdate(new Date());
                
                // Déclencher un événement personnalisé pour notifier les cartes
                window.dispatchEvent(new CustomEvent('animeDataUpdated', { 
                    detail: { 
                        animes: result.data,
                        timestamp: new Date()
                    } 
                }));
            } else {
                setError(result.error || 'Erreur lors de la mise à jour forcée');
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur inconnue');
        } finally {
            setIsUpdating(false);
        }
    }, []);

    // Fetch initial au montage
    useEffect(() => {
        if (initialFetch) {
            performUpdate();
        }
    }, [initialFetch, performUpdate]);

    // Auto-refresh à intervalles réguliers
    useEffect(() => {
        const interval = setInterval(() => {
            performUpdate();
        }, autoRefreshInterval * 60 * 1000); // Convertir minutes en millisecondes

        return () => clearInterval(interval);
    }, [autoRefreshInterval, performUpdate]);

    return {
        isUpdating,
        lastUpdate,
        error,
        forceUpdate,
        totalAnimes
    };
};
