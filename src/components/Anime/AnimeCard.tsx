import React from 'react';
import { AnimePlanning } from '../../types/anime.types';

interface AnimeCardProps {
    anime: AnimePlanning;
    onHide?: (id: string) => void;
    onRestore?: (id: string) => void;
    onMarkSeen?: (id: string) => void;
    showActions?: boolean;
    isHidden?: boolean;
    isNew?: boolean;
    isOld?: boolean;
}

export const AnimeCard: React.FC<AnimeCardProps> = ({
    anime,
    onHide,
    onRestore,
    onMarkSeen,
    showActions = true,
    isHidden = false,
    isNew = false,
    isOld = false,
}) => {
    const baseUrl = process.env.REACT_APP_ANIME_BASE_URL;

    const handleClick = () => {
        // Utiliser fullUrl si disponible, sinon construire l'URL
        console.log('Navigating to anime URL:', anime.fullUrl || `${baseUrl} / ${anime.url}`);

        const finalUrl = anime.fullUrl || `${baseUrl}/${anime.url}`;
        window.open(finalUrl, '_blank');
    };

    const handleAction = (
        e: React.MouseEvent | React.TouchEvent,
        action: () => void
    ) => {
        e.preventDefault();
        e.stopPropagation();
        action();
    };

    const getBadgeStyle = () => {
        if (isNew) return 'bg-green-500';
        if (isOld) return 'bg-orange-500';
        if (isHidden) return 'bg-gray-500';
        return 'bg-blue-500';
    };

    const getTypeStyle = () => {
        switch (anime.type) {
            case 'VOSTFR': return 'bg-purple-600';
            case 'VF': return 'bg-blue-600';
            case 'Scan': return 'bg-green-600';
            case 'ScanVF': return 'bg-teal-600';
            default: return 'bg-gray-600';
        }
    };

    return (
        <div
            className={`
                relative group cursor-pointer rounded-md overflow-hidden shadow-md
                transition-all duration-200 hover:shadow-lg
                ${isHidden ? 'opacity-60' : ''}
            `}
            onClick={handleClick}
        >
            {/* Image */}
            <div className="aspect-[4/3] relative">
                <img
                    src={anime.image}
                    alt={anime.title}
                    className="w-full h-full object-cover"
                    loading="lazy"
                    onError={(e) => {
                        (e.target as HTMLImageElement).src = 'https://via.placeholder.com/300x400?text=No+Image';
                    }}
                />
                
                {/* Overlay gradient */}
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent" />
                
                {/* Badges */}
                <div className="absolute top-2 left-2 flex gap-1">
                    <span className={`px-2 py-1 text-xs font-bold rounded ${getTypeStyle()}`}>
                        {anime.type}
                    </span>
                    {isNew && (
                        <span className="px-2 py-1 text-xs font-bold rounded bg-green-500 animate-pulse">
                            NOUVEAU
                        </span>
                    )}
                    {isOld && (
                        <span className="px-2 py-1 text-xs font-bold rounded bg-orange-500">
                            ANCIEN
                        </span>
                    )}
                </div>
                
                {/* Season badge */}
                {anime.season && (
                    <div className="absolute top-2 right-2">
                        <span className="px-2 py-1 text-xs font-bold rounded bg-yellow-500">
                            {anime.season.replace(/^Saison\s*/i, 'S')}
                        </span>
                    </div>
                )}
                
                {/* Content */}
                <div className="absolute bottom-0 left-0 right-0 p-3">
                    <h3 className="text-white font-bold text-sm line-clamp-2 mb-1">
                        {anime.title}
                    </h3>
                    <div className="flex items-center gap-2 text-white/80 text-xs">
                        <span>{anime.dayOfWeek}</span>
                        {anime.time && (
                            <>
                                <span>•</span>
                                <span>{anime.time}</span>
                            </>
                        )}
                    </div>
                </div>
                
                {/* Actions (visible on hover) */}
                {showActions && (
                    <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
                        {isHidden ? (
                            <button
                                className="px-3 py-2 bg-green-600 hover:bg-green-700 rounded-lg text-white text-sm font-medium transition-colors"
                                onClick={(e) => handleAction(e, () => onRestore?.(anime.id))}
                                onMouseDown={(e) => e.stopPropagation()}
                            >
                                ♻️ Restaurer
                            </button>
                        ) : (
                            <>
                                {onMarkSeen && isNew && (
                                    <button
                                        className="px-3 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-white text-sm font-medium transition-colors"
                                        onClick={(e) => handleAction(e, () => onMarkSeen(anime.id))}
                                        onMouseDown={(e) => e.stopPropagation()}
                                    >
                                        ✓ Vu
                                    </button>
                                )}
                                {onHide && (
                                    <button
                                        className="px-3 py-2 bg-red-600 hover:bg-red-700 rounded-lg text-white text-sm font-medium transition-colors"
                                        onClick={(e) => handleAction(e, () => onHide(anime.id))}
                                        onMouseDown={(e) => e.stopPropagation()}
                                    >
                                        🙈 Masquer
                                    </button>
                                )}
                            </>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
};

export default AnimeCard;
