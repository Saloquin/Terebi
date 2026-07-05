import { AnimePlanning, AnimeStorage } from '../../types/anime.types';

export const STORAGE_KEY = 'anime_dashboard_v2';

const DAY_ORDER = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

export const createEmptyStorage = (): AnimeStorage => ({
    current: [],
    new: [],
    old: [],
    hidden: [],
    towatch: [],
    inprogress: [],
    completed: [],
    viewed: [],
    lastUpdate: new Date().toISOString(),
});

// Aide à la migration des IDs
const migrateAnimeId = (anime: AnimePlanning): string => {
    return `${anime.title.toLowerCase().replace(/[^a-z0-9]/g, '')}-${(anime.type || 'vostfr').toLowerCase()}`;
};

export const readStorage = (): AnimeStorage => {
    try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) return createEmptyStorage();
        const storage = JSON.parse(raw) as AnimeStorage;
        
        let needsSave = false;

        // Migration: ajouter les clés manquantes
        if (!storage.towatch) { storage.towatch = []; needsSave = true; }
        if (!storage.inprogress) { storage.inprogress = []; needsSave = true; }
        if (!storage.completed) { storage.completed = []; needsSave = true; }
        if (!storage.viewed) { storage.viewed = []; needsSave = true; }

        // Migration 2: Uniformiser les ID instables (ex: lundi-onepiece-18h-vostfr -> onepiece-vostfr)
        // On vérifie si le premier item de 'current' a un '-no-time-' ou s'il commence par un jour (lundi-, mardi-, etc)
        // Mais plus simple: on recalcule TOUS les IDs localement et on met à jour hidden
        
        let idMapping: Record<string, string> = {};

        const migrateList = (list: AnimePlanning[]) => {
            if (!list) return [];
            return list.map(anime => {
                const newId = migrateAnimeId(anime);
                if (anime.id !== newId) {
                    idMapping[anime.id] = newId;
                    anime.id = newId;
                    needsSave = true;
                }
                return anime;
            });
        };

        storage.current = migrateList(storage.current || []);
        storage.new = migrateList(storage.new || []);
        storage.old = migrateList(storage.old || []);
        storage.towatch = migrateList(storage.towatch || []);
        storage.inprogress = migrateList(storage.inprogress || []);
        storage.completed = migrateList(storage.completed || []);
        storage.viewed = migrateList(storage.viewed || []);

        // Mettre à jour hidden
        if (Object.keys(idMapping).length > 0 || (storage.hidden && storage.hidden.some(h => /^(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)-/.test(h)))) {
            if (storage.hidden) {
                storage.hidden = storage.hidden.map(oldId => {
                    if (idMapping[oldId]) return idMapping[oldId];
                    // Tente d'extraire si ça vient d'un vieil ID non mappé (ex: disparu des listes)
                    const oldMatch = oldId.match(/^(?:lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)-(.+)-(?:\d+h\d+|no-time)-([a-z]+)$/);
                    if (oldMatch) {
                        return `${oldMatch[1]}-${oldMatch[2]}`;
                    }
                    return oldId;
                });
                // Dédoublonner hidden
                storage.hidden = Array.from(new Set(storage.hidden));
                needsSave = true;
            }
        }

        // Dédoublonner également les listes (un même ID ne doit pas être en double dans une liste)
        if (needsSave) {
            const deduplicate = <T extends AnimePlanning>(list: T[]): T[] => {
                const seen = new Set<string>();
                return list.filter(a => {
                    if (seen.has(a.id)) return false;
                    seen.add(a.id);
                    return true;
                });
            };
            
            storage.current = deduplicate(storage.current);
            storage.new = deduplicate(storage.new);
            storage.old = deduplicate(storage.old);
            storage.towatch = deduplicate(storage.towatch);
            storage.inprogress = deduplicate(storage.inprogress);
            storage.completed = deduplicate(storage.completed);
            storage.viewed = deduplicate(storage.viewed);
        }

        if (needsSave) {
            writeStorage(storage);
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
