import React, { useState, useMemo, useEffect } from 'react';
import { useAnimeData } from '../../hooks/useAnimeData';
import { ViewMode } from '../../types/anime.types';
import { configApi } from '../../services/api/config.api';
import { migrateStorageDomain } from '../../services/api/domain-migration';
import AnimeFilters from './AnimeFilters';
import AnimeList from './AnimeList';
import LiveTvIcon from '@mui/icons-material/LiveTv';
import LanguageIcon from '@mui/icons-material/Language';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import RefreshIcon from '@mui/icons-material/Refresh';
import WarningAmberIcon from '@mui/icons-material/WarningAmber';
import SyncIcon from '@mui/icons-material/Sync';

const EXT_STORAGE_KEY = 'anime_extension';

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
        clearNew,
        clearOld,
        filterBySearch,
        getAnimesByViewMode,
    } = useAnimeData();

    const [viewMode, setViewMode] = useState<ViewMode>('planning');
    const [searchQuery, setSearchQuery] = useState('');

    // Extension state
    const [extension, setExtension] = useState(() => localStorage.getItem(EXT_STORAGE_KEY) || 'to');
    const [editingExt, setEditingExt] = useState(false);
    const [inputExt, setInputExt] = useState('');
    const [savingExt, setSavingExt] = useState(false);
    const [detecting, setDetecting] = useState(false);
    const [detectInfo, setDetectInfo] = useState<string | null>(null);

    // Au démarrage : détecter automatiquement l'extension active et migrer si besoin
    useEffect(() => {
        const currentLocalExt = localStorage.getItem(EXT_STORAGE_KEY) || 'to';
        setDetecting(true);
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
            })
            .finally(() => setDetecting(false));
    }, []);

    const handleSaveExtension = async () => {
        if (!inputExt.trim()) return;
        setSavingExt(true);
        try {
            const config = await configApi.setExtension(inputExt.trim());
            setExtension(config.extension);
            localStorage.setItem(EXT_STORAGE_KEY, config.extension);
            setEditingExt(false);
        } catch (e) {
            alert(e instanceof Error ? e.message : 'Erreur');
        } finally {
            setSavingExt(false);
        }
    };

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
        <div className="h-screen flex flex-col bg-gray-100 dark:bg-gray-900 py-3 px-2 sm:px-4">
            {/* Header */}
            <div className="flex items-center justify-between mb-3 flex-shrink-0">
                <div className="flex items-center gap-4">
                    <h1 className="text-xl font-bold text-gray-800 dark:text-gray-200 flex items-center gap-2">
                        <LiveTvIcon fontSize="small" /> Planning Anime
                    </h1>
                    {/* Extension selector */}
                    <div className="flex items-center">
                        {editingExt ? (
                            <div className="flex items-center gap-1.5">
                                <span className="text-gray-500 dark:text-gray-400 text-sm">anime-sama.</span>
                                <input
                                    type="text"
                                    value={inputExt}
                                    onChange={(e) => setInputExt(e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') handleSaveExtension();
                                        if (e.key === 'Escape') setEditingExt(false);
                                    }}
                                    className="w-14 px-1.5 py-0.5 bg-gray-200 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded text-gray-800 dark:text-white text-sm focus:outline-none focus:border-blue-500"
                                    placeholder="to"
                                    autoFocus
                                />
                                <button
                                    onClick={handleSaveExtension}
                                    disabled={savingExt}
                                    className="px-1.5 py-0.5 bg-green-600 hover:bg-green-700 text-white text-xs rounded transition-colors"
                                >
                                    {savingExt ? '...' : <CheckIcon sx={{ fontSize: 14 }} />}
                                </button>
                                <button
                                    onClick={() => setEditingExt(false)}
                                    className="px-1.5 py-0.5 bg-gray-400 hover:bg-gray-500 text-white text-xs rounded transition-colors"
                                >
                                    <CloseIcon sx={{ fontSize: 14 }} />
                                </button>
                            </div>
                        ) : (
                            <button
                                onClick={() => { setInputExt(extension); setEditingExt(true); }}
                                className="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 text-sm flex items-center gap-1 transition-colors"
                                title="Changer l'extension du site"
                            >
                                <LanguageIcon sx={{ fontSize: 16 }} /> anime-sama.<span className="text-blue-500 font-bold">{extension}</span>
                            </button>
                        )}
                    </div>
                    {/* Bouton détecter auto */}
                    <button
                        onClick={async () => {
                            const currentLocalExt = localStorage.getItem(EXT_STORAGE_KEY) || extension;
                            setDetecting(true);
                            try {
                                const config = await configApi.detectExtension();
                                if (currentLocalExt !== config.extension) {
                                    migrateStorageDomain(currentLocalExt, config.extension);
                                    setDetectInfo(`Domaine migré : .${currentLocalExt} → .${config.extension}`);
                                } else {
                                    setDetectInfo(`Domaine actif confirmé : .${config.extension}`);
                                }
                                setExtension(config.extension);
                                localStorage.setItem(EXT_STORAGE_KEY, config.extension);
                            } catch {
                                setDetectInfo('Détection échouée');
                            } finally {
                                setDetecting(false);
                            }
                        }}
                        disabled={detecting}
                        className="text-gray-500 dark:text-gray-400 hover:text-blue-500 transition-colors disabled:opacity-40"
                        title="Détecter automatiquement le domaine actif"
                    >
                        <SyncIcon sx={{ fontSize: 18 }} className={detecting ? 'animate-spin' : ''} />
                    </button>
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
                        onHide={viewMode !== 'masques' ? hideAnime : undefined}
                        onRestore={viewMode === 'masques' ? restoreAnime : undefined}
                        onMarkSeen={viewMode === 'nouveaux' ? markAsSeen : undefined}
                        showActions={true}
                        isHiddenList={viewMode === 'masques'}
                        isNewList={viewMode === 'nouveaux'}
                        isOldList={viewMode === 'anciens'}
                        groupByDay={true}
                        emptyMessage={getEmptyMessage()}
                    />
                </div>
            )}
        </div>
    );
};

export default AnimePage;
