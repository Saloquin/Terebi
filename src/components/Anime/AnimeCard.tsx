import React, { useState, useEffect } from 'react';
import { AnimePlanning } from '../../types/anime.types';
import RestoreIcon from '@mui/icons-material/Restore';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import BookmarkIcon from '@mui/icons-material/Bookmark';
import BookmarkBorderIcon from '@mui/icons-material/BookmarkBorder';
import PlayCircleIcon from '@mui/icons-material/PlayCircle';

interface AnimeCardProps {
    anime: AnimePlanning;
    onHide?: (id: string) => void;
    onRestore?: (id: string) => void;
    onMarkSeen?: (id: string) => void;
    onRemoveOld?: (id: string) => void;
    onAddToWatch?: (anime: AnimePlanning) => void;
    onRemoveFromToWatch?: (id: string) => void;
    showActions?: boolean;
    isHidden?: boolean;
    isNew?: boolean;
    isOld?: boolean;
    isInToWatch?: boolean;
}

export const AnimeCard: React.FC<AnimeCardProps> = ({
    anime,
    onHide,
    onRestore,
    onMarkSeen,
    onRemoveOld,
    onAddToWatch,
    onRemoveFromToWatch,
    showActions = true,
    isHidden = false,
    isNew = false,
    isOld = false,
    isInToWatch = false,
}) => {
    const handleClick = () => {
        const finalUrl = anime.fullUrl || `https://anime-sama.to/${anime.url}`;
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

    const canRestore = isHidden && !!onRestore;
    const canRemoveFromNew = !isHidden && isNew && !!onMarkSeen;
    const canRemoveFromOld = !isHidden && isOld && !!onRemoveOld;
    const canHide = !isHidden && !!onHide;
    const hasActions = showActions && (canRestore || canRemoveFromNew || canRemoveFromOld || canHide);

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

                {/* À voir button - top right corner */}
                {!isHidden && (onAddToWatch || onRemoveFromToWatch) && (
                    <button
                        className={`absolute top-2 right-${anime.season ? '16' : '2'} w-8 h-8 flex items-center justify-center rounded-full shadow-lg transition-colors ${
                            isInToWatch
                                ? 'bg-yellow-400 hover:bg-yellow-500 text-gray-900'
                                : 'bg-gray-600 hover:bg-gray-700 text-white'
                        }`}
                        onClick={(e) => {
                            e.stopPropagation();
                            if (isInToWatch && onRemoveFromToWatch) {
                                onRemoveFromToWatch(anime.title);
                            } else if (!isInToWatch && onAddToWatch) {
                                onAddToWatch(anime);
                            }
                        }}
                        onMouseDown={(e) => e.stopPropagation()}
                        title={isInToWatch ? 'Retirer de "À voir"' : 'Ajouter à "À voir"'}
                    >
                        {isInToWatch ? (
                            <BookmarkIcon sx={{ fontSize: 18 }} />
                        ) : (
                            <BookmarkBorderIcon sx={{ fontSize: 18 }} />
                        )}
                    </button>
                )}
                
                {/* Content */}
                <div className="absolute bottom-0 left-0 right-0 p-3 space-y-2">
                    <h3 className="text-white font-bold text-sm line-clamp-2">
                        {anime.title}
                    </h3>
                    
                    {/* Time and Day */}
                    <div className="flex items-center gap-2 text-white/90 text-xs font-medium">
                        <span>{anime.dayOfWeek}</span>
                        {anime.time && (
                            <>
                                <span>•</span>
                                <span className="font-bold text-yellow-300">{anime.time}</span>
                            </>
                        )}
                    </div>

                    {/* Status */}
                    {anime.status && (
                        <p className="text-white/75 text-xs line-clamp-1">
                            {anime.status}
                        </p>
                    )}
                </div>
                
                {/* Actions - small corner buttons (bottom-right) */}
                {hasActions && (
                    <div className="absolute bottom-12 right-1 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity z-10">
                        {canRestore ? (
                            <button
                                className="w-7 h-7 flex items-center justify-center bg-green-600 hover:bg-green-700 rounded-full text-white text-xs shadow-lg transition-colors"
                                onClick={(e) => handleAction(e, () => onRestore?.(anime.id))}
                                onMouseDown={(e) => e.stopPropagation()}
                                title="Supprimer de masqués"
                            >
                                <RestoreIcon sx={{ fontSize: 16 }} />
                            </button>
                        ) : (
                            <>
                                {canRemoveFromNew && (
                                    <button
                                        className="w-7 h-7 flex items-center justify-center bg-blue-600 hover:bg-blue-700 rounded-full text-white text-xs shadow-lg transition-colors"
                                        onClick={(e) => handleAction(e, () => onMarkSeen(anime.id))}
                                        onMouseDown={(e) => e.stopPropagation()}
                                        title="Retirer de nouveaux"
                                    >
                                        <CheckIcon sx={{ fontSize: 16 }} />
                                    </button>
                                )}
                                {canRemoveFromOld && (
                                    <button
                                        className="w-7 h-7 flex items-center justify-center bg-orange-600 hover:bg-orange-700 rounded-full text-white text-xs shadow-lg transition-colors"
                                        onClick={(e) => handleAction(e, () => onRemoveOld?.(anime.id))}
                                        onMouseDown={(e) => e.stopPropagation()}
                                        title="Supprimer de anciens"
                                    >
                                        <CloseIcon sx={{ fontSize: 16 }} />
                                    </button>
                                )}
                                {canHide && (
                                    <button
                                        className="w-7 h-7 flex items-center justify-center bg-red-600 hover:bg-red-700 rounded-full text-white text-xs shadow-lg transition-colors"
                                        onClick={(e) => handleAction(e, () => onHide(anime.id))}
                                        onMouseDown={(e) => e.stopPropagation()}
                                        title="Masquer"
                                    >
                                        <CloseIcon sx={{ fontSize: 16 }} />
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
