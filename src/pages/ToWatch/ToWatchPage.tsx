import React, { useState, useEffect } from 'react';
import { useAnimeData } from '../../hooks/useAnimeData';
import { removeFromToWatch } from '../../utils/tabLogic/towatch.logic';
import { CatalogAnimeCard } from '../Catalog/CatalogAnimeCard';
import { AnimePlanning } from '../../types/anime.types';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import RestartAltIcon from '@mui/icons-material/RestartAlt';
import Tooltip from '@mui/material/Tooltip';
import { Tabs, Tab, Box, Snackbar, Alert } from '@mui/material';

interface ToWatchPageProps {
    onSelectAnime?: (anime: AnimePlanning) => void;
}

interface SnackbarState {
    open: boolean;
    message: string;
    severity: 'success' | 'error' | 'info' | 'warning';
}

export const ToWatchPage: React.FC<ToWatchPageProps> = ({ onSelectAnime }) => {
    const { towatch, viewed, loading, markAsViewed, removeFromViewed } = useAnimeData();
    const [activeTab, setActiveTab] = useState<'towatch' | 'viewed'>(0 as any);
    const [localTowatch, setLocalTowatch] = useState(towatch);
    const [localViewed, setLocalViewed] = useState(viewed);
    const [snackbar, setSnackbar] = useState<SnackbarState>({
        open: false,
        message: '',
        severity: 'info',
    });

    useEffect(() => {
        setLocalTowatch(towatch);
    }, [towatch]);

    useEffect(() => {
        setLocalViewed(viewed);
    }, [viewed]);

    const handleRemove = (title: string) => {
        // Remove from localStorage
        removeFromToWatch(title);
        // Update local state
        setLocalTowatch(prev => prev.filter(a => a.title !== title));
        setSnackbar({
            open: true,
            message: `"${title}" retiré de "À regarder"!`,
            severity: 'info',
        });
    };

    const handleMarkWatched = (anime: any) => {
        // Move to viewed and remove from towatch
        markAsViewed(anime);
        // Update local state
        setLocalTowatch(prev => prev.filter(a => a.title !== anime.title));
        setLocalViewed(prev => [...prev, { ...anime, viewedAt: new Date().toISOString() }]);
        setSnackbar({
            open: true,
            message: `"${anime.title}" marqué comme regardé!`,
            severity: 'success',
        });
    };

    const handleUnmarkWatched = (animeId: string) => {
        const anime = localViewed.find(a => a.id === animeId);
        if (anime) {
            removeFromViewed(animeId);
            setLocalViewed(prev => prev.filter(a => a.id !== animeId));
            setSnackbar({
                open: true,
                message: `"${anime.title}" retiré de "Déjà vu"!`,
                severity: 'info',
            });
        }
    };

    return (
        <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
            <div className="max-w-7xl mx-auto px-4 py-8">
                {/* Header */}
                <div className="mb-8">
                    <h1 className="text-4xl font-bold mb-2">À regarder</h1>
                    <p className="text-gray-600 dark:text-gray-400">
                        Gérez votre liste de visionnage
                    </p>
                </div>

                {loading && (
                    <div className="text-center py-12">
                        <p className="text-gray-500 dark:text-gray-400">Chargement...</p>
                    </div>
                )}

                {!loading && (
                    <>
                        {/* Tabs */}
                        <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 4 }} className="dark:border-gray-700">
                            <Tabs 
                                value={activeTab} 
                                onChange={(e, newValue) => setActiveTab(newValue)}
                                sx={{
                                    '& .MuiTab-root': {
                                        color: 'inherit',
                                        '&.Mui-selected': {
                                            color: '#2563eb',
                                        }
                                    },
                                    '& .MuiTabs-indicator': {
                                        backgroundColor: '#2563eb',
                                    }
                                }}
                            >
                                <Tab 
                                    label={`À regarder (${localTowatch.length})`} 
                                    value="towatch"
                                    sx={{ fontSize: '1rem', fontWeight: 500 }}
                                />
                                <Tab 
                                    label={`Déjà vu (${localViewed.length})`} 
                                    value="viewed"
                                    sx={{ fontSize: '1rem', fontWeight: 500 }}
                                />
                            </Tabs>
                        </Box>

                        {/* À regarder Tab */}
                        {activeTab === 'towatch' && (
                            <>
                                {localTowatch.length === 0 && (
                                    <div className="text-center py-16 bg-gradient-to-b from-gray-100 to-gray-50 dark:from-gray-800 dark:to-gray-900 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-600">
                                        <div className="text-5xl mb-4">📺</div>
                                        <p className="text-lg font-semibold text-gray-700 dark:text-gray-300 mb-2">
                                            Votre liste "À regarder" est vide
                                        </p>
                                        <p className="text-sm text-gray-500 dark:text-gray-400">
                                            Explorez le catalogue pour ajouter des animes !
                                        </p>
                                    </div>
                                )}

                                {localTowatch.length > 0 && (
                                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
                                        {localTowatch.map((anime) => (
                                            <div key={anime.id} className="relative">
                                                <CatalogAnimeCard
                                                    item={anime as any}
                                                    isInToWatch={true}
                                                    onAddToWatch={() => {}}
                                                    onRemoveFromToWatch={() => handleRemove(anime.title)}
                                                    compact={true}
                                                    onSelectAnime={onSelectAnime}
                                                />
                                                {/* Mark as watched button */}
                                                <Tooltip title="Marquer comme regardé">
                                                    <button
                                                        onClick={() => handleMarkWatched(anime)}
                                                        className="absolute bottom-14 left-2 right-2 px-2 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 hover:bg-green-200 dark:hover:bg-green-900/50 rounded text-xs font-medium flex items-center justify-center gap-1 transition-colors z-10"
                                                    >
                                                        <CheckCircleIcon sx={{ fontSize: 14 }} />
                                                        Vu
                                                    </button>
                                                </Tooltip>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </>
                        )}

                        {/* Déjà vu Tab */}
                        {activeTab === 'viewed' && (
                            <>
                                {localViewed.length === 0 && (
                                    <div className="text-center py-16 bg-gradient-to-b from-gray-100 to-gray-50 dark:from-gray-800 dark:to-gray-900 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-600">
                                        <div className="text-5xl mb-4">✅</div>
                                        <p className="text-lg font-semibold text-gray-700 dark:text-gray-300 mb-2">
                                            Aucun anime marqué comme regardé
                                        </p>
                                        <p className="text-sm text-gray-500 dark:text-gray-400">
                                            Marquez des animes comme regardés pour les voir ici !
                                        </p>
                                    </div>
                                )}

                                {localViewed.length > 0 && (
                                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
                                        {localViewed.map((anime) => (
                                            <div key={anime.id} className="relative">
                                                <div className="relative">
                                                    <CatalogAnimeCard
                                                        item={anime as any}
                                                        isInToWatch={false}
                                                        onAddToWatch={() => {}}
                                                        onRemoveFromToWatch={() => {}}
                                                        compact={true}
                                                        onSelectAnime={onSelectAnime}
                                                    />
                                                    {/* Checkmark overlay */}
                                                    <div className="absolute top-1 left-1 bg-green-500 text-white rounded-full w-6 h-6 flex items-center justify-center">
                                                        <CheckCircleIcon sx={{ fontSize: 18 }} />
                                                    </div>
                                                </div>
                                                {/* Remove from viewed button */}
                                                <Tooltip title="Retirer de 'Déjà vu'">
                                                    <button
                                                        onClick={() => handleUnmarkWatched(anime.id)}
                                                        className="absolute bottom-14 left-2 right-2 px-2 py-1 bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400 hover:bg-orange-200 dark:hover:bg-orange-900/50 rounded text-xs font-medium flex items-center justify-center gap-1 transition-colors z-10"
                                                    >
                                                        <RestartAltIcon sx={{ fontSize: 14 }} />
                                                        Annuler
                                                    </button>
                                                </Tooltip>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </>
                        )}
                    </>
                )}

                {/* Snackbar for notifications */}
                <Snackbar
                    open={snackbar.open}
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
        </div>
    );
};
