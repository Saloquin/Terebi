import React, { useState, useEffect } from 'react';
import BookmarkIcon from '@mui/icons-material/Bookmark';
import BookmarkBorderIcon from '@mui/icons-material/BookmarkBorder';
import PlayCircleIcon from '@mui/icons-material/PlayCircle';
import Tooltip from '@mui/material/Tooltip';

interface CatalogItem {
    id: string;
    title: string;
    image?: string;
    url: string;
    fullUrl: string;
    genres?: string[];
    year?: string;
    score?: number;
    status?: string;
    type?: string;
}

interface CatalogAnimeCardProps {
    item: CatalogItem;
    isInToWatch?: boolean;
    onAddToWatch?: (item: CatalogItem) => void;
    onRemoveFromToWatch?: (title: string) => void;
    compact?: boolean;
}

export const CatalogAnimeCard: React.FC<CatalogAnimeCardProps> = ({
    item,
    isInToWatch = false,
    onAddToWatch,
    onRemoveFromToWatch,
    compact = false,
}) => {
    const [seasons, setSeasons] = useState<number | null>(null);
    const [loadingSeasons, setLoadingSeasons] = useState(false);
    const [optimisticIsInToWatch, setOptimisticIsInToWatch] = useState<boolean | null>(null);

    // Use optimistic state if set, otherwise use prop
    const displayIsInToWatch = optimisticIsInToWatch !== null ? optimisticIsInToWatch : isInToWatch;

    useEffect(() => {
        // Extract slug from fullUrl or url
        const urlParts = item.fullUrl.split('/');
        const slug = urlParts.find((part) => part && !part.includes('.'));
        
        if (slug) {
            setLoadingSeasons(true);
            fetch(`/api/animes/seasons/${slug}`)
                .then(res => res.json())
                .then(data => {
                    if (data.success && data.data?.totalSeasons) {
                        setSeasons(data.data.totalSeasons);
                    }
                })
                .catch(() => {
                    // Silently fail
                })
                .finally(() => setLoadingSeasons(false));
        }
    }, [item.fullUrl, item.url]);

    if (compact) {
        // Compact version for ToWatch page
        return (
            <div className="group rounded-lg overflow-hidden hover:shadow-lg transition-shadow bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 flex flex-col h-full">
                <a href={item.fullUrl} target="_blank" rel="noopener noreferrer" className="relative block flex-1 overflow-hidden">
                    {item.image ? (
                        <img
                            src={item.image}
                            alt={item.title}
                            className="w-full h-full object-cover group-hover:opacity-80 transition-opacity"
                        />
                    ) : (
                        <div className="w-full h-full bg-gray-300 dark:bg-gray-600 flex items-center justify-center">
                            <span className="text-gray-500 dark:text-gray-400 text-xs">No image</span>
                        </div>
                    )}
                    
                    {/* Seasons badge - top right */}
                    {seasons !== null && (
                        <div className="absolute top-1 right-1 bg-blue-500 text-white text-xs font-bold px-2 py-1 rounded">
                            {seasons}s
                        </div>
                    )}
                </a>

                <div className="p-2 flex flex-col gap-2 flex-1">
                    <h3 className="font-semibold text-xs line-clamp-2 text-gray-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400">
                        {item.title}
                    </h3>
                    
                    {item.type && (
                        <span className={`text-xs font-bold px-2 py-0.5 rounded mt-1 w-fit ${
                            item.type.toLowerCase() === 'anime'
                                ? 'bg-purple-100 dark:bg-purple-900 text-purple-700 dark:text-purple-300'
                                : 'bg-orange-100 dark:bg-orange-900 text-orange-700 dark:text-orange-300'
                        }`}>
                            {item.type}
                        </span>
                    )}

                    {/* Toggle button */}
                    {(onAddToWatch || onRemoveFromToWatch) && (
                        <Tooltip title={displayIsInToWatch ? 'Retirer de "À voir"' : 'Ajouter à "À voir"'}>
                            <button
                                onClick={(e) => {
                                    e.preventDefault();
                                    if (displayIsInToWatch && onRemoveFromToWatch) {
                                        setOptimisticIsInToWatch(false);
                                        onRemoveFromToWatch(item.title);
                                    } else if (!displayIsInToWatch && onAddToWatch) {
                                        setOptimisticIsInToWatch(true);
                                        onAddToWatch(item);
                                    }
                                }}
                                className={`w-full px-2 py-1 text-xs font-medium rounded flex items-center justify-center gap-1 transition-colors ${
                                    displayIsInToWatch
                                        ? 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 hover:bg-red-200 dark:hover:bg-red-900/50'
                                        : 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400 hover:bg-blue-200 dark:hover:bg-blue-900/50'
                                }`}
                            >
                                {displayIsInToWatch ? (
                                    <>
                                        <BookmarkIcon sx={{ fontSize: 14 }} />
                                        Retirer
                                    </>
                                ) : (
                                    <>
                                        <BookmarkBorderIcon sx={{ fontSize: 14 }} />
                                        Ajouter
                                    </>
                                )}
                            </button>
                        </Tooltip>
                    )}
                </div>
            </div>
        );
    }

    // Regular version for Catalog
    return (
        <div className="group rounded-lg overflow-hidden hover:shadow-lg transition-shadow bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 flex flex-col">
            <a href={item.fullUrl} target="_blank" rel="noopener noreferrer" className="relative block flex-1 overflow-hidden">
                {item.image ? (
                    <img
                        src={item.image}
                        alt={item.title}
                        className="w-full h-48 object-cover group-hover:opacity-80 transition-opacity"
                    />
                ) : (
                    <div className="w-full h-48 bg-gray-300 dark:bg-gray-600 flex items-center justify-center">
                        <span className="text-gray-500 dark:text-gray-400">Pas d'image</span>
                    </div>
                )}

                {/* Seasons badge - top right */}
                {seasons !== null && (
                    <div className="absolute top-2 right-2 bg-blue-500 text-white text-xs font-bold px-2 py-1 rounded flex items-center gap-1">
                        <PlayCircleIcon sx={{ fontSize: 16 }} />
                        {seasons} saison{seasons > 1 ? 's' : ''}
                    </div>
                )}
            </a>

            <div className="p-3 space-y-2 flex-1 flex flex-col">
                <div className="flex items-start justify-between gap-2">
                    <h3 className="font-semibold text-sm text-gray-900 dark:text-white line-clamp-2 group-hover:text-blue-600 dark:group-hover:text-blue-400 flex-1">
                        {item.title}
                    </h3>
                    {item.type && (
                        <span className={`flex-shrink-0 text-xs font-bold px-2 py-1 rounded whitespace-nowrap ${
                            item.type.toLowerCase() === 'anime'
                                ? 'bg-purple-100 dark:bg-purple-900 text-purple-700 dark:text-purple-300'
                                : 'bg-orange-100 dark:bg-orange-900 text-orange-700 dark:text-orange-300'
                        }`}>
                        {item.type}
                    </span>
                    )}
                </div>

                {/* Genres */}
                {item.genres && item.genres.length > 0 && (
                    <div className="flex flex-wrap gap-1">
                        {item.genres.slice(0, 2).map((genre, idx) => (
                            <span key={idx} className="inline-block text-xs px-2 py-1 bg-blue-100 dark:bg-blue-900 text-blue-700 dark:text-blue-300 rounded">
                                {genre}
                            </span>
                        ))}
                        {item.genres.length > 2 && (
                            <span className="inline-block text-xs px-2 py-1 bg-gray-200 dark:bg-gray-600 text-gray-700 dark:text-gray-300 rounded">
                                +{item.genres.length - 2}
                            </span>
                        )}
                    </div>
                )}

                {/* Year and Score */}
                {(item.year || item.score) && (
                    <div className="flex gap-2 text-xs text-gray-600 dark:text-gray-400">
                        {item.year && <span>{item.year}</span>}
                        {item.score && <span>{item.score.toFixed(1)}/10</span>}
                    </div>
                )}

                {/* Status */}
                {item.status && (
                    <p className="text-xs text-gray-500 dark:text-gray-400 line-clamp-1">
                        {item.status}
                    </p>
                )}

                {/* Toggle button */}
                {(onAddToWatch || onRemoveFromToWatch) && (
                    <Tooltip title={displayIsInToWatch ? 'Retirer de "À voir"' : 'Ajouter à "À voir"'}>
                        <button
                            onClick={(e) => {
                                e.preventDefault();
                                if (displayIsInToWatch && onRemoveFromToWatch) {
                                    setOptimisticIsInToWatch(false);
                                    onRemoveFromToWatch(item.title);
                                } else if (!displayIsInToWatch && onAddToWatch) {
                                    setOptimisticIsInToWatch(true);
                                    onAddToWatch(item);
                                }
                            }}
                            className={`mt-auto px-3 py-2 text-xs font-medium rounded flex items-center justify-center gap-1 transition-colors ${
                                displayIsInToWatch
                                    ? 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400 hover:bg-yellow-200 dark:hover:bg-yellow-900/50'
                                    : 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400 hover:bg-blue-200 dark:hover:bg-blue-900/50'
                            }`}
                        >
                            {displayIsInToWatch ? (
                                <>
                                    <BookmarkIcon sx={{ fontSize: 16 }} />
                                    Dans "À voir"
                                </>
                            ) : (
                                <>
                                    <BookmarkBorderIcon sx={{ fontSize: 16 }} />
                                    Ajouter à "À voir"
                                </>
                            )}
                        </button>
                    </Tooltip>
                )}
            </div>
        </div>
    );
};
