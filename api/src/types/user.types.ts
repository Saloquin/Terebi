export interface EpisodeProgress {
    anilistId: number;
    seasonNumber: number;
    lastEpisode: number;
    totalEpisodes?: number;
    updatedAt: string;
}

export interface UserSettings {
    extension: string;
    anilistClientId?: string;
    anilistClientSecret?: string;
    anilistAccessToken?: string;
}

export interface UserListEntry {
    anilistId: number;
    addedAt: string;
}
