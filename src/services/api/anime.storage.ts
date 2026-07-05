import { AnimePlanning, AnimeStorage, AnimeStats, AnimeViewed } from '../../types/anime.types';
import { getHiddenAnime, restoreHiddenAnime } from '../../utils/tabLogic/hidden.logic';
import { getNewAnime, newMarkAsSeen } from '../../utils/tabLogic/new.logic';
import { getOldAnime, removeOldAnime } from '../../utils/tabLogic/old.logic';
import { getPlanningAnime } from '../../utils/tabLogic/planning.logic';
import { readStorage, STORAGE_KEY, writeStorage } from '../../utils/tabLogic/storage.utils';

class AnimeStorageService {
    private getStorage(): AnimeStorage {
        return readStorage();
    }

    // Méthode publique pour récupérer le stockage
    public readStorage(): AnimeStorage {
        return this.getStorage();
    }

    private initStorage(): AnimeStorage {
        return {
            current: [],
            new: [],
            old: [],
            hidden: [],
            towatch: [],
            inprogress: [],
            completed: [],
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
     * Get all to-watch animes
     */
    getToWatch() {
        const storage = this.getStorage();
        if (!storage.towatch) {
            storage.towatch = [];
            this.saveStorage(storage);
        }
        return storage.towatch;
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
     * Get animes in progress (partially watched)
     */
    getInProgress() {
        const storage = this.getStorage();
        if (!storage.inprogress) {
            storage.inprogress = [];
            this.saveStorage(storage);
        }
        return storage.inprogress;
    }

    /**
     * Get completed animes (all regular seasons watched)
     */
    getCompleted() {
        const storage = this.getStorage();
        if (!storage.completed) {
            storage.completed = [];
            this.saveStorage(storage);
        }
        return storage.completed;
    }

    /**
     * Get to-watch not started animes
     */
    getToWatchNotStarted() {
        const storage = this.getStorage();
        if (!storage.towatch) return [];
        
        return storage.towatch.filter(anime => 
            !anime.viewedSeasons || anime.viewedSeasons.length === 0
        );
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
        storage.viewed = storage.viewed.filter(a => a.id !== animeId);

        if (storage.viewed.length < initialLength) {
            this.saveStorage(storage);
            console.log(`🗑️ Anime retiré de "Déjà vu"`);
            return true;
        }

        return false;
    }

    /**
     * Reclasse un anime spécifique en fonction de sa progression
     * Logique:
     * - 0 saisons vues → towatch (À regarder)
     * - 1+ saisons vues mais pas toutes régulières → inprogress (En cours)
     * - Toutes régulières vues mais pas tout → completed (Complétés)
     * - Tout vu (régulières + tous les supplémentaires) → viewed (Déjà vu)
     */
    reclassifyAnime(animeId: string): void {
        const storage = this.getStorage();
        
        // Initialiser les listes si elles n'existent pas
        if (!storage.inprogress) storage.inprogress = [];
        if (!storage.completed) storage.completed = [];
        if (!storage.towatch) storage.towatch = [];
        if (!storage.viewed) storage.viewed = [];
        
        // Chercher l'anime partout
        let anime: any = null;
        let foundInList = '';
        
        // Chercher dans towatch
        let index = storage.towatch.findIndex(a => a.id === animeId);
        if (index >= 0) {
            anime = storage.towatch[index];
            foundInList = 'towatch';
        }
        
        // Chercher dans inprogress
        if (!anime) {
            index = storage.inprogress.findIndex(a => a.id === animeId);
            if (index >= 0) {
                anime = storage.inprogress[index];
                foundInList = 'inprogress';
            }
        }
        
        // Chercher dans completed
        if (!anime) {
            index = storage.completed.findIndex(a => a.id === animeId);
            if (index >= 0) {
                anime = storage.completed[index];
                foundInList = 'completed';
            }
        }
        
        // Chercher dans viewed
        if (!anime) {
            index = storage.viewed.findIndex(a => a.id === animeId);
            if (index >= 0) {
                anime = storage.viewed[index];
                foundInList = 'viewed';
            }
        }
        
        if (!anime) {
            console.log(`⚠️ Anime introuvable pour reclassification: ${animeId}`);
            return;
        }
        
        const viewedSeasons = anime.viewedSeasons || [];
        
        // Déterminer la nouvelle catégorie basée sur les saisons vues
        let newList: string;
        
        // CAS 1: Aucune saison vue → À regarder
        if (viewedSeasons.length === 0) {
            newList = 'towatch';
        }
        // CAS 2: Des saisons vues mais pas de données complètes → En cours
        else if (!anime.seasons || anime.seasons.length === 0) {
            newList = 'inprogress';
        }
        // CAS 3 & 4: On a les données complètes
        else {
            const regularSeasons = anime.seasons.filter((s: any) => s.type === 'regular');
            const allSeasons = anime.seasons;
            
            // Compter les saisons régulières vues
            const viewedRegularSeasons = viewedSeasons.filter((viewed: string) =>
                regularSeasons.some((s: any) => s.name === viewed)
            );
            
            // Compter TOUTES les saisons vues
            const viewedAllSeasons = viewedSeasons.length;
            
            // Si aucune saison régulière vues → À regarder
            if (viewedRegularSeasons.length === 0) {
                newList = 'towatch';
            }
            // Si 1+ régulière vues mais pas toutes → En cours
            else if (viewedRegularSeasons.length > 0 && viewedRegularSeasons.length < regularSeasons.length) {
                newList = 'inprogress';
            }
            // Si toutes les régulières vues mais pas tout → Complétés
            else if (viewedRegularSeasons.length === regularSeasons.length && viewedAllSeasons < allSeasons.length) {
                newList = 'completed';
            }
            // Si tout est vu → Déjà vu
            else if (viewedAllSeasons === allSeasons.length) {
                newList = 'viewed';
            }
            // Fallback
            else {
                newList = 'inprogress';
            }
        }
        
        // Si pas de changement, ne rien faire
        if (newList === foundInList) {
            console.log(`ℹ️ Anime reste dans ${foundInList}: "${anime.title}"`);
            return;
        }
        
        // Retirer de l'ancienne liste
        if (foundInList === 'towatch') {
            storage.towatch = storage.towatch.filter(a => a.id !== animeId);
        } else if (foundInList === 'inprogress') {
            storage.inprogress = storage.inprogress.filter(a => a.id !== animeId);
        } else if (foundInList === 'completed') {
            storage.completed = storage.completed.filter(a => a.id !== animeId);
        } else if (foundInList === 'viewed') {
            storage.viewed = storage.viewed.filter(a => a.id !== animeId);
        }
        
        // Ajouter à la nouvelle liste
        if (newList === 'towatch') {
            storage.towatch.push(anime);
            console.log(`📦 Reclassification: "${anime.title}" → À regarder`);
        } else if (newList === 'inprogress') {
            storage.inprogress.push(anime);
            console.log(`📦 Reclassification: "${anime.title}" → En cours (${viewedSeasons.length} saison(s))`);
        } else if (newList === 'completed') {
            storage.completed.push(anime);
            console.log(`✅ Reclassification: "${anime.title}" → Complétés (régulières finies)`);
        } else if (newList === 'viewed') {
            storage.viewed.push(anime);
            console.log(`🎉 Reclassification: "${anime.title}" → Déjà vu (tout vu)`);
        }
        
        this.saveStorage(storage);
    }

    /**
     * Reclasse TOUS les animes de toutes les listes en fonction de leur progression
     */
    reclassifyAllAnimes(): void {
        const storage = this.getStorage();
        
        // Initialiser les listes si elles n'existent pas
        if (!storage.inprogress) storage.inprogress = [];
        if (!storage.completed) storage.completed = [];
        if (!storage.viewed) storage.viewed = [];
        
        // Lister tous les animes à reclassifier
        const allAnimes = [
            ...(storage.towatch || []),
            ...(storage.inprogress || []),
            ...(storage.completed || []),
            ...(storage.viewed || []),
        ];
        
        // Reclassifier chaque anime
        allAnimes.forEach(anime => {
            this.reclassifyAnime(anime.id);
        });
    }

    /**
     * Reclasse les animes de "Déjà vu" vers les bonnes catégories en fonction de leur progression
     * - Aucune saison vue → towatch (À regarder)
     * - 1+ saison vue mais pas toutes → inprogress (En cours)
     * - Toutes les saisons régulières vues → completed (Complétés)
     * - Tout est vu (y compris spéciaux) → viewed (Déjà vu)
     */
    reclassifyViewedAnimes(): void {
        const storage = this.getStorage();
        const toMoveToTowatch: AnimePlanning[] = [];
        const toMoveToInprogress: AnimeViewed[] = [];
        const toMoveToCompleted: AnimeViewed[] = [];
        let hasChanges = false;

        // Initialiser les listes si elles n'existent pas
        if (!storage.inprogress) storage.inprogress = [];
        if (!storage.completed) storage.completed = [];
        if (!storage.viewed) storage.viewed = [];

        // Parcourir les animes "DÃ©jÃ  vu"
        storage.viewed = storage.viewed.filter(anime => {
            // CAS 1: Aucune saison vue → À regarder
            if (!anime.viewedSeasons || anime.viewedSeasons.length === 0) {
                const animeToAdd: AnimePlanning = {
                    ...anime,
                    viewedSeasons: [],
                };
                toMoveToTowatch.push(animeToAdd);
                hasChanges = true;
                console.log(`📦 Reclassification: "${anime.title}" → À regarder (pas commencé)`);
                return false; // Retirer de viewed
            }

            // CAS 2: Des saisons ont été vues
            // Si on a pas de données de saisons, on ne peut pas comparer → En cours
            if (!anime.seasons || anime.seasons.length === 0) {
                // On a viewedSeasons mais pas de données complètes
                // → C'est un anime en cours (1+ saison vue)
                const animeToAdd: AnimeViewed = {
                    ...anime,
                    viewedSeasons: anime.viewedSeasons,
                };
                toMoveToInprogress.push(animeToAdd);
                hasChanges = true;
                console.log(`📦 Reclassification: "${anime.title}" → En cours (${anime.viewedSeasons.length} saison(s) vue(s))`);
                return false; // Retirer de viewed
            }

            // CAS 3: On a les données complètes
            const regularSeasons = anime.seasons.filter(s => s.type === 'regular');
            const allSeasons = anime.seasons;
            const viewedRegularSeasons = anime.viewedSeasons.filter(viewed =>
                regularSeasons.some(s => s.name === viewed)
            );
            const viewedAllSeasons = anime.viewedSeasons.length;

            // Si 1+ saison vue mais pas toutes les régulières → En cours
            if (viewedRegularSeasons.length > 0 && viewedRegularSeasons.length < regularSeasons.length) {
                const animeToAdd: AnimeViewed = {
                    ...anime,
                    viewedSeasons: anime.viewedSeasons,
                };
                toMoveToInprogress.push(animeToAdd);
                hasChanges = true;
                console.log(`📦 Reclassification: "${anime.title}" → En cours (${viewedRegularSeasons.length}/${regularSeasons.length} régulières)`);
                return false; // Retirer de viewed
            }

            // Si toutes les saisons régulières vues mais pas tout → Complétés
            if (viewedRegularSeasons.length === regularSeasons.length && viewedAllSeasons < allSeasons.length) {
                const animeToAdd: AnimeViewed = {
                    ...anime,
                    viewedSeasons: anime.viewedSeasons,
                };
                toMoveToCompleted.push(animeToAdd);
                hasChanges = true;
                console.log(`✅ Reclassification: "${anime.title}" → Complétés (régulières finies)`);
                return false; // Retirer de viewed
            }

            // CAS 4: Tout est vu → rester dans viewed (Déjà vu)
            console.log(`✅ Garde dans Déjà vu: "${anime.title}" (entièrement vu)`);
            return true;
        });

        // Ajouter aux bonnes listes
        toMoveToTowatch.forEach(anime => {
            const exists = storage.towatch?.some(a => 
                this.normalizeTitle(a.title) === this.normalizeTitle(anime.title)
            );
            if (!exists) {
                if (!storage.towatch) storage.towatch = [];
                storage.towatch.push(anime);
                console.log(`✔️ Ajouté à towatch: "${anime.title}"`);
            }
        });

        toMoveToInprogress.forEach(anime => {
            const exists = storage.inprogress?.some(a => 
                this.normalizeTitle(a.title) === this.normalizeTitle(anime.title)
            );
            if (!exists) {
                if (!storage.inprogress) storage.inprogress = [];
                storage.inprogress.push(anime);
                console.log(`✔️ Ajouté à inprogress: "${anime.title}"`);
            }
            // Enlever de towatch
            storage.towatch = storage.towatch.filter(a => 
                this.normalizeTitle(a.title) !== this.normalizeTitle(anime.title)
            );
        });

        toMoveToCompleted.forEach(anime => {
            const exists = storage.completed?.some(a => 
                this.normalizeTitle(a.title) === this.normalizeTitle(anime.title)
            );
            if (!exists) {
                if (!storage.completed) storage.completed = [];
                storage.completed.push(anime);
                console.log(`✔️ Ajouté à completed: "${anime.title}"`);
            }
            // Enlever de towatch
            storage.towatch = storage.towatch.filter(a => 
                this.normalizeTitle(a.title) !== this.normalizeTitle(anime.title)
            );
        });

        if (hasChanges) {
            this.saveStorage(storage);
            console.log(`🔄 Reclassification terminée: ${toMoveToTowatch.length + toMoveToInprogress.length + toMoveToCompleted.length} anime(s) déplacé(s)`);
        } else {
            console.log(`ℹ️ Aucun anime à reclassifier`);
        }
    }
}

export const animeStorage = new AnimeStorageService();
