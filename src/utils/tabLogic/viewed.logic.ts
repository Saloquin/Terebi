import { AnimeViewed, AnimePlanning } from '../../types/anime.types';
import { readStorage, sortAnimesByDay, writeStorage } from './storage.utils';
import { TabActionBindings, TabHandlers, TabLogic } from './types';

export const getViewedAnimes = (): AnimeViewed[] => {
    const storage = readStorage();
    const visibleViewed = storage.viewed.filter(anime => !storage.hidden.includes(anime.id));
    return sortAnimesByDay(visibleViewed);
};

export const addToViewed = (anime: AnimePlanning): boolean => {
    const storage = readStorage();
    
    // Check if already in viewed
    if (storage.viewed.some(a => a.id === anime.id)) {
        return false;
    }

    const viewedAnime: AnimeViewed = {
        ...anime,
        viewedAt: new Date().toISOString(),
    };

    storage.viewed.push(viewedAnime);
    writeStorage(storage);
    return true;
};

export const removeFromViewed = (animeId: string): boolean => {
    const storage = readStorage();
    const viewedIndex = storage.viewed.findIndex(anime => anime.id === animeId);

    if (viewedIndex === -1) return false;

    storage.viewed.splice(viewedIndex, 1);
    storage.hidden = storage.hidden.filter(id => id !== animeId);
    writeStorage(storage);
    return true;
};

export const isAnimeViewed = (animeId: string): boolean => {
    const storage = readStorage();
    return storage.viewed.some(anime => anime.id === animeId);
};

export const getViewedEmptyMessage = (): string => 'Pas d\'animes vus';

export const getViewedBindings = ({ removeFromOld }: TabHandlers): TabActionBindings => ({
    onHide: undefined,
    onRestore: undefined,
    onMarkSeen: undefined,
    onRemoveOld: removeFromOld,
    isHiddenList: false,
    isNewList: false,
    isOldList: false,
});

export const getViewedTabLogic = (): TabLogic => ({
    mode: 'viewed' as any,
    emptyMessage: getViewedEmptyMessage(),
    bindActions: getViewedBindings,
});
