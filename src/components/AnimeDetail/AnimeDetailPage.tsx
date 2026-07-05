import React, { useState, useEffect, useCallback } from 'react';
import { AnimePlanning } from '../../types/anime.types';
import { useAnimeSeasons } from '../../hooks/useAnimeSeasons';
import { useAnimeData } from '../../hooks/useAnimeData';
import { animeStorage } from '../../services/api/anime.storage';
import { extractCatalogSlug, formatWatchTime, EPISODE_MINUTES, FILM_MINUTES } from '../../utils/anime.utils';
import { getEpisodeProgress, setEpisodeProgress } from '../../utils/episode-progress.utils';
import { CircularProgress } from '@mui/material';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import RadioButtonUncheckedIcon from '@mui/icons-material/RadioButtonUnchecked';
import PlayArrowIcon from '@mui/icons-material/PlayArrow';
import CloseIcon from '@mui/icons-material/Close';

interface AnimeDetailPageProps {
    anime: AnimePlanning;
    onBack: () => void;
    theme?: 'light' | 'dark';
}

interface SeasonEpisodeInfo {
    episodeCount: number;
    lastEpisode: number;
}

export const AnimeDetailPage: React.FC<AnimeDetailPageProps> = ({ anime, onBack, theme = 'light' }) => {
    const slug = extractCatalogSlug(anime.fullUrl || anime.url);
    const { data: seasonsData, loading: loadingSeasons } = useAnimeSeasons(slug || null);
    const { markAsViewed } = useAnimeData();
    const [viewedSeasons, setViewedSeasons] = useState<string[]>([]);
    const [activePlayerUrl, setActivePlayerUrl] = useState<string | null>(null);
    const [activeSeasonName, setActiveSeasonName] = useState<string>('');
    const [episodeInfo, setEpisodeInfo] = useState<Record<string, SeasonEpisodeInfo>>({});
    const [loadingEpisodes, setLoadingEpisodes] = useState<Record<string, boolean>>({});

    const isDarkMode = theme === 'dark' || (typeof document !== 'undefined' && document.documentElement.classList.contains('dark'));

    const loadViewedSeasons = useCallback(() => {
        const viewedAnime = animeStorage.findViewedAnime(anime);
        setViewedSeasons(viewedAnime?.viewedSeasons || []);
    }, [anime]);

    useEffect(() => {
        loadViewedSeasons();
    }, [loadViewedSeasons]);

    const fetchEpisodeCount = useCallback(async (seasonUrl: string, seasonName: string) => {
        setLoadingEpisodes(prev => ({ ...prev, [seasonName]: true }));
        try {
            const encoded = encodeURIComponent(seasonUrl);
            const response = await fetch(`/api/animes/seasons/${slug}/episodes?url=${encoded}`);
            const json = await response.json();
            const episodeCount = json.success ? (json.data?.episodeCount || 0) : 0;
            const progress = getEpisodeProgress(seasonUrl);

            setEpisodeInfo(prev => ({
                ...prev,
                [seasonName]: {
                    episodeCount,
                    lastEpisode: progress?.lastEpisode || 0,
                },
            }));
        } catch {
            setEpisodeInfo(prev => ({
                ...prev,
                [seasonName]: { episodeCount: 0, lastEpisode: getEpisodeProgress(seasonUrl)?.lastEpisode || 0 },
            }));
        } finally {
            setLoadingEpisodes(prev => ({ ...prev, [seasonName]: false }));
        }
    }, [slug]);

    useEffect(() => {
        if (!seasonsData?.seasons) return;
        seasonsData.seasons.forEach(season => {
            fetchEpisodeCount(season.url, season.name);
        });
    }, [seasonsData, fetchEpisodeCount]);

    const persistSeasons = (seasons: string[]) => {
        setViewedSeasons(seasons);
        animeStorage.updateViewedSeasons(anime, seasons);
    };

    const handleSeasonToggle = (seasonName: string) => {
        const updated = viewedSeasons.includes(seasonName)
            ? viewedSeasons.filter(s => s !== seasonName)
            : [...viewedSeasons, seasonName];

        persistSeasons(updated);

        if (seasonsData?.seasons) {
            const allViewed = seasonsData.seasons.every(s => updated.includes(s.name));
            if (allViewed) {
                markAsViewed({ ...anime, viewedSeasons: updated }, updated);
            }
        }
    };

    const handleMarkAll = () => {
        if (!seasonsData?.seasons) return;
        const all = seasonsData.seasons.map(s => s.name);
        persistSeasons(all);
        markAsViewed({ ...anime, viewedSeasons: all }, all);
    };

    const handleClearAll = () => {
        persistSeasons([]);
    };

    const handlePlaySeason = (seasonUrl: string, seasonName: string) => {
        setActivePlayerUrl(seasonUrl);
        setActiveSeasonName(seasonName);
    };

    const handleEpisodeChange = (seasonUrl: string, seasonName: string, episode: number) => {
        const total = episodeInfo[seasonName]?.episodeCount;
        setEpisodeProgress(seasonUrl, episode, total);
        setEpisodeInfo(prev => ({
            ...prev,
            [seasonName]: {
                ...prev[seasonName],
                lastEpisode: episode,
            },
        }));
    };

    const estimatedWatchMinutes = seasonsData?.seasons
        ? seasonsData.seasons
            .filter(s => viewedSeasons.includes(s.name))
            .reduce((total, season) => {
                if (season.type === 'film') return total + FILM_MINUTES;
                const info = episodeInfo[season.name];
                const eps = info?.episodeCount && info.episodeCount > 0 ? info.episodeCount : 12;
                return total + eps * EPISODE_MINUTES;
            }, 0)
        : 0;

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
                                    {seasonsData?.totalSeasons != null && (
                                        <p><strong>Saisons:</strong> {seasonsData.totalSeasons}</p>
                                    )}
                                    {estimatedWatchMinutes > 0 && (
                                        <p><strong>Temps de visionnage estimé:</strong> {formatWatchTime(estimatedWatchMinutes)}</p>
                                    )}
                                    {anime.fullUrl && (
                                        <p>
                                            <strong>URL:</strong>{' '}
                                            <a
                                                href={anime.fullUrl}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="underline text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300"
                                            >
                                                {anime.fullUrl.replace(/^https?:\/\//, '').split('/')[0]}
                                            </a>
                                        </p>
                                    )}
                                </div>
                            </div>
                        </div>
                    </div>

                    {activePlayerUrl && (
                        <div className="mb-8 rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden bg-black">
                            <div className="flex items-center justify-between px-4 py-2 bg-gray-900 text-white">
                                <span className="font-medium">Lecteur — {activeSeasonName}</span>
                                <button
                                    onClick={() => setActivePlayerUrl(null)}
                                    className="p-1 hover:bg-gray-700 rounded"
                                >
                                    <CloseIcon fontSize="small" />
                                </button>
                            </div>
                            <iframe
                                src={activePlayerUrl}
                                title={`Lecteur ${activeSeasonName}`}
                                className="w-full h-[480px]"
                                sandbox="allow-scripts allow-same-origin allow-popups allow-forms"
                            />
                            {episodeInfo[activeSeasonName] && (
                                <div className="px-4 py-3 bg-gray-800 text-white flex items-center gap-4">
                                    <label className="text-sm">Épisode en cours:</label>
                                    <input
                                        type="number"
                                        min={1}
                                        max={episodeInfo[activeSeasonName].episodeCount || 999}
                                        value={episodeInfo[activeSeasonName].lastEpisode || 1}
                                        onChange={(e) => {
                                            const ep = parseInt(e.target.value, 10) || 1;
                                            handleEpisodeChange(activePlayerUrl, activeSeasonName, ep);
                                        }}
                                        className="w-20 px-2 py-1 rounded text-gray-900 text-sm"
                                    />
                                    {episodeInfo[activeSeasonName].episodeCount > 0 && (
                                        <span className="text-sm text-gray-300">
                                            / {episodeInfo[activeSeasonName].episodeCount} épisodes
                                        </span>
                                    )}
                                </div>
                            )}
                        </div>
                    )}

                    <hr className="border-gray-300 dark:border-gray-700" />

                    <div className="mt-8">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-xl font-bold">Saisons disponibles</h3>
                            {seasonsData?.seasons && seasonsData.seasons.length > 0 && (
                                <div className="flex gap-2">
                                    <button
                                        onClick={handleMarkAll}
                                        className="px-4 py-2 rounded text-sm font-semibold transition-colors bg-green-600 dark:bg-green-700 text-white hover:bg-green-700 dark:hover:bg-green-800"
                                    >
                                        Tout marquer vu
                                    </button>
                                    <button
                                        onClick={handleClearAll}
                                        className="px-4 py-2 rounded text-sm font-semibold transition-colors bg-red-600 dark:bg-red-700 text-white hover:bg-red-700 dark:hover:bg-red-800"
                                    >
                                        Tout effacer
                                    </button>
                                </div>
                            )}
                        </div>

                        {loadingSeasons && (
                            <div className="flex justify-center py-12">
                                <CircularProgress />
                            </div>
                        )}

                        {!loadingSeasons && seasonsData?.seasons && seasonsData.seasons.length > 0 ? (
                            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                                {seasonsData.seasons.map((season, idx) => {
                                    const isViewed = viewedSeasons.includes(season.name);
                                    const info = episodeInfo[season.name];
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
                                            className={`relative overflow-hidden rounded-lg transition-all duration-300 p-4 border-2 ${
                                                isViewed
                                                    ? `bg-gradient-to-br ${color.bg} ${color.border}`
                                                    : 'bg-gray-100 dark:bg-gray-800 border-gray-300 dark:border-gray-600'
                                            }`}
                                        >
                                            <div className="relative flex flex-col gap-3">
                                                <div
                                                    className="flex items-center justify-between gap-3 cursor-pointer"
                                                    onClick={() => handleSeasonToggle(season.name)}
                                                >
                                                    <div className="flex-1 min-w-0">
                                                        <p className={`font-bold truncate ${isViewed ? color.text : 'text-gray-900 dark:text-white'}`}>
                                                            {season.name}
                                                        </p>
                                                        <p className={`text-xs mt-1 ${isViewed ? color.text + ' opacity-90' : 'text-gray-600 dark:text-gray-400'}`}>
                                                            {season.type}
                                                            {info?.episodeCount ? ` · ${info.episodeCount} ép.` : ''}
                                                            {info?.lastEpisode ? ` · Ép. ${info.lastEpisode}` : ''}
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
                                                <button
                                                    onClick={() => handlePlaySeason(season.url, season.name)}
                                                    disabled={loadingEpisodes[season.name]}
                                                    className="flex items-center justify-center gap-1 px-3 py-2 rounded text-sm font-medium bg-blue-600 text-white hover:bg-blue-700 transition-colors"
                                                >
                                                    <PlayArrowIcon sx={{ fontSize: 18 }} />
                                                    {loadingEpisodes[season.name] ? 'Chargement...' : 'Regarder'}
                                                </button>
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
