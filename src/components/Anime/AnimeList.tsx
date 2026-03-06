import React, { useMemo } from 'react';
import { AnimePlanning } from '../../types/anime.types';
import AnimeCard from './AnimeCard';

interface AnimeListProps {
    animes: AnimePlanning[];
    onHide?: (id: string) => void;
    onRestore?: (id: string) => void;
    onMarkSeen?: (id: string) => void;
    showActions?: boolean;
    isHiddenList?: boolean;
    isNewList?: boolean;
    isOldList?: boolean;
    groupByDay?: boolean;
    emptyMessage?: string;
}

const DAY_ORDER = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

export const AnimeList: React.FC<AnimeListProps> = ({
    animes,
    onHide,
    onRestore,
    onMarkSeen,
    showActions = true,
    isHiddenList = false,
    isNewList = false,
    isOldList = false,
    groupByDay = true,
    emptyMessage = 'Aucun anime à afficher',
}) => {
    // Grouper par jour si demandé
    const groupedAnimes = useMemo(() => {
        if (!groupByDay) {
            return { 'Tous': animes };
        }

        const groups: Record<string, AnimePlanning[]> = {};
        
        animes.forEach(anime => {
            const day = anime.dayOfWeek || 'Inconnu';
            if (!groups[day]) {
                groups[day] = [];
            }
            groups[day].push(anime);
        });

        // Trier les jours dans l'ordre
        const sortedGroups: Record<string, AnimePlanning[]> = {};
        DAY_ORDER.forEach(day => {
            const capitalizedDay = day.charAt(0).toUpperCase() + day.slice(1);
            if (groups[capitalizedDay]) {
                sortedGroups[capitalizedDay] = groups[capitalizedDay];
            }
        });

        // Ajouter les jours non reconnus à la fin
        Object.keys(groups).forEach(day => {
            if (!Object.keys(sortedGroups).includes(day)) {
                sortedGroups[day] = groups[day];
            }
        });

        return sortedGroups;
    }, [animes, groupByDay]);

    if (animes.length === 0) {
        return (
            <div className="flex flex-col items-center justify-center py-16 text-gray-500">
                <span className="text-6xl mb-4">📭</span>
                <p className="text-lg">{emptyMessage}</p>
            </div>
        );
    }

    // Vue horizontale pour le planning groupé par jour
    if (groupByDay) {
        const dayCount = Object.keys(groupedAnimes).length;
        return (
            <div className="grid gap-3" style={{ gridTemplateColumns: `repeat(${dayCount}, minmax(0, 1fr))` }}>
                {Object.entries(groupedAnimes).map(([day, dayAnimes]) => (
                    <div 
                        key={day} 
                        className="bg-white dark:bg-gray-800 rounded-xl shadow-lg overflow-hidden min-w-0"
                    >
                        {/* Header du jour */}
                        <div className="sticky top-0 bg-blue-600 px-3 py-2 z-10">
                            <h2 className="text-sm font-bold text-white flex items-center justify-between">
                                <span className="truncate">{day}</span>
                                <span className="px-2 py-0.5 text-xs bg-white/20 rounded-full ml-1 flex-shrink-0">
                                    {dayAnimes.length}
                                </span>
                            </h2>
                        </div>
                        
                        {/* Liste des animes du jour */}
                        <div className="max-h-[75vh] overflow-y-auto p-2 space-y-2">
                            {dayAnimes.map(anime => (
                                <AnimeCard
                                    key={anime.id}
                                    anime={anime}
                                    onHide={onHide}
                                    onRestore={onRestore}
                                    onMarkSeen={onMarkSeen}
                                    showActions={showActions}
                                    isHidden={isHiddenList}
                                    isNew={isNewList}
                                    isOld={isOldList}
                                />
                            ))}
                        </div>
                    </div>
                ))}
            </div>
        );
    }

    // Vue grille standard pour les autres modes
    return (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 2xl:grid-cols-8 gap-4">
            {animes.map(anime => (
                <AnimeCard
                    key={anime.id}
                    anime={anime}
                    onHide={onHide}
                    onRestore={onRestore}
                    onMarkSeen={onMarkSeen}
                    showActions={showActions}
                    isHidden={isHiddenList}
                    isNew={isNewList}
                    isOld={isOldList}
                />
            ))}
        </div>
    );
};

export default AnimeList;
