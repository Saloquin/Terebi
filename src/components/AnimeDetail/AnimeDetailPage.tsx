import React, { useState, useEffect } from 'react';
import { AnimePlanning } from '../../types/anime.types';
import { useAnimeSeasons } from '../../hooks/useAnimeSeasons';
import { CircularProgress } from '@mui/material';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import RadioButtonUncheckedIcon from '@mui/icons-material/RadioButtonUnchecked';

interface AnimeDetailPageProps {
    anime: AnimePlanning;
    onBack: () => void;
    theme?: 'light' | 'dark';
}

export const AnimeDetailPage: React.FC<AnimeDetailPageProps> = ({ anime, onBack, theme = 'light' }) => {
    const slug = anime?.fullUrl?.match(/\/catalogue\/([^/]+)/)?.[1] || '';
    const { data: seasonsData, loading: loadingSeasons } = useAnimeSeasons(slug);
    const [viewedSeasons, setViewedSeasons] = useState<string[]>([]);
    
    // Check if dark mode is active
    const isDarkMode = theme === 'dark' || (typeof document !== 'undefined' && document.documentElement.classList.contains('dark'));

    useEffect(() => {
        const storage = localStorage.getItem('anime_dashboard_v2');
        if (storage) {
            try {
                const parsed = JSON.parse(storage);
                
                const viewedAnime = parsed.viewed?.find((a: any) => a.id === anime.id);
                if (viewedAnime?.viewedSeasons) {
                    setViewedSeasons(viewedAnime.viewedSeasons);
                }
            } catch {
                // ignore
            }
        }
    }, [anime.id]);

    const saveSeasons = (seasons: string[]) => {
        const storage = localStorage.getItem('anime_dashboard_v2');
        if (storage) {
            try {
                const parsed = JSON.parse(storage);
                const viewedIndex = parsed.viewed.findIndex((a: any) => a.id === anime.id);
                if (viewedIndex >= 0) {
                    parsed.viewed[viewedIndex].viewedSeasons = seasons;
                } else {
                    parsed.viewed.push({ ...anime, viewedAt: new Date().toISOString(), viewedSeasons: seasons });
                }
                localStorage.setItem('anime_dashboard_v2', JSON.stringify(parsed));
            } catch {
                // ignore
            }
        }
    };

    const handleSeasonToggle = (seasonName: string) => {
        const updated = viewedSeasons.includes(seasonName)
            ? viewedSeasons.filter(s => s !== seasonName)
            : [...viewedSeasons, seasonName];
        setViewedSeasons(updated);
        saveSeasons(updated);
        
        // Check if all seasons are now viewed
        if (seasonsData?.seasons) {
            const allViewed = seasonsData.seasons.every(s => 
                updated.includes(s.name) || updated.some(vs => vs === s.name)
            );
            
            // If all seasons are viewed, move anime from towatch to viewed
            if (allViewed) {
                moveToViewed();
            }
        }
    };

    const moveToViewed = () => {
        const storage = localStorage.getItem('anime_dashboard_v2');
        if (storage) {
            try {
                const parsed = JSON.parse(storage);
                
                // Remove from towatch if present
                if (parsed.towatch) {
                    parsed.towatch = parsed.towatch.filter((a: any) => a.id !== anime.id);
                }
                
                // Add to viewed if not already there
                const existingViewed = parsed.viewed?.findIndex((a: any) => a.id === anime.id) ?? -1;
                if (existingViewed === -1) {
                    if (!parsed.viewed) parsed.viewed = [];
                    parsed.viewed.push({
                        ...anime,
                        viewedAt: new Date().toISOString(),
                        viewedSeasons: viewedSeasons
                    });
                }
                
                localStorage.setItem('anime_dashboard_v2', JSON.stringify(parsed));
            } catch {
                // ignore
            }
        }
    };

    return (
        <div className={isDarkMode ? 'dark' : ''}>
            <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
                <div className="sticky top-0 z-40 border-b border-gray-200 dark:border-gray-700 backdrop-blur-sm bg-white/80 dark:bg-gray-800/80">
                    <div className="max-w-4xl mx-auto px-4 py-4 flex items-center gap-4">
                        <button 
                            onClick={onBack} 
                            className="flex items-center gap-2 px-3 py-2 rounded transition-all text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
                        >
                            <ArrowBackIcon fontSize="small" />
                            Retour
                        </button>
                        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
                            {anime.title}
                        </h1>
                    </div>
                </div>

                <div className="max-w-4xl mx-auto px-4 py-8">
                    <div className="rounded-lg p-6 mb-8 border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800">
                        <div className="flex gap-6">
                            {anime.image && (
                                <img 
                                    src={anime.image} 
                                    alt={anime.title} 
                                    className="w-48 h-64 object-cover rounded-lg flex-shrink-0 shadow-lg" 
                                />
                            )}
                            <div className="flex-1">
                                <h2 className="text-2xl font-bold mb-4 text-gray-900 dark:text-white">
                                    {anime.title}
                                </h2>
                                <div className="flex flex-wrap gap-2 mb-4">
                                    <span className="px-3 py-1 rounded text-xs font-semibold bg-purple-100 dark:bg-purple-900 text-purple-700 dark:text-purple-300">
                                        {anime.type}
                                    </span>
                                    {anime.dayOfWeek && (
                                        <span className="px-3 py-1 rounded text-xs font-semibold bg-blue-100 dark:bg-blue-900 text-blue-700 dark:text-blue-300">
                                            {anime.dayOfWeek}
                                        </span>
                                    )}
                                </div>
                                <div className="space-y-2 text-sm text-gray-700 dark:text-gray-300">
                                    {anime.status && <p><strong>État:</strong> {anime.status}</p>}
                                    {seasonsData?.totalSeasons && <p><strong>Saisons:</strong> {seasonsData.totalSeasons}</p>}
                                    <p>
                                        <strong>URL:</strong> <a 
                                            href={anime.fullUrl} 
                                            target="_blank" 
                                            rel="noopener noreferrer" 
                                            className="underline text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300"
                                        >
                                            anime-sama.to
                                        </a>
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <hr className="border-gray-300 dark:border-gray-700" />

                    <div className="mt-8">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-xl font-bold">Saisons disponibles</h3>
                            {seasonsData?.seasons && seasonsData.seasons.length > 0 && (
                                <div className="flex gap-2">
                                    <button 
                                        onClick={() => { 
                                            const all = seasonsData.seasons.map(s => s.name); 
                                            setViewedSeasons(all); 
                                            saveSeasons(all); 
                                        }} 
                                        className="px-4 py-2 rounded text-sm font-semibold transition-colors bg-green-600 dark:bg-green-700 text-white hover:bg-green-700 dark:hover:bg-green-800"
                                    >
                                        Tout marquer vu
                                    </button>
                                    <button 
                                        onClick={() => { 
                                            setViewedSeasons([]); 
                                            saveSeasons([]); 
                                        }} 
                                        className="px-4 py-2 rounded text-sm font-semibold transition-colors bg-red-600 dark:bg-red-700 text-white hover:bg-red-700 dark:hover:bg-red-800"
                                    >
                                        Tout effacer
                                    </button>
                                </div>
                            )}
                        </div>

                        {loadingSeasons && <div className="flex justify-center py-12"><CircularProgress /></div>}

                        {!loadingSeasons && seasonsData?.seasons && seasonsData.seasons.length > 0 ? (
                            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                                {seasonsData.seasons.map((season, idx) => {
                                    const isViewed = viewedSeasons.includes(season.name);
                                    const colors = [
                                        { bg: 'from-pink-400 to-rose-500 dark:from-pink-900 dark:to-rose-800', border: 'border-pink-300 dark:border-pink-600', text: 'text-pink-900 dark:text-pink-100' },
                                        { bg: 'from-purple-400 to-indigo-500 dark:from-purple-900 dark:to-indigo-800', border: 'border-purple-300 dark:border-purple-600', text: 'text-purple-900 dark:text-purple-100' },
                                        { bg: 'from-blue-400 to-cyan-500 dark:from-blue-900 dark:to-cyan-800', border: 'border-blue-300 dark:border-blue-600', text: 'text-blue-900 dark:text-blue-100' },
                                        { bg: 'from-green-400 to-emerald-500 dark:from-green-900 dark:to-emerald-800', border: 'border-green-300 dark:border-green-600', text: 'text-green-900 dark:text-green-100' },
                                        { bg: 'from-yellow-400 to-amber-500 dark:from-yellow-900 dark:to-amber-800', border: 'border-yellow-300 dark:border-yellow-600', text: 'text-yellow-900 dark:text-yellow-100' },
                                    ];
                                    const color = colors[idx % colors.length];
                                    return (
                                        <div
                                            key={season.name}
                                            onClick={() => handleSeasonToggle(season.name)}
                                            className={`relative overflow-hidden rounded-lg cursor-pointer transition-all duration-300 transform hover:scale-105 p-4 border-2 ${
                                                isViewed
                                                    ? `bg-gradient-to-br ${color.bg} ${color.border}`
                                                    : 'bg-gray-100 dark:bg-gray-800 border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500'
                                            }`}
                                        >
                                            <div className="absolute inset-0 opacity-5 bg-gradient-to-br from-white to-transparent" />
                                            <div className="relative flex items-center justify-between gap-3">
                                                <div className="flex-1 min-w-0">
                                                    <p className={`font-bold truncate ${isViewed ? color.text : 'text-gray-900 dark:text-white'}`}>
                                                        {season.name}
                                                    </p>
                                                    <p className={`text-xs mt-1 ${isViewed ? color.text + ' opacity-90' : 'text-gray-600 dark:text-gray-400'}`}>
                                                        {season.type}
                                                    </p>
                                                </div>
                                                <div className="flex-shrink-0">
                                                    {isViewed ? (
                                                        <CheckCircleIcon sx={{ fontSize: 32, color: 'white', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.3))' }} />
                                                    ) : (
                                                        <RadioButtonUncheckedIcon sx={{ fontSize: 32, color: '#d1d5db' }} className="dark:text-gray-400" />
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        ) : !loadingSeasons ? (
                            <p className="text-center py-8 text-gray-500 dark:text-gray-400">Aucune saison trouvée.</p>
                        ) : null}
                    </div>

                    {seasonsData?.seasons && seasonsData.seasons.length > 0 && (
                        <div className="mt-8 p-4 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
                            <p className="text-sm font-semibold mb-3 text-gray-900 dark:text-white">
                                Progression: <span className="font-bold">{viewedSeasons.length}</span> / <span className="font-bold">{seasonsData.seasons.length}</span> saison{seasonsData.seasons.length > 1 ? 's' : ''}
                            </p>
                            <div className="h-3 rounded-full overflow-hidden bg-gray-200 dark:bg-gray-700">
                                <div 
                                    className="h-full bg-gradient-to-r from-green-500 to-emerald-500 transition-all duration-300" 
                                    style={{ width: `${(viewedSeasons.length / seasonsData.seasons.length) * 100}%` }} 
                                />
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default AnimeDetailPage;
