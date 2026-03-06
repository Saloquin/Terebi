export type AnimeType = 'VOSTFR' | 'VF' | 'Scan' | 'ScanVF';

export interface AnimePlanning {
    id: string;
    title: string;
    image: string;
    imageUrl?: string; // Alias pour compatibilité
    url: string;
    fullUrl?: string;
    dayOfWeek: string;
    time?: string;
    type: AnimeType;
    season?: string;
    status?: string;
}

export interface ApiResponse<T> {
    success: boolean;
    data: T | null;
    error?: string;
    timestamp: string;
}
