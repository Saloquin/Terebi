import { AnimePlanning, AnimeStorage, AnimeStats } from '../../types/anime.types';
import { getHiddenAnime, restoreHiddenAnime } from '../../utils/tabLogic/hidden.logic';
import { getNewAnime, newMarkAsSeen } from '../../utils/tabLogic/new.logic';
import { getOldAnime, removeOldAnime } from '../../utils/tabLogic/old.logic';
import { getPlanningAnime } from '../../utils/tabLogic/planning.logic';
import { readStorage, STORAGE_KEY, writeStorage } from '../../utils/tabLogic/storage.utils';

class AnimeStorageService {
    private getStorage(): AnimeStorage {
        return readStorage();
    }

    private initStorage(): AnimeStorage {
        return {
            current: [],
            new: [],
            old: [],
            hidden: [],
            towatch: [],
            viewed: [],
            lastUpdate: new Date().toISOString(),
        };
    }

    private saveStorage(storage: AnimeStorage): void {
        writeStorage(storage);
    }

    private normalizeTitle(title: string): string {
        return title.toLowerCase().replace(/[^a-z0-9]/g, '').trim();
    }

    private findByTitle(list: AnimePlanning[], title: string): AnimePlanning | undefined {
        const normalized = this.normalizeTitle(title);
        return list.find(a => this.normalizeTitle(a.title) === normalized);
    }

    private isInList(list: AnimePlanning[], anime: AnimePlanning): boolean {
        return !!this.findByTitle(list, anime.title);
    }

    /**
     * Synchronise les données de l'API avec le localStorage
     * - Les animes de l'API qui ne sont pas dans current -> ajoutés à new ET current
     * - Les animes dans current qui ne sont plus dans l'API -> déplacés vers old
     * - Les hidden restent filtrés de l'affichage
     */
    syncWithApi(apiAnimes: AnimePlanning[]): void {
        const storage = this.getStorage();
        
        console.log('🔄 Synchronisation avec API...');
        console.log(`   - Animes API: ${apiAnimes.length}`);
        console.log(`   - Current local: ${storage.current.length}`);
        console.log(`   - New local: ${storage.new.length}`);
        console.log(`   - Hidden: ${storage.hidden.length}`);

        // 1. Trouver les nouveaux animes (dans API mais pas dans current)
        const newFromApi = apiAnimes.filter(apiAnime => 
            !this.isInList(storage.current, apiAnime) && 
            !this.isInList(storage.new, apiAnime)
        );

        // 2. Trouver les animes qui ne sont plus dans l'API (current -> old)
        const toMoveToOld = storage.current.filter(currentAnime =>
            !apiAnimes.some(apiAnime => 
                this.normalizeTitle(apiAnime.title) === this.normalizeTitle(currentAnime.title)
            )
        );

        // 3. Mettre à jour les listes
        // Ajouter les nouveaux à 'new'
        newFromApi.forEach(anime => {
            if (!this.isInList(storage.new, anime)) {
                storage.new.push(anime);
            }
        });

        // Mettre à jour current avec les animes de l'API
        storage.current = apiAnimes;
        
        // Déplacer vers old (sans doublons)
        toMoveToOld.forEach(anime => {
            if (!this.isInList(storage.old, anime)) {
                storage.old.push(anime);
            }
        });

        storage.lastUpdate = new Date().toISOString();
        this.saveStorage(storage);

        console.log('✅ Sync terminée:');
        console.log(`   - Nouveaux détectés: ${newFromApi.length}`);
        console.log(`   - Déplacés vers old: ${toMoveToOld.length}`);
        console.log(`   - Total current: ${storage.current.length}`);
        console.log(`   - Total new: ${storage.new.length}`);
    }

    // Getters - Filtrent les hidden
    getCurrent(): AnimePlanning[] {
        return getPlanningAnime();
    }

    getNew(): AnimePlanning[] {
        return getNewAnime();
    }

    getOld(): AnimePlanning[] {
        return getOldAnime();
    }

    getHidden(): AnimePlanning[] {
        return getHiddenAnime();
    }

    // Actions
    hideAnime(animeId: string): boolean {
        const storage = this.getStorage();
        
        if (!storage.hidden.includes(animeId)) {
            storage.hidden.push(animeId);
            this.saveStorage(storage);
            console.log(`🙈 Anime masqué: ${animeId}`);
            return true;
        }
        return false;
    }

    restoreAnime(animeId: string): boolean {
        if (restoreHiddenAnime(animeId)) {
            console.log(`👁️ Anime restauré: ${animeId}`);
            return true;
        }
        return false;
    }

    markAsSeen(animeId: string): boolean {
        if (newMarkAsSeen(animeId)) {
            console.log(`✅ Anime marqué comme vu: ${animeId}`);
            return true;
        }
        return false;
    }

    removeFromOld(animeId: string): boolean {
        if (removeOldAnime(animeId)) {
            console.log(`🗑️ Anime supprimé des anciens: ${animeId} (+ hidden nettoyé)`);
            return true;
        }
        return false;
    }

    // Utilitaires
    clearNew(): void {
        const storage = this.getStorage();
        storage.new = [];
        this.saveStorage(storage);
        console.log('🗑️ Liste des nouveaux vidée');
    }

    clearOld(): void {
        const storage = this.getStorage();
        const oldIds = new Set(storage.old.map(a => a.id));
        storage.hidden = storage.hidden.filter(id => !oldIds.has(id));
        storage.old = [];
        this.saveStorage(storage);
        console.log('🗑️ Liste des anciens vidée (+ hidden nettoyés)');
    }

    clearAll(): void {
        this.saveStorage(this.initStorage());
        console.log('🗑️ Tout le storage vidé');
    }

    getStats(): AnimeStats {
        const storage = this.getStorage();
        const byDay: Record<string, number> = {};
        
        const visibleCurrent = storage.current.filter(a => !storage.hidden.includes(a.id));
        
        visibleCurrent.forEach(anime => {
            byDay[anime.dayOfWeek] = (byDay[anime.dayOfWeek] || 0) + 1;
        });

        return {
            totalCurrent: visibleCurrent.length,
            totalNew: storage.new.filter(a => !storage.hidden.includes(a.id)).length,
            totalOld: storage.old.filter(a => !storage.hidden.includes(a.id)).length,
            totalHidden: storage.hidden.length,
            totalToWatch: storage.towatch.length,
            byDay,
            lastUpdate: storage.lastUpdate,
        };
    }

    /**
     * Get all viewed animes
     */
    getViewed() {
        const storage = this.getStorage();
        if (!storage.viewed) {
            storage.viewed = [];
            this.saveStorage(storage);
        }
        return storage.viewed;
    }

    /**
     * Update viewed seasons for an anime (by title match)
     */
    updateViewedSeasons(anime: AnimePlanning, viewedSeasons: string[]): boolean {
        const storage = this.getStorage();

        if (!storage.viewed) {
            storage.viewed = [];
        }

        const existingIndex = storage.viewed.findIndex(a =>
            this.normalizeTitle(a.title) === this.normalizeTitle(anime.title)
        );

        const viewedAnime = {
            ...anime,
            viewedSeasons,
            viewedAt: new Date().toISOString(),
        };

        if (existingIndex >= 0) {
            storage.viewed[existingIndex] = { ...storage.viewed[existingIndex], ...viewedAnime };
        } else {
            storage.viewed.push(viewedAnime);
        }

        this.saveStorage(storage);
        return true;
    }

    /**
     * Find viewed anime by title or id
     */
    findViewedAnime(anime: AnimePlanning) {
        const storage = this.getStorage();
        return storage.viewed?.find(a =>
            a.id === anime.id ||
            this.normalizeTitle(a.title) === this.normalizeTitle(anime.title)
        );
    }

    /**
     * Remove anime from towatch and optionally mark fully viewed
     */
    completeViewedAnime(anime: AnimePlanning, viewedSeasons: string[]): boolean {
        const storage = this.getStorage();

        storage.towatch = (storage.towatch || []).filter(a =>
            this.normalizeTitle(a.title) !== this.normalizeTitle(anime.title)
        );

        this.markAsViewed({ ...anime, viewedSeasons }, viewedSeasons);
        return true;
    }

    /**
     * Mark an anime as viewed (completely or partially with selected seasons)
     */
    markAsViewed(anime: AnimePlanning, viewedSeasons?: string[]): boolean {
        const storage = this.getStorage();
        
        if (!storage.viewed) {
            storage.viewed = [];
        }

        const existingIndex = storage.viewed.findIndex(a => 
            this.normalizeTitle(a.title) === this.normalizeTitle(anime.title)
        );

        const viewedAnime = {
            ...anime,
            viewedSeasons: viewedSeasons || [],
            viewedAt: new Date().toISOString(),
        };

        if (existingIndex >= 0) {
            storage.viewed[existingIndex] = viewedAnime;
        } else {
            storage.viewed.push(viewedAnime);
        }

        // Also remove from towatch if present
        storage.towatch = storage.towatch.filter(a => 
            this.normalizeTitle(a.title) !== this.normalizeTitle(anime.title)
        );

        this.saveStorage(storage);
        console.log(`✅ "${anime.title}" marqué comme vu`);
        return true;
    }

    /**
     * Remove anime from viewed list
     */
    removeFromViewed(animeId: string): boolean {
        const storage = this.getStorage();
        
        if (!storage.viewed) {
            storage.viewed = [];
        }

        const initialLength = storage.viewed.length;
        storage.viewed = storage.viewed.filter(a =>
            a.id !== animeId &&
            this.normalizeTitle(a.id) !== this.normalizeTitle(animeId)
        );

        // Also try matching by title if animeId looks like a title
        if (storage.viewed.length === initialLength) {
            storage.viewed = storage.viewed.filter(a =>
                this.normalizeTitle(a.title) !== this.normalizeTitle(animeId)
            );
        }

        if (storage.viewed.length < initialLength) {
            this.saveStorage(storage);
            console.log(`🗑️ Anime retiré de "Déjà vu"`);
            return true;
        }

        return false;
    }
}

export const animeStorage = new AnimeStorageService();
