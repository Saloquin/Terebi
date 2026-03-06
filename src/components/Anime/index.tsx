import React, { useState, useMemo } from 'react';
import { useAnimeData } from '../../hooks/useAnimeData';
import { ViewMode } from '../../types/anime.types';
import AnimeFilters from './AnimeFilters';
import AnimeList from './AnimeList';

export const AnimePage: React.FC = () => {
    const {
        current,
        newAnimes,
        old,
        hidden,
        loading,
        error,
        refresh,
        hideAnime,
        restoreAnime,
        markAsSeen,
        filterBySearch,
        getAnimesByViewMode,
    } = useAnimeData();

    const [viewMode, setViewMode] = useState<ViewMode>('planning');
    const [searchQuery, setSearchQuery] = useState('');

    // Get animes for current view
    const currentViewAnimes = useMemo(() => {
        let animes = getAnimesByViewMode(viewMode);
        animes = filterBySearch(animes, searchQuery);
        return animes;
    }, [viewMode, searchQuery, getAnimesByViewMode, filterBySearch]);

    // Counts for tabs
    const counts = useMemo(() => ({
        planning: current.length,
        nouveaux: newAnimes.length,
        anciens: old.length,
        masques: hidden.length,
    }), [current.length, newAnimes.length, old.length, hidden.length]);

    // Empty messages
    const getEmptyMessage = () => {
        switch (viewMode) {
            case 'planning': return 'Aucun anime dans le planning';
            case 'nouveaux': return 'Pas de nouveaux animes détectés';
            case 'anciens': return 'Pas d\'anciens animes';
            case 'masques': return 'Aucun anime masqué';
            default: return 'Aucun anime';
        }
    };

    return (
        <div className="min-h-screen bg-gray-100 dark:bg-gray-900 py-4 px-2 sm:px-4">
            <div className="w-full">
                {/* Header avec bouton refresh */}
                <div className="flex items-center justify-between mb-4">
                    <div>
                        <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-200">
                            📺 Planning Anime
                        </h1>
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
                        <span className={loading ? 'animate-spin' : ''}>🔄</span>
                        {loading ? 'Chargement...' : 'Rafraîchir'}
                    </button>
                </div>

                {/* Error message */}
                {error && (
                    <div className="mb-4 p-3 bg-red-100 dark:bg-red-900 border border-red-300 dark:border-red-700 rounded-lg text-red-700 dark:text-red-300 text-sm">
                        ⚠️ {error}
                    </div>
                )}

                {/* Filters */}
                <AnimeFilters
                    viewMode={viewMode}
                    onViewModeChange={setViewMode}
                    searchQuery={searchQuery}
                    onSearchChange={setSearchQuery}
                    counts={counts}
                />

                {/* Loading indicator */}
                {loading && (
                    <div className="flex justify-center py-8">
                        <div className="animate-spin text-4xl">🔄</div>
                    </div>
                )}

                {/* Anime List */}
                {!loading && (
                    <AnimeList
                        animes={currentViewAnimes}
                        onHide={viewMode !== 'masques' ? hideAnime : undefined}
                        onRestore={viewMode === 'masques' ? restoreAnime : undefined}
                        onMarkSeen={viewMode === 'nouveaux' ? markAsSeen : undefined}
                        showActions={true}
                        isHiddenList={viewMode === 'masques'}
                        isNewList={viewMode === 'nouveaux'}
                        isOldList={viewMode === 'anciens'}
                        groupByDay={viewMode === 'planning'}
                        emptyMessage={getEmptyMessage()}
                    />
                )}
            </div>
        </div>
    );
};

export default AnimePage;
