export type AnimeType = 'VOSTFR' | 'VF' | 'Scan' | 'ScanVF';

export interface Season {
    name: string;
    url: string;
    type: 'regular' | 'oav' | 'special' | 'film';
}

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
    seasons?: Season[];
    totalSeasons?: number;
    viewedSeasons?: string[]; // Track which seasons have been watched (e.g., ['season-1', 'season-2'])
}

export interface AnimeViewed extends AnimePlanning {
    viewedAt?: string;
}

export interface AnimeStorage {
    current: AnimePlanning[];
    new: AnimePlanning[];
    old: AnimePlanning[];
    hidden: string[]; // On stocke juste les IDs des animes masqués
    towatch: AnimePlanning[]; // À regarder (pas commencé)
    inprogress: AnimeViewed[]; // En cours (partiellement vu)
    completed: AnimeViewed[]; // Complétés (toutes les saisons régulières vues)
    viewed: AnimeViewed[]; // Déjà vu (entièrement fini, y compris spéciaux/films)
    lastUpdate: string;
}

export type ViewMode = 'planning' | 'nouveaux' | 'anciens' | 'masques';
export type DayFilter = 'tous' | 'lundi' | 'mardi' | 'mercredi' | 'jeudi' | 'vendredi' | 'samedi' | 'dimanche' | 'aujourd\'hui';

export interface AnimeStats {
    totalCurrent: number;
    totalNew: number;
    totalOld: number;
    totalHidden: number;
    totalToWatch: number;
    byDay: Record<string, number>;
    lastUpdate?: string;
}

export interface ApiResponse<T> {
    success: boolean;
    data: T | null;
    error?: string;
    timestamp: string;
}
