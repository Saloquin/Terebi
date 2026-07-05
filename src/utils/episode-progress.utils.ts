const EPISODE_PROGRESS_KEY = 'anime_episode_progress';

export interface EpisodeProgress {
    seasonUrl: string;
    lastEpisode: number;
    totalEpisodes?: number;
    updatedAt: string;
}

interface EpisodeProgressStore {
    [seasonUrl: string]: EpisodeProgress;
}

const readStore = (): EpisodeProgressStore => {
    try {
        const raw = localStorage.getItem(EPISODE_PROGRESS_KEY);
        return raw ? JSON.parse(raw) : {};
    } catch {
        return {};
    }
};

const writeStore = (store: EpisodeProgressStore): void => {
    localStorage.setItem(EPISODE_PROGRESS_KEY, JSON.stringify(store));
};

export const getEpisodeProgress = (seasonUrl: string): EpisodeProgress | null => {
    return readStore()[seasonUrl] || null;
};

export const setEpisodeProgress = (
    seasonUrl: string,
    lastEpisode: number,
    totalEpisodes?: number
): void => {
    const store = readStore();
    store[seasonUrl] = {
        seasonUrl,
        lastEpisode,
        totalEpisodes,
        updatedAt: new Date().toISOString(),
    };
    writeStore(store);
};

export const getAllEpisodeProgress = (): EpisodeProgress[] => {
    return Object.values(readStore());
};

export const getTotalWatchedMinutes = (
    viewedSeasons: { type: string; episodeCount?: number }[]
): number => {
    const EPISODE_MINUTES = 24;
    const FILM_MINUTES = 120;

    return viewedSeasons.reduce((total, season) => {
        if (season.type === 'film') {
            return total + FILM_MINUTES;
        }
        const eps = season.episodeCount && season.episodeCount > 0 ? season.episodeCount : 12;
        return total + eps * EPISODE_MINUTES;
    }, 0);
};
