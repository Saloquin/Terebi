import { AnimePlanning } from '../../types/anime.types';
import { readStorage, sortAnimesByDay, writeStorage } from './storage.utils';
import { TabActionBindings, TabHandlers, TabLogic } from './types';

export const getHiddenAnime = (): AnimePlanning[] => {
    const storage = readStorage();
    const allAnimes = [...storage.current, ...storage.new, ...storage.old];
    const hiddenAnimes = allAnimes.filter(anime => storage.hidden.includes(anime.id));
    return sortAnimesByDay(hiddenAnimes);
};

export const restoreHiddenAnime = (animeId: string): boolean => {
    const storage = readStorage();
    const hiddenIndex = storage.hidden.indexOf(animeId);

    if (hiddenIndex === -1) return false;

    storage.hidden.splice(hiddenIndex, 1);
    writeStorage(storage);
    return true;
};

export const getHiddenEmptyMessage = (): string => 'Aucun anime masqué';

export const getHiddenBindings = ({ restoreAnime }: TabHandlers): TabActionBindings => ({
    onHide: undefined,
    onRestore: restoreAnime,
    onMarkSeen: undefined,
    onRemoveOld: undefined,
    isHiddenList: true,
    isNewList: false,
    isOldList: false,
});

export const getHiddenTabLogic = (): TabLogic => ({
    mode: 'masques',
    emptyMessage: getHiddenEmptyMessage(),
    bindActions: getHiddenBindings,
});
