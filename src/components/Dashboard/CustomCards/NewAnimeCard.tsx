import React from 'react';
import { AlertTriangle, Calendar, Check, Clock, ExternalLink, Image, Newspaper, PartyPopper, Sparkles, Telescope, Timer, Tv, X } from 'lucide-react';
import { useLocalAnimeData } from '../../../hooks/useLocalAnimeData';

interface NewAnimeCardProps {
    title?: string;
}

const NewAnimeCard: React.FC<NewAnimeCardProps> = ({ title = "Nouveaux Animes" }) => {    const {
        newAnimes,
        loading,
        error,
        hideAnime,
        markAsViewed
    } = useLocalAnimeData({
        fetchTodayOnly: false,
        autoRefresh: true
    });
    return (
        <div className="bg-gray-800 rounded-lg p-4 h-full flex flex-col">            <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-semibold text-white flex items-center">
                    <Telescope className="mr-2 text-blue-400" size={20} />
                    {title}
                </h3>
            </div>
            <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2 text-xs">
                    <div className="bg-blue-600/20 text-blue-400 px-2 py-1 rounded flex items-center gap-1">
                        <PartyPopper size={12} />
                        Nouveautés
                    </div>
                </div>

                {newAnimes && (
                    <div className="text-xs text-gray-400">
                        {newAnimes.length} nouveau(x)
                    </div>
                )}
            </div>            {/* Contenu */}
            <div className="flex-1 overflow-hidden">
                <div className="h-full space-y-2 overflow-y-auto scrollbar-thin scrollbar-track-gray-700 scrollbar-thumb-gray-500 hover:scrollbar-thumb-gray-400 pr-2">
                    {loading && (
                        <div className="text-center py-6">
                            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-green-500 mx-auto mb-2"></div>
                            <p className="text-gray-400 text-sm">Chargement...</p>
                        </div>
                    )}                    {error && (
                        <div className="bg-red-900/30 border border-red-500 rounded p-3">
                            <p className="text-red-400 text-sm flex items-center gap-2">
                                <AlertTriangle size={16} />
                                {error}
                            </p>
                        </div>
                    )}{!loading && !error && (!newAnimes || newAnimes.length === 0) && (
                        <div className="text-center py-6">
                            <div className="flex justify-center mb-3">
                                <Sparkles color='#fbbf24' size="48" className="text-amber-400" />
                            </div>
                            <p className="text-gray-400 text-sm">Aucun nouvel anime</p>
                            <p className="text-gray-500 text-xs mt-1">Tous les animes sont déjà connus</p>
                        </div>
                    )}

                    {!loading && !error && newAnimes && newAnimes.length > 0 && (
                        <>
                            {newAnimes.map((anime, index) => (
                                <div
                                    key={anime.id || index}
                                    className="flex items-center space-x-3 p-3 bg-green-800/20 rounded transition-colors group cursor-pointer"
                                    onClick={() =>anime.fullUrl && window.open(anime.fullUrl, '_blank')}
                                >
                                    {anime.imageUrl ? (
                                        <img
                                            src={anime.imageUrl}
                                            alt={anime.title}
                                            draggable="false"
                                            className="w-10 h-14 object-cover rounded"
                                            onError={(e) => {
                                                e.currentTarget.style.display = 'none';
                                            }}
                                        />                                    ) : (
                                        <div className="w-10 h-14 bg-gray-600 rounded flex items-center justify-center">
                                            <Image className="text-gray-400" size={20} />
                                        </div>
                                    )}

                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center justify-between">                                            
                                            <h4 className="font-medium text-white truncate flex items-center">
                                                <Sparkles className="text-green-400 mr-2" size={16} />
                                                {anime.title}
                                            </h4><div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                                <button
                                                    onClick={() => markAsViewed(anime.id)}
                                                    className="text-xs px-2 py-1 bg-green-600/20 text-green-400 rounded hover:bg-green-600/40"
                                                    title="Marquer comme vu"
                                                >
                                                    <Check size={12} />
                                                </button>

                                                <button
                                                    onClick={() => hideAnime(anime.id)}
                                                    className="text-xs px-2 py-1 bg-red-600/20 text-red-400 rounded hover:bg-red-600/40"
                                                    title="Ne plus afficher"
                                                >
                                                    <X size={12} />
                                                </button>
                                            </div>
                                        </div>                                        
                                        <div className="flex items-center space-x-2 mt-1">
                                            <span className="text-xs bg-blue-600 text-white px-2 py-1 rounded flex items-center gap-1">
                                                <Calendar size={12} />
                                                {anime.dayOfWeek}
                                            </span>

                                            {anime.time && (
                                                <span className="text-xs text-gray-400 flex items-center gap-1">
                                                    <Clock size={12} />
                                                    {anime.time}
                                                </span>
                                            )}

                                            {anime.status && (
                                                <span className="text-xs text-red-400 flex items-center gap-1">
                                                    <AlertTriangle size={12} />
                                                    {anime.status}
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </>)}
                </div>
            </div>
        </div>
    );
};

export default NewAnimeCard;
