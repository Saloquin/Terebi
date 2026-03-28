import { AnimePlanning, AnimeStorage } from '../../types/anime.types';

export const STORAGE_KEY = 'anime_dashboard_v2';

const DAY_ORDER = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

export const createEmptyStorage = (): AnimeStorage => ({
    current: [],
    new: [],
    old: [],
    hidden: [],
    towatch: [],
    lastUpdate: new Date().toISOString(),
});

export const readStorage = (): AnimeStorage => {
    try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) return createEmptyStorage();
        const storage = JSON.parse(raw) as AnimeStorage;
        // Migration: ajouter towatch s'il n'existe pas
        if (!storage.towatch) {
            storage.towatch = [];
        }
        return storage;
    } catch {
        return createEmptyStorage();
    }
};

export const writeStorage = (storage: AnimeStorage): void => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(storage));
};

const getDayIndex = (dayOfWeek?: string): number => {
    if (!dayOfWeek) return Number.MAX_SAFE_INTEGER;
    const idx = DAY_ORDER.indexOf(dayOfWeek.toLowerCase());
    return idx === -1 ? Number.MAX_SAFE_INTEGER : idx;
};

export const sortAnimesByDay = (animes: AnimePlanning[]): AnimePlanning[] => {
    return [...animes].sort((firstAnime, secondAnime) => {
        const dayDelta = getDayIndex(firstAnime.dayOfWeek) - getDayIndex(secondAnime.dayOfWeek);
        if (dayDelta !== 0) return dayDelta;

        const firstTime = firstAnime.time || '99h99';
        const secondTime = secondAnime.time || '99h99';
        const timeDelta = firstTime.localeCompare(secondTime);
        if (timeDelta !== 0) return timeDelta;

        return firstAnime.title.localeCompare(secondAnime.title, 'fr', { sensitivity: 'base' });
    });
};
