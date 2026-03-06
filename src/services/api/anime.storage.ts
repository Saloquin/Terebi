import { AnimePlanning, AnimeStorage, AnimeStats } from '../../types/anime.types';

const STORAGE_KEY = 'anime_dashboard_v2';

class AnimeStorageService {
    private getStorage(): AnimeStorage {
        try {
            const stored = localStorage.getItem(STORAGE_KEY);
            if (stored) {
                return JSON.parse(stored);
            }
        } catch (error) {
            console.error('Erreur lecture storage:', error);
        }
        return this.initStorage();
    }

    private initStorage(): AnimeStorage {
        return {
            current: [],
            new: [],
            old: [],
            hidden: [],
            lastUpdate: new Date().toISOString(),
        };
    }

    private saveStorage(storage: AnimeStorage): void {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(storage));
        } catch (error) {
            console.error('Erreur sauvegarde storage:', error);
        }
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
        const storage = this.getStorage();
        return storage.current.filter(a => !storage.hidden.includes(a.id));
    }

    getNew(): AnimePlanning[] {
        const storage = this.getStorage();
        return storage.new.filter(a => !storage.hidden.includes(a.id));
    }

    getOld(): AnimePlanning[] {
        const storage = this.getStorage();
        return storage.old.filter(a => !storage.hidden.includes(a.id));
    }

    getHidden(): AnimePlanning[] {
        const storage = this.getStorage();
        const allAnimes = [...storage.current, ...storage.new, ...storage.old];
        return allAnimes.filter(a => storage.hidden.includes(a.id));
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
        const storage = this.getStorage();
        const index = storage.hidden.indexOf(animeId);
        
        if (index > -1) {
            storage.hidden.splice(index, 1);
            this.saveStorage(storage);
            console.log(`👁️ Anime restauré: ${animeId}`);
            return true;
        }
        return false;
    }

    markAsSeen(animeId: string): boolean {
        const storage = this.getStorage();
        const index = storage.new.findIndex(a => a.id === animeId);
        
        if (index > -1) {
            storage.new.splice(index, 1);
            this.saveStorage(storage);
            console.log(`✅ Anime marqué comme vu: ${animeId}`);
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
        storage.old = [];
        this.saveStorage(storage);
        console.log('🗑️ Liste des anciens vidée');
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
            byDay,
            lastUpdate: storage.lastUpdate,
        };
    }
}

export const animeStorage = new AnimeStorageService();
