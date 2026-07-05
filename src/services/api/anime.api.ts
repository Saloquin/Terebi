import { AnimePlanning, ApiResponse } from '../../types/anime.types';

const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';

class AnimeApiService {
    private async fetch<T>(endpoint: string, options?: RequestInit): Promise<ApiResponse<T>> {
        try {
            const response = await fetch(`${API_BASE_URL}${endpoint}`, {
                ...options,
                headers: {
                    'Content-Type': 'application/json',
                    ...options?.headers,
                },
            });

            if (!response.ok) {
                let errorMessage = `Erreur HTTP ${response.status}`;
                try {
                    const errorBody = await response.json();
                    if (errorBody?.error) {
                        errorMessage = errorBody.error;
                    }
                } catch {
                    // ignore non-JSON error bodies
                }
                return {
                    success: false,
                    data: null,
                    error: errorMessage,
                    timestamp: new Date().toISOString(),
                };
            }

            return await response.json();
        } catch (error) {
            console.error('❌ Erreur API:', error);
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur réseau',
                timestamp: new Date().toISOString(),
            };
        }
    }

    async getAll(): Promise<ApiResponse<AnimePlanning[]>> {
        console.log('📡 Appel API: GET /animes');
        return this.fetch<AnimePlanning[]>('/animes');
    }

    async getToday(): Promise<ApiResponse<AnimePlanning[]>> {
        return this.fetch<AnimePlanning[]>('/animes/today');
    }

    async getByDay(day: string): Promise<ApiResponse<AnimePlanning[]>> {
        return this.fetch<AnimePlanning[]>(`/animes/day/${day}`);
    }

    async refresh(): Promise<ApiResponse<AnimePlanning[]>> {
        console.log('🔄 Appel API: POST /animes/refresh');
        return this.fetch<AnimePlanning[]>('/animes/refresh', { method: 'POST' });
    }
}

export const animeApi = new AnimeApiService();
