import { AnimePlanning } from '../../types/anime.types';
import { readStorage, sortAnimesByDay, writeStorage } from './storage.utils';
import { TabActionBindings, TabHandlers, TabLogic } from './types';

export const getNewAnime = (): AnimePlanning[] => {
    const storage = readStorage();
    const visibleNew = storage.new.filter(anime => !storage.hidden.includes(anime.id));
    return sortAnimesByDay(visibleNew);
};

export const newMarkAsSeen = (animeId: string): boolean => {
    const storage = readStorage();
    const index = storage.new.findIndex(anime => anime.id === animeId);

    if (index === -1) return false;

    storage.new.splice(index, 1);
    writeStorage(storage);
    return true;
};

export const getNewEmptyMessage = (): string => 'Pas de nouveaux animes détectés';

export const getNewBindings = ({ markAsSeen }: TabHandlers): TabActionBindings => ({
    onHide: undefined,
    onRestore: undefined,
    onMarkSeen: markAsSeen,
    onRemoveOld: undefined,
    isHiddenList: false,
    isNewList: true,
    isOldList: false,
});

export const getNewTabLogic = (): TabLogic => ({
    mode: 'nouveaux',
    emptyMessage: getNewEmptyMessage(),
    bindActions: getNewBindings,
});
