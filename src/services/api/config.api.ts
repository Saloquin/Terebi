const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';

export interface AppConfig {
    extension: string;
    baseUrl: string;
}

class ConfigApiService {
    async getConfig(): Promise<AppConfig> {
        try {
            const res = await fetch(`${API_BASE_URL}/config`);
            const data = await res.json();
            if (data.success) return data.data;
            throw new Error(data.error);
        } catch (error) {
            console.error('❌ Erreur config:', error);
            return { extension: 'to', baseUrl: 'https://anime-sama.to' };
        }
    }

    async setExtension(extension: string): Promise<AppConfig> {
        const res = await fetch(`${API_BASE_URL}/config`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ extension }),
        });
        const data = await res.json();
        if (data.success) return data.data;
        throw new Error(data.error || 'Erreur lors du changement d\'extension');
    }
}

export const configApi = new ConfigApiService();
