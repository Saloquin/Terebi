import React, { useState, useMemo, useEffect } from 'react';
import { useAnimeData } from '../../hooks/useAnimeData';
import { ViewMode, AnimePlanning } from '../../types/anime.types';
import { configApi } from '../../services/api/config.api';
import { migrateStorageDomain } from '../../services/api/domain-migration';
import { getTabLogic } from '../../utils/tabLogic';
import AnimeFilters from './AnimeFilters';
import AnimeList from './AnimeList';
import { AnimeDetailPanel } from './AnimeDetailPanel';
import LiveTvIcon from '@mui/icons-material/LiveTv';
import LanguageIcon from '@mui/icons-material/Language';
import CloseIcon from '@mui/icons-material/Close';
import RefreshIcon from '@mui/icons-material/Refresh';
import WarningAmberIcon from '@mui/icons-material/WarningAmber';
import SyncIcon from '@mui/icons-material/Sync';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import { Snackbar, Alert, Box, Typography, Button, Tooltip, Card, CardMedia, CardContent } from '@mui/material';

const EXT_STORAGE_KEY = 'anime_extension';

interface AnimePageProps {
    selectedAnime?: AnimePlanning | null;
    onDeselectAnime?: () => void;
}

export const AnimePage: React.FC<AnimePageProps> = ({ selectedAnime = null, onDeselectAnime }) => {
    const {
        current,
        newAnimes,
        old,
        hidden,
        towatch,
        viewed,
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
        markAsViewed,
    } = useAnimeData();

    const [viewMode, setViewMode] = useState<ViewMode>('planning');
    const [searchQuery, setSearchQuery] = useState('');
    const [detailModalOpen, setDetailModalOpen] = useState(false);
    const [snackbar, setSnackbar] = useState({
        open: false,
        message: '',
        severity: 'success' as 'success' | 'error' | 'info' | 'warning',
    });

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
        const animes = getAnimesByViewMode(viewMode);
        return filterBySearch(animes, searchQuery);
    }, [viewMode, searchQuery, getAnimesByViewMode, filterBySearch, current, newAnimes, old, hidden]);

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

    const handleMarkAsViewedWithSeasons = (selectedSeasons: string[]) => {
        if (selectedAnime) {
            const viewedAnime = {
                ...selectedAnime,
                viewedSeasons: selectedSeasons,
            };
            markAsViewed(viewedAnime, selectedSeasons);
            setSnackbar({
                open: true,
                message: `"${selectedAnime.title}" marqué comme regardé (${selectedSeasons.length} saison${selectedSeasons.length > 1 ? 's' : ''})!`,
                severity: 'success',
            });
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

            {/* Selected Anime Details Panel */}
            {selectedAnime && (
                <Box
                    sx={{
                        p: 2.5,
                        mb: 2,
                        bg: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                        borderRadius: 1,
                        color: 'white',
                        display: 'flex',
                        gap: 2,
                        alignItems: 'flex-start',
                        flexShrink: 0,
                    }}
                    className="dark:bg-gradient-to-r dark:from-blue-900 dark:to-purple-900"
                >
                    {/* Anime Image */}
                    {selectedAnime.image && (
                        <Box
                            component="img"
                            src={selectedAnime.image}
                            sx={{
                                width: 60,
                                height: 80,
                                borderRadius: 1,
                                objectFit: 'cover',
                                flexShrink: 0,
                            }}
                            alt={selectedAnime.title}
                        />
                    )}

                    {/* Anime Info */}
                    <Box sx={{ flex: 1 }}>
                        <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5 }}>
                            {selectedAnime.title}
                        </Typography>
                        <Typography variant="body2" sx={{ opacity: 0.9 }}>
                            {selectedAnime.type} • {selectedAnime.dayOfWeek}
                        </Typography>

                        {/* Check if anime is already viewed */}
                        {viewed.some(
                            (a) =>
                                a.title.toLowerCase() === selectedAnime.title.toLowerCase() ||
                                a.id === selectedAnime.id
                        ) && (
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1 }}>
                                <CheckCircleIcon sx={{ fontSize: 18 }} />
                                <Typography variant="caption" sx={{ fontWeight: 600 }}>
                                    Déjà marqué comme vu
                                </Typography>
                            </Box>
                        )}
                    </Box>
                    {/* Action Buttons */}
                    <Box sx={{ display: 'flex', gap: 1, flexShrink: 0 }}>
                        <Tooltip title="Marquer certaines saisons comme vues">
                            <Button
                                variant="contained"
                                size="small"
                                startIcon={<CheckCircleIcon />}
                                onClick={() => setDetailModalOpen(true)}
                                sx={{
                                    backgroundColor: 'rgba(255,255,255,0.25)',
                                    color: 'white',
                                    '&:hover': {
                                        backgroundColor: 'rgba(255,255,255,0.35)',
                                    },
                                }}
                            >
                                Marquer vu
                            </Button>
                        </Tooltip>
                        <Tooltip title="Fermer le détail">
                            <Button
                                variant="contained"
                                size="small"
                                startIcon={<CloseIcon />}
                                onClick={() => onDeselectAnime?.()}
                                sx={{
                                    backgroundColor: 'rgba(255,255,255,0.25)',
                                    color: 'white',
                                    '&:hover': {
                                        backgroundColor: 'rgba(255,255,255,0.35)',
                                    },
                                }}
                            >
                                Fermer
                            </Button>
                        </Tooltip>
                    </Box>
                </Box>
            )}

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
                        groupByDay={viewMode === 'planning'}
                        emptyMessage={tabLogic.emptyMessage}
                        toWatchTitles={towatch.map(a => a.title)}
                    />
                </div>
            )}

            {/* Anime Detail Modal */}
            <AnimeDetailPanel
                anime={selectedAnime}
                isOpen={detailModalOpen}
                onClose={() => setDetailModalOpen(false)}
                onMarkAsViewed={handleMarkAsViewedWithSeasons}
            />

            {/* Snackbar for notifications */}
            <Snackbar
                open={snackbar.open && !!snackbar.message}
                autoHideDuration={3000}
                onClose={() => setSnackbar({ ...snackbar, open: false })}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
            >
                <Alert
                    onClose={() => setSnackbar({ ...snackbar, open: false })}
                    severity={snackbar.severity}
                    sx={{ width: '100%' }}
                >
                    {snackbar.message}
                </Alert>
            </Snackbar>
        </div>
    );
};

export default AnimePage;
