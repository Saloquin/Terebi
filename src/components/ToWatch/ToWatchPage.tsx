import React from 'react';
import { useAnimeData } from '../../hooks/useAnimeData';
import { removeFromToWatch } from '../../utils/tabLogic/towatch.logic';
import DeleteIcon from '@mui/icons-material/Delete';
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
                            <div
                                key={anime.id}
                                className="group rounded-lg overflow-hidden bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:shadow-xl transition-all hover:scale-105 flex flex-col h-full"
                            >
                                {/* Image Container */}
                                <div className="relative w-full h-32 overflow-hidden bg-gray-300 dark:bg-gray-600">
                                    {anime.image ? (
                                        <>
                                            <img
                                                src={anime.image}
                                                alt={anime.title}
                                                className="w-full h-full object-cover group-hover:brightness-75 transition-all"
                                            />
                                            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all" />
                                        </>
                                    ) : (
                                        <div className="w-full h-full flex items-center justify-center">
                                            <span className="text-xs text-gray-500 dark:text-gray-400 text-center px-2">
                                                No image
                                            </span>
                                        </div>
                                    )}
                                </div>

                                {/* Content */}
                                <div className="p-2 flex-1 flex flex-col">
                                    {/* Title */}
                                    <h3 className="font-semibold text-xs line-clamp-2 text-gray-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 mb-2 flex-1">
                                        {anime.title}
                                    </h3>

                                    {/* Type/Status Badge */}
                                    {anime.type && (
                                        <div className="mb-2">
                                            <span className="inline-block text-xs font-bold px-2 py-0.5 bg-purple-100 dark:bg-purple-900/40 text-purple-700 dark:text-purple-300 rounded">
                                                {anime.type}
                                            </span>
                                        </div>
                                    )}

                                    {/* Actions */}
                                    <div className="flex gap-1 flex-shrink-0">
                                        <button
                                            onClick={() => handleMarkWatched(anime)}
                                            className="flex-1 px-1.5 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 hover:bg-green-200 dark:hover:bg-green-900/50 rounded text-xs font-medium flex items-center justify-center gap-1 transition-colors whitespace-nowrap"
                                            title="Marquer comme regardé"
                                        >
                                            <CheckCircleIcon sx={{ fontSize: 14 }} />
                                            Vu
                                        </button>
                                        <button
                                            onClick={() => handleRemove(anime.title, anime.title)}
                                            className="flex-1 px-1.5 py-1 bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 hover:bg-red-200 dark:hover:bg-red-900/50 rounded text-xs font-medium flex items-center justify-center gap-1 transition-colors whitespace-nowrap"
                                            title="Retirer"
                                        >
                                            <DeleteIcon sx={{ fontSize: 14 }} />
                                            Retirer
                                        </button>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};
