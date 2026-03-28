import React, { useState, useMemo, useEffect } from 'react';
import { useAnimeData } from '../../hooks/useAnimeData';
import { ViewMode, AnimePlanning } from '../../types/anime.types';
import { configApi } from '../../services/api/config.api';
import { migrateStorageDomain } from '../../services/api/domain-migration';
import { getTabLogic } from '../../utils/tabLogic';
import AnimeFilters from './AnimeFilters';
import AnimeList from './AnimeList';
import LiveTvIcon from '@mui/icons-material/LiveTv';
import LanguageIcon from '@mui/icons-material/Language';
import CloseIcon from '@mui/icons-material/Close';
import RefreshIcon from '@mui/icons-material/Refresh';
import WarningAmberIcon from '@mui/icons-material/WarningAmber';
import SyncIcon from '@mui/icons-material/Sync';

const EXT_STORAGE_KEY = 'anime_extension';

interface AnimePageProps {
    selectedAnime?: AnimePlanning | null;
}

export const AnimePage: React.FC<AnimePageProps> = ({ selectedAnime = null }) => {
    const {
        current,
        newAnimes,
        old,
        hidden,
        towatch,
        loading,
        error,
        refresh,
        hideAnime,
        restoreAnime,
        markAsSeen,
        removeFromOld,
        removeFromToWatch,
        clearNew,
        clearOld,
        filterBySearch,
        getAnimesByViewMode,
        markAsToWatch,
    } = useAnimeData();

    const [viewMode, setViewMode] = useState<ViewMode>('planning');
    const [searchQuery, setSearchQuery] = useState('');

    // Extension state
    const [extension, setExtension] = useState(() => localStorage.getItem(EXT_STORAGE_KEY) || 'to');
    const [detectInfo, setDetectInfo] = useState<string | null>(null);

    // Au démarrage : détecter automatiquement l'extension active et migrer si besoin
    useEffect(() => {
        const currentLocalExt = localStorage.getItem(EXT_STORAGE_KEY) || 'to';
        configApi.detectExtension()
            .then(config => {
                if (config.previousExtension && config.previousExtension !== config.extension) {
                    // L'extension a changé : migrer le localStorage
                    migrateStorageDomain(currentLocalExt, config.extension);
                    setDetectInfo(`Domaine migré : .${config.previousExtension} → .${config.extension}`);
                } else if (currentLocalExt !== config.extension) {
                    // LocalStorage différent du backend : migrer silencieusement
                    migrateStorageDomain(currentLocalExt, config.extension);
                }
                setExtension(config.extension);
                localStorage.setItem(EXT_STORAGE_KEY, config.extension);
            })
            .catch(() => {
                // Fallback : utiliser getConfig sans détection
                configApi.getConfig().then(c => {
                    setExtension(c.extension);
                    localStorage.setItem(EXT_STORAGE_KEY, c.extension);
                }).catch(() => {});
            });
    }, []);

    // Get animes for current view
    const currentViewAnimes = useMemo(() => {
        let animes = getAnimesByViewMode(viewMode);
        animes = filterBySearch(animes, searchQuery);
        
        // Filter by selectedAnime if provided
        if (selectedAnime) {
            animes = animes.filter(anime => 
                anime.title.toLowerCase() === selectedAnime.title.toLowerCase() ||
                anime.id === selectedAnime.id
            );
        }
        
        return animes;
    }, [viewMode, searchQuery, getAnimesByViewMode, filterBySearch, selectedAnime]);

    // Counts for tabs
    const counts = useMemo(() => ({
        planning: current.length,
        nouveaux: newAnimes.length,
        anciens: old.length,
        masques: hidden.length,
    }), [current.length, newAnimes.length, old.length, hidden.length]);

    const tabLogic = getTabLogic(viewMode);
    const tabActions = tabLogic.bindActions({
        hideAnime,
        restoreAnime,
        markAsSeen,
        removeFromOld,
    });

    return (
        <div className="h-screen flex flex-col bg-gray-100 dark:bg-gray-900 py-3 px-2 sm:px-4">
            {/* Header */}
            <div className="flex items-center justify-between mb-3 flex-shrink-0">
                <div className="flex items-center gap-4">
                    <h1 className="text-xl font-bold text-gray-800 dark:text-gray-200 flex items-center gap-2">
                        <LiveTvIcon fontSize="small" /> Planning Anime
                    </h1>
                    <div className="text-gray-500 dark:text-gray-400 text-sm flex items-center gap-1">
                        <LanguageIcon sx={{ fontSize: 16 }} /> anime-sama.<span className="text-blue-500 font-bold">{extension}</span>
                    </div>
                </div>
                <button
                    onClick={refresh}
                    disabled={loading}
                    className={`
                        px-3 py-1.5 bg-blue-600 text-white rounded-lg text-sm font-medium
                        hover:bg-blue-700 transition-colors flex items-center gap-2
                        ${loading ? 'opacity-50 cursor-not-allowed' : ''}
                    `}
                >
                    <RefreshIcon sx={{ fontSize: 18 }} className={loading ? 'animate-spin' : ''} />
                    {loading ? 'Chargement...' : 'Rafraîchir'}
                </button>
            </div>

            {/* Migration info banner */}
            {detectInfo && (
                <div className="mb-3 p-2 bg-blue-100 dark:bg-blue-900/40 border border-blue-300 dark:border-blue-700 rounded-lg text-blue-700 dark:text-blue-300 text-sm flex items-center justify-between flex-shrink-0">
                    <span className="flex items-center gap-2"><SyncIcon sx={{ fontSize: 16 }} /> {detectInfo}</span>
                    <button onClick={() => setDetectInfo(null)} className="text-blue-400 hover:text-blue-600"><CloseIcon sx={{ fontSize: 14 }} /></button>
                </div>
            )}

            {/* Error message */}
            {error && (
                <div className="mb-3 p-3 bg-red-100 dark:bg-red-900 border border-red-300 dark:border-red-700 rounded-lg text-red-700 dark:text-red-300 text-sm flex-shrink-0">
                    <WarningAmberIcon sx={{ fontSize: 18 }} /> {error}
                </div>
            )}

            {/* Filters */}
            <div className="flex-shrink-0">
                <AnimeFilters
                    viewMode={viewMode}
                    onViewModeChange={setViewMode}
                    searchQuery={searchQuery}
                    onSearchChange={setSearchQuery}
                    counts={counts}
                    onClear={viewMode === 'nouveaux' ? clearNew : viewMode === 'anciens' ? clearOld : undefined}
                />
            </div>

            {/* Loading indicator */}
            {loading && (
                <div className="flex justify-center py-8 flex-shrink-0">
                    <RefreshIcon sx={{ fontSize: 48 }} className="animate-spin" />
                </div>
            )}

            {/* Anime List - fills remaining height */}
            {!loading && (
                <div className="flex-1 min-h-0 overflow-hidden">
                    <AnimeList
                        animes={currentViewAnimes}
                        onHide={tabActions.onHide}
                        onRestore={tabActions.onRestore}
                        onMarkSeen={tabActions.onMarkSeen}
                        onRemoveOld={tabActions.onRemoveOld}
                        onAddToWatch={markAsToWatch}
                        onRemoveFromToWatch={removeFromToWatch}
                        showActions={true}
                        isHiddenList={tabActions.isHiddenList}
                        isNewList={tabActions.isNewList}
                        isOldList={tabActions.isOldList}
                        groupByDay={true}
                        emptyMessage={tabLogic.emptyMessage}
                        toWatchTitles={towatch.map(a => a.title)}
                    />
                </div>
            )}
        </div>
    );
};

export default AnimePage;
