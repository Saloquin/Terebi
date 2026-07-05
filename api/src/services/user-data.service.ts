import { getDb } from '../db/init';
import { EpisodeProgress, UserListEntry, UserSettings } from '../types/user.types';

class UserDataService {
    getHiddenIds(): number[] {
        const db = getDb();
        const rows = db
            .prepare('SELECT anilist_id FROM hidden_animes ORDER BY created_at DESC')
            .all() as Array<{ anilist_id: number }>;
        return rows.map(r => r.anilist_id);
    }

    hideAnime(anilistId: number): number[] {
        const db = getDb();
        db.prepare('INSERT OR IGNORE INTO hidden_animes (anilist_id, created_at) VALUES (?, ?)').run(
            anilistId,
            new Date().toISOString()
        );
        return this.getHiddenIds();
    }

    unhideAnime(anilistId: number): number[] {
        const db = getDb();
        db.prepare('DELETE FROM hidden_animes WHERE anilist_id = ?').run(anilistId);
        return this.getHiddenIds();
    }

    getList(listType: 'towatch' | 'viewed'): UserListEntry[] {
        const db = getDb();
        const rows = db
            .prepare(
                'SELECT anilist_id, added_at FROM user_lists WHERE list_type = ? ORDER BY added_at DESC'
            )
            .all(listType) as Array<{ anilist_id: number; added_at: string }>;
        return rows.map(r => ({ anilistId: r.anilist_id, addedAt: r.added_at }));
    }

    addToList(listType: 'towatch' | 'viewed', anilistId: number): UserListEntry[] {
        const db = getDb();
        db.prepare(
            'INSERT OR IGNORE INTO user_lists (list_type, anilist_id, added_at) VALUES (?, ?, ?)'
        ).run(listType, anilistId, new Date().toISOString());
        return this.getList(listType);
    }

    removeFromList(listType: 'towatch' | 'viewed', anilistId: number): UserListEntry[] {
        const db = getDb();
        db.prepare('DELETE FROM user_lists WHERE list_type = ? AND anilist_id = ?').run(
            listType,
            anilistId
        );
        return this.getList(listType);
    }

    private getSetting(key: string): string | undefined {
        const db = getDb();
        const row = db
            .prepare('SELECT value FROM user_settings WHERE key = ?')
            .get(key) as { value: string } | undefined;
        return row?.value || undefined;
    }

    private setSetting(key: string, value: string): void {
        const db = getDb();
        db.prepare(
            'INSERT INTO user_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value'
        ).run(key, value);
    }

    getSettings(): UserSettings {
        return {
            extension: this.getSetting('extension') || 'to',
            anilistClientId: this.getSetting('anilist_client_id'),
            anilistClientSecret: this.getSetting('anilist_client_secret'),
            anilistAccessToken: this.getSetting('anilist_access_token'),
        };
    }

    /** Returns settings safe for API responses (secrets masked). */
    getSettingsForClient(): UserSettings & { hasClientSecret: boolean; hasAccessToken: boolean } {
        const settings = this.getSettings();
        return {
            extension: settings.extension,
            anilistClientId: settings.anilistClientId || '',
            anilistClientSecret: '',
            anilistAccessToken: '',
            hasClientSecret: Boolean(settings.anilistClientSecret),
            hasAccessToken: Boolean(settings.anilistAccessToken),
        };
    }

    saveSettings(settings: Partial<UserSettings>): UserSettings & { hasClientSecret: boolean; hasAccessToken: boolean } {
        const current = this.getSettings();
        const next = { ...current, ...settings };

        this.setSetting('extension', next.extension);

        if (settings.anilistClientId !== undefined) {
            this.setSetting('anilist_client_id', settings.anilistClientId.trim());
        }
        if (settings.anilistClientSecret !== undefined && settings.anilistClientSecret !== '') {
            this.setSetting('anilist_client_secret', settings.anilistClientSecret.trim());
        }
        if (settings.anilistAccessToken !== undefined && settings.anilistAccessToken !== '') {
            this.setSetting('anilist_access_token', settings.anilistAccessToken.trim());
        }

        return this.getSettingsForClient();
    }

    getAllEpisodeProgress(): EpisodeProgress[] {
        const db = getDb();
        const rows = db
            .prepare(
                'SELECT anilist_id, season_number, last_episode, total_episodes, updated_at FROM episode_progress'
            )
            .all() as Array<{
            anilist_id: number;
            season_number: number;
            last_episode: number;
            total_episodes: number | null;
            updated_at: string;
        }>;
        return rows.map(row => ({
            anilistId: row.anilist_id,
            seasonNumber: row.season_number,
            lastEpisode: row.last_episode,
            totalEpisodes: row.total_episodes ?? undefined,
            updatedAt: row.updated_at,
        }));
    }

    setEpisodeProgress(
        anilistId: number,
        seasonNumber: number,
        lastEpisode: number,
        totalEpisodes?: number
    ): EpisodeProgress {
        const db = getDb();
        const updatedAt = new Date().toISOString();
        db.prepare(`
            INSERT INTO episode_progress (anilist_id, season_number, last_episode, total_episodes, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(anilist_id, season_number) DO UPDATE SET
                last_episode = excluded.last_episode,
                total_episodes = excluded.total_episodes,
                updated_at = excluded.updated_at
        `).run(anilistId, seasonNumber, lastEpisode, totalEpisodes ?? null, updatedAt);
        return { anilistId, seasonNumber, lastEpisode, totalEpisodes, updatedAt };
    }

    deleteEpisodeProgress(anilistId: number, seasonNumber: number): boolean {
        const db = getDb();
        const result = db
            .prepare('DELETE FROM episode_progress WHERE anilist_id = ? AND season_number = ?')
            .run(anilistId, seasonNumber);
        return result.changes > 0;
    }
}

export const userDataService = new UserDataService();
