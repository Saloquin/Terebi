import React, { useState, useEffect } from 'react';
import { CatalogSearch } from '../Catalog/CatalogSearch';
import { AnimePlanning } from '../../types/anime.types';
import { markAsToWatch, removeFromToWatch } from '../../utils/tabLogic/towatch.logic';
import { useAnimeData } from '../../hooks/useAnimeData';
import { Snackbar, Alert } from '@mui/material';

interface CatalogPageProps {
    theme?: 'light' | 'dark';
    onSelectAnime?: (anime: AnimePlanning) => void;
}

interface SnackbarState {
    open: boolean;
    message: string;
    severity: 'success' | 'error' | 'info' | 'warning';
}

export const CatalogPage: React.FC<CatalogPageProps> = ({ theme = 'light', onSelectAnime }) => {
    const [pageTitle, setPageTitle] = useState('Catalogue');
    const { towatch, loading } = useAnimeData();
    const [toWatchTitles, setToWatchTitles] = useState<string[]>([]);
    const [viewedIds, setViewedIds] = useState<string[]>([]);
    const [snackbar, setSnackbar] = useState<SnackbarState>({
        open: false,
        message: '',
        severity: 'info',
    });

    useEffect(() => {
        setToWatchTitles(towatch.map(a => a.title));
    }, [towatch]);

    // Load viewed animes on mount
    useEffect(() => {
        const storage = localStorage.getItem('anime_dashboard_v2');
        if (storage) {
            try {
                const parsed = JSON.parse(storage);
                setViewedIds(parsed.viewed?.map((a: any) => a.id) || []);
            } catch {
                // Ignore parse errors
            }
        }
    }, []);

    const handleAddToWatch = (item: any) => {
        const anime: AnimePlanning = {
            id: item.id,
            title: item.title,
            image: item.image || '',
            url: item.url,
            fullUrl: item.fullUrl,
            dayOfWeek: '',
            type: 'VOSTFR' as any,
        };
        markAsToWatch(anime);
        // Update local state immediately
        setToWatchTitles(prev => [...prev, item.title]);
        setSnackbar({
            open: true,
            message: `"${item.title}" ajouté à "À regarder"!`,
            severity: 'success',
        });
    };

    const handleRemoveFromToWatch = (title: string) => {
        removeFromToWatch(title);
        // Update local state immediately
        setToWatchTitles(prev => prev.filter(t => t !== title));
        setSnackbar({
            open: true,
            message: `"${title}" retiré de "À regarder"!`,
            severity: 'info',
        });
    };

    return (
        <div className={theme === 'dark' ? 'dark' : ''}>
            <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
                <div className="max-w-6xl mx-auto px-4 py-8">
                    {/* Header */}
                    <div className="mb-8">
                        <h1 className="text-4xl font-bold mb-2">Catalogue Anime et Films</h1>
                        <p className="text-gray-600 dark:text-gray-400">
                            Découvrez notre sélection d'animes et de films en VOSTFR
                        </p>
                    </div>

                    {/* Search Component */}
                    <CatalogSearch
                        onSearch={(query, page) => {
                            setPageTitle(`Catalogue - Résultats pour "${query}"`);
                        }}
                        onAddToWatch={handleAddToWatch}
                        onRemoveFromToWatch={handleRemoveFromToWatch}
                        toWatchTitles={toWatchTitles}
                        viewedIds={viewedIds}
                        onSelectAnime={onSelectAnime}
                    />
                </div>
            </div>

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
    );
};
