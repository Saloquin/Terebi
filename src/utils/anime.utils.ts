import { readStorage } from './tabLogic/storage.utils';
import { AnimePlanning } from '../types/anime.types';

/**
 * Extract catalogue slug from a full or relative anime-sama URL.
 */
export const extractCatalogSlug = (url?: string): string => {
    if (!url) return '';
    const match = url.match(/\/catalogue\/([^/?#]+)/);
    return match?.[1] || '';
};

/**
 * Find an anime across all localStorage lists by catalogue slug.
 */
export const findAnimeBySlug = (slug: string): AnimePlanning | null => {
    if (!slug) return null;

    const storage = readStorage();
    const all = [
        ...storage.current,
        ...storage.towatch,
        ...(storage.viewed || []),
        ...storage.new,
        ...storage.old,
    ];

    return all.find(a => extractCatalogSlug(a.fullUrl || a.url) === slug) || null;
};

/** Minutes per episode (standard) and per film */
export const EPISODE_MINUTES = 24;
export const FILM_MINUTES = 120;

export const formatWatchTime = (totalMinutes: number): string => {
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours === 0) return `${minutes} min`;
    return minutes > 0 ? `${hours}h${minutes.toString().padStart(2, '0')}` : `${hours}h`;
};
