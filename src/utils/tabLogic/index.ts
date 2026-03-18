import { ViewMode } from '../../types/anime.types';
import { getHiddenTabLogic } from './hidden.logic';
import { getNewTabLogic } from './new.logic';
import { getOldTabLogic } from './old.logic';
import { getPlanningTabLogic } from './planning.logic';
import { TabLogic } from './types';

const TAB_LOGIC_FACTORIES: Record<ViewMode, () => TabLogic> = {
    planning: getPlanningTabLogic,
    nouveaux: getNewTabLogic,
    anciens: getOldTabLogic,
    masques: getHiddenTabLogic,
};

export const getTabLogic = (mode: ViewMode): TabLogic => TAB_LOGIC_FACTORIES[mode]();

export * from './planning.logic';
export * from './new.logic';
export * from './old.logic';
export * from './hidden.logic';
export * from './types';
