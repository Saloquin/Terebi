const DEFAULT_TTL_MS = 20 * 60 * 1000;

interface CacheEntry<T> {
    value: T;
    expiresAt: number;
}

export class AniListCache {
    private store = new Map<string, CacheEntry<unknown>>();

    get<T>(key: string): T | undefined {
        const entry = this.store.get(key);
        if (!entry) return undefined;
        if (Date.now() > entry.expiresAt) {
            this.store.delete(key);
            return undefined;
        }
        return entry.value as T;
    }

    set<T>(key: string, value: T, ttlMs = DEFAULT_TTL_MS): void {
        this.store.set(key, { value, expiresAt: Date.now() + ttlMs });
    }

    delete(key: string): void {
        this.store.delete(key);
    }
}

export const anilistCache = new AniListCache();
