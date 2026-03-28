import React from 'react';
import { useAnimeData } from '../../hooks/useAnimeData';
import { removeFromToWatch } from '../../utils/tabLogic/towatch.logic';
import { CatalogAnimeCard } from '../Catalog/CatalogAnimeCard';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';

export const ToWatchPage: React.FC = () => {
    const { towatch, loading, markAsSeen } = useAnimeData();

    const handleRemove = (id: string, title: string) => {
        if (window.confirm(`Retirer "${title}" de la liste "À voir" ?`)) {
            removeFromToWatch(id);
            window.location.reload();
        }
    };

    const handleMarkWatched = (anime: any) => {
        markAsSeen(anime.title);
        removeFromToWatch(anime.title);
        window.location.reload();
    };

    return (
        <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
            <div className="max-w-7xl mx-auto px-4 py-8">
                {/* Header */}
                <div className="mb-8">
                    <h1 className="text-4xl font-bold mb-2">⭐ Ma liste "À voir"</h1>
                    <p className="text-gray-600 dark:text-gray-400">
                        {towatch.length} élément{towatch.length !== 1 ? 's' : ''} sauvegardé{towatch.length !== 1 ? 's' : ''}
                    </p>
                </div>

                {loading && (
                    <div className="text-center py-12">
                        <p className="text-gray-500 dark:text-gray-400">Chargement...</p>
                    </div>
                )}

                {!loading && towatch.length === 0 && (
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

                {!loading && towatch.length > 0 && (
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
                        {towatch.map((anime) => (
                            <div key={anime.id} className="relative">
                                <CatalogAnimeCard
                                    item={anime as any}
                                    isInToWatch={true}
                                    onAddToWatch={() => {}}
                                    onRemoveFromToWatch={() => handleRemove(anime.id || anime.title, anime.title)}
                                    compact={true}
                                />
                                {/* Extra actions overlay for ToWatch */}
                                <button
                                    onClick={() => handleMarkWatched(anime)}
                                    className="absolute bottom-14 left-2 right-2 px-2 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 hover:bg-green-200 dark:hover:bg-green-900/50 rounded text-xs font-medium flex items-center justify-center gap-1 transition-colors z-10"
                                    title="Marquer comme regardé"
                                >
                                    <CheckCircleIcon sx={{ fontSize: 14 }} />
                                    Vu
                                </button>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};
