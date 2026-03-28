import React, { useState, useEffect } from 'react';
import { useAnimeData } from '../../hooks/useAnimeData';
import { removeFromToWatch } from '../../utils/tabLogic/towatch.logic';
import { CatalogAnimeCard } from '../Catalog/CatalogAnimeCard';
import { AnimePlanning } from '../../types/anime.types';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import Tooltip from '@mui/material/Tooltip';

interface ToWatchPageProps {
    onSelectAnime?: (anime: AnimePlanning) => void;
}

export const ToWatchPage: React.FC<ToWatchPageProps> = ({ onSelectAnime }) => {
    const { towatch, loading, markAsSeen } = useAnimeData();
    const [localTowatch, setLocalTowatch] = useState(towatch);

    useEffect(() => {
        setLocalTowatch(towatch);
    }, [towatch]);

    const handleRemove = (title: string) => {
        // Remove from localStorage
        removeFromToWatch(title);
        // Update local state
        setLocalTowatch(prev => prev.filter(a => a.title !== title));
    };

    const handleMarkWatched = (anime: any) => {
        // Update local state immediately
        setLocalTowatch(prev => prev.filter(a => a.title !== anime.title));
        // Then update storage
        markAsSeen(anime.title);
        removeFromToWatch(anime.title);
    };

    return (
        <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
            <div className="max-w-7xl mx-auto px-4 py-8">
                {/* Header */}
                <div className="mb-8">
                    <h1 className="text-4xl font-bold mb-2">Ma liste "À voir"</h1>
                    <p className="text-gray-600 dark:text-gray-400">
                        {localTowatch.length} élément{localTowatch.length !== 1 ? 's' : ''} sauvegardé{localTowatch.length !== 1 ? 's' : ''}
                    </p>
                </div>

                {loading && (
                    <div className="text-center py-12">
                        <p className="text-gray-500 dark:text-gray-400">Chargement...</p>
                    </div>
                )}

                {!loading && localTowatch.length === 0 && (
                    <div className="text-center py-16 bg-gradient-to-b from-gray-100 to-gray-50 dark:from-gray-800 dark:to-gray-900 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-600">
                        <div className="text-5xl mb-4">📺</div>
                        <p className="text-lg font-semibold text-gray-700 dark:text-gray-300 mb-2">
                            Votre liste "À voir" est vide
                        </p>
                        <p className="text-sm text-gray-500 dark:text-gray-400">
                            Explorez le catalogue, le planning ou des animes pour en ajouter !
                        </p>
                    </div>
                )}

                {!loading && localTowatch.length > 0 && (
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
                                {/* Extra actions overlay for ToWatch */}
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
            </div>
        </div>
    );
};
