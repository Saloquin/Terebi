import { AnimePlanning } from '../../types/anime.types';
import { readStorage, sortAnimesByDay, writeStorage } from './storage.utils';
import { TabActionBindings, TabHandlers, TabLogic } from './types';

export const getOldAnime = (): AnimePlanning[] => {
    const storage = readStorage();
    const visibleOld = storage.old.filter(anime => !storage.hidden.includes(anime.id));
    return sortAnimesByDay(visibleOld);
};

export const removeOldAnime = (animeId: string): boolean => {
    const storage = readStorage();
    const oldIndex = storage.old.findIndex(anime => anime.id === animeId);

    if (oldIndex === -1) return false;

    storage.old.splice(oldIndex, 1);
    storage.hidden = storage.hidden.filter(id => id !== animeId);
    writeStorage(storage);
    return true;
};

export const getOldEmptyMessage = (): string => 'Pas d\'anciens animes';

export const getOldBindings = ({ removeFromOld }: TabHandlers): TabActionBindings => ({
    onHide: undefined,
    onRestore: undefined,
    onMarkSeen: undefined,
    onRemoveOld: removeFromOld,
    isHiddenList: false,
    isNewList: false,
    isOldList: true,
});

export const getOldTabLogic = (): TabLogic => ({
    mode: 'anciens',
    emptyMessage: getOldEmptyMessage(),
    bindActions: getOldBindings,
});
