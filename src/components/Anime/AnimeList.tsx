import React, { useMemo } from 'react';
import { AnimePlanning } from '../../types/anime.types';
import AnimeCard from './AnimeCard';
import InboxIcon from '@mui/icons-material/Inbox';

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
    headerColor?: string;
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
    headerColor,
}) => {
    const resolvedHeaderColor = headerColor || (isNewList ? 'bg-green-600' : isOldList ? 'bg-orange-600' : isHiddenList ? 'bg-gray-600' : 'bg-blue-600');

    // Grouper par jour
    const groupedAnimes = useMemo(() => {
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
    }, [animes]);

    if (animes.length === 0) {
        return (
            <div className="flex flex-col items-center justify-center py-16 text-gray-500">
                <InboxIcon sx={{ fontSize: 64 }} />
                <p className="text-lg">{emptyMessage}</p>
            </div>
        );
    }

    const dayCount = Object.keys(groupedAnimes).length;
    return (
        <div className="h-full grid gap-3" style={{ gridTemplateColumns: `repeat(${dayCount}, minmax(0, 1fr))` }}>
            {Object.entries(groupedAnimes).map(([day, dayAnimes]) => (
                <div 
                    key={day} 
                    className="bg-white dark:bg-gray-800 rounded-xl shadow-lg overflow-hidden min-w-0 flex flex-col"
                >
                    {/* Header du jour */}
                    <div className={`${resolvedHeaderColor} px-3 py-2 flex-shrink-0`}>
                        <h2 className="text-sm font-bold text-white flex items-center justify-between">
                            <span className="truncate">{day}</span>
                            <span className="px-2 py-0.5 text-xs bg-white/20 rounded-full ml-1 flex-shrink-0">
                                {dayAnimes.length}
                            </span>
                        </h2>
                    </div>
                    
                    {/* Liste des animes du jour */}
                    <div className="flex-1 overflow-y-auto p-2 space-y-2">
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
};

export default AnimeList;
