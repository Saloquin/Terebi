import { ViewMode } from '../../types/anime.types';

export interface TabHandlers {
    hideAnime: (id: string) => void;
    restoreAnime: (id: string) => void;
    markAsSeen: (id: string) => void;
    removeFromOld: (id: string) => void;
}

export interface TabActionBindings {
    onHide?: (id: string) => void;
    onRestore?: (id: string) => void;
    onMarkSeen?: (id: string) => void;
    onRemoveOld?: (id: string) => void;
    isHiddenList: boolean;
    isNewList: boolean;
    isOldList: boolean;
}

export interface TabLogic {
    mode: ViewMode;
    emptyMessage: string;
    bindActions: (handlers: TabHandlers) => TabActionBindings;
}
