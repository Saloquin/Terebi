import React, { useMemo } from 'react';
import { AlertTriangle, Calendar, Clock, ExternalLink, Hourglass, Image, Timer, X } from 'lucide-react';
import { useLocalAnimeData } from '../../../hooks/useLocalAnimeData';

interface NextAnimeCardProps {
    title?: string;
}

const NextAnimeCard: React.FC<NextAnimeCardProps> = ({ title = "Prochain Anime" }) => {    const {
        data,
        loading,
        error,
        hideAnime
    } = useLocalAnimeData({
        fetchTodayOnly: false,
        autoRefresh: true
    });

    // Calculer le prochain anime
    const nextAnime = useMemo(() => {
        if (!data || data.length === 0) return null;

        const now = new Date();
        const currentDay = now.getDay(); // 0 = dimanche, 1 = lundi, etc.
        const currentTime = now.getHours() * 60 + now.getMinutes();

        // Mapper les jours de la semaine
        const dayMap: Record<string, number> = {
            'Dimanche': 0,
            'Lundi': 1,
            'Mardi': 2,
            'Mercredi': 3,
            'Jeudi': 4,
            'Vendredi': 5,
            'Samedi': 6
        };

        // Convertir l'heure en minutes
        const parseTime = (timeStr: string): number => {
            const match = timeStr.match(/(\d{1,2})[h:](\d{2})/);
            if (!match) return 0;
            return parseInt(match[1]) * 60 + parseInt(match[2]);
        };

        // Créer une liste des animes avec leurs temps calculés
        const animesWithTime = data.map(anime => {
            const animeDay = dayMap[anime.dayOfWeek] ?? 0;
            const animeTime = anime.time ? parseTime(anime.time) : 0;

            // Calculer les minutes jusqu'à cet anime
            let minutesUntil = 0;

            if (animeDay === currentDay && animeTime > currentTime) {
                // Aujourd'hui, mais plus tard
                minutesUntil = animeTime - currentTime;
            } else if (animeDay > currentDay) {
                // Cette semaine
                minutesUntil = (animeDay - currentDay) * 24 * 60 + animeTime - currentTime;
            } else {
                // Semaine prochaine
                minutesUntil = (7 - currentDay + animeDay) * 24 * 60 + animeTime - currentTime;
            }

            return {
                ...anime,
                minutesUntil,
                animeDay
            };
        });

        // Trier par proximité et prendre le premier
        const sortedAnimes = animesWithTime
            .filter(anime => anime.minutesUntil > 0)
            .sort((a, b) => a.minutesUntil - b.minutesUntil);

        return sortedAnimes[0] || null;
    }, [data]);

    // Formater le temps restant
    const formatTimeUntil = (minutes: number): string => {
        if (minutes < 60) {
            return `${minutes} min`;
        } else if (minutes < 24 * 60) {
            const hours = Math.floor(minutes / 60);
            const remainingMinutes = minutes % 60;
            return `${hours}h${remainingMinutes > 0 ? ` ${remainingMinutes}min` : ''}`;
        } else {
            const days = Math.floor(minutes / (24 * 60));
            const remainingHours = Math.floor((minutes % (24 * 60)) / 60);
            return `${days}j${remainingHours > 0 ? ` ${remainingHours}h` : ''}`;
        }
    };

    return (
        <div className="bg-gray-800 rounded-lg p-4 h-full">            <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-semibold text-white flex items-center">
                    <Hourglass className="mr-2 text-blue-400" size={20} />
                    {title}
                </h3>
            </div>            
            <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2 text-xs">
                    <div className="bg-orange-600/20 text-orange-400 px-2 py-1 rounded flex items-center gap-1">
                        <Hourglass size={12} />
                        À venir
                    </div>
                </div>
            </div>

            {/* Contenu */}
            <div className="space-y-2">
                {loading && (
                    <div className="text-center py-6">
                        <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-orange-500 mx-auto mb-2"></div>
                        <p className="text-gray-400 text-sm">Calcul en cours...</p>
                    </div>
                )}                {error && (
                    <div className="bg-red-900/30 border border-red-500 rounded p-3">
                        <p className="text-red-400 text-sm flex items-center gap-2">
                            <AlertTriangle size={16} />
                            {error}
                        </p>
                    </div>
                )}

                {!loading && !error && !nextAnime && (
                    <div className="text-center py-6">
                        <div className="flex justify-center mb-4">
                            <Timer className="text-gray-400" size={48} />
                        </div>
                        <p className="text-gray-400 text-sm">Aucun prochain anime</p>
                        <p className="text-gray-500 text-xs mt-1">Vérifiez le planning</p>
                    </div>
                )}

                {!loading && !error && nextAnime && (
                    <div className="bg-orange-900/20 rounded-lg p-4">
                        <div className="flex items-center space-x-3">
                            {nextAnime.imageUrl ? (
                                <img
                                    src={nextAnime.imageUrl}
                                    alt={nextAnime.title}
                                    draggable="false"
                                    className="w-16 h-20 object-cover rounded"
                                    onError={(e) => {
                                        e.currentTarget.style.display = 'none';
                                    }}
                                />
                            ) : (                                <div className="w-16 h-20 bg-gray-600 rounded flex items-center justify-center">
                                    <Image className="text-gray-400" size={28} />
                                </div>
                            )}

                            <div className="flex-1">
                                <div className="flex items-center justify-between mb-2">
                                    <h4 className="font-bold text-white text-lg">
                                        {nextAnime.title}                                </h4>

                                    <div className="flex items-center gap-1">
                                        {nextAnime.fullUrl && (
                                            <button
                                                onClick={() => window.open(nextAnime.fullUrl, '_blank')}
                                                className="text-xs px-2 py-1 bg-blue-600/20 text-blue-400 rounded hover:bg-blue-600/40"
                                                title="Regarder sur Anime-Sama"
                                            >
                                                <ExternalLink size={12} />
                                            </button>
                                        )}
                                        
                                        <button
                                            onClick={() => hideAnime(nextAnime.id)}
                                            className="text-xs px-2 py-1 bg-red-600/20 text-red-400 rounded hover:bg-red-600/40"
                                            title="Ne plus afficher"
                                        >
                                            <X size={12} />
                                        </button>
                                    </div>
                                </div>                                <div className="space-y-2">
                                    <div className="flex items-center space-x-2">
                                        <span className="text-lg bg-orange-600 text-white px-3 py-1 rounded font-bold flex items-center gap-2">
                                            <Timer size={16} />
                                            Dans {formatTimeUntil(nextAnime.minutesUntil)}
                                        </span>
                                    </div>

                                    <div className="flex items-center space-x-2">
                                        <span className="text-sm bg-blue-600 text-white px-2 py-1 rounded flex items-center gap-1">
                                            <Calendar size={14} />
                                            {nextAnime.dayOfWeek}
                                        </span>

                                        {nextAnime.time && (
                                            <span className="text-sm text-gray-300 flex items-center gap-1">
                                                <Clock size={14} />
                                                {nextAnime.time}
                                            </span>
                                        )}

                                        {nextAnime.status && (
                                            <span className="text-sm text-red-400 flex items-center gap-1">
                                                <AlertTriangle size={14} />
                                                {nextAnime.status}
                                            </span>
                                        )}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

export default NextAnimeCard;
