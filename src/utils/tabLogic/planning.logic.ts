import { AnimePlanning } from '../../types/anime.types';
import { readStorage, sortAnimesByDay, writeStorage } from './storage.utils';
import { TabActionBindings, TabHandlers, TabLogic } from './types';

export const getPlanningAnime = (): AnimePlanning[] => {
    const storage = readStorage();
    const visiblePlanning = storage.current.filter(anime => !storage.hidden.includes(anime.id));
    return sortAnimesByDay(visiblePlanning);
};

export const planningMarkAsSeen = (animeId: string): boolean => {
    const storage = readStorage();
    const index = storage.new.findIndex(anime => anime.id === animeId);

    if (index === -1) return false;

    storage.new.splice(index, 1);
    writeStorage(storage);
    return true;
};

export const getPlanningEmptyMessage = (): string => 'Aucun anime dans le planning';

export const getPlanningBindings = ({ hideAnime }: TabHandlers): TabActionBindings => ({
    onHide: hideAnime,
    onRestore: undefined,
    onMarkSeen: undefined,
    onRemoveOld: undefined,
    isHiddenList: false,
    isNewList: false,
    isOldList: false,
});

export const getPlanningTabLogic = (): TabLogic => ({
    mode: 'planning',
    emptyMessage: getPlanningEmptyMessage(),
    bindActions: getPlanningBindings,
});
