/**
 * Service de stockage des animes avec cache JSON
 */

import { AnimePlanning } from './anime-planning';

export interface AnimeStorage {
    currentAnime: AnimePlanning[];
    oldAnime: AnimePlanning[];
    doNotDisplay: AnimePlanning[];
    newAnime: AnimePlanning[];
    lastUpdate?: string;
}

export interface AnimeStorageResult {
    success: boolean;
    data: AnimePlanning[] | null;
    error?: string;
}

class AnimeStorageService {
    private storageKey = 'anime_storage_cache';

    /**
     * Initialiser le stockage avec la structure par défaut
     */    private initStorage(): AnimeStorage {
        return {
            currentAnime: [],
            oldAnime: [],
            doNotDisplay: [],
            newAnime: [],
            lastUpdate: new Date().toISOString()
        };
    }

    /**
     * Récupérer le stockage depuis localStorage
     */
    private getStorage(): AnimeStorage {
        try {
            const stored = localStorage.getItem(this.storageKey);
            if (stored) {
                return JSON.parse(stored);
            }
        } catch (error) {
            console.error('Erreur lors de la lecture du stockage anime:', error);
        }
        
        return this.initStorage();
    }    /**
     * Sauvegarder le stockage dans localStorage
     */
    private setStorage(storage: AnimeStorage): void {
        try {
            localStorage.setItem(this.storageKey, JSON.stringify(storage));
        } catch (error) {
            console.error('Erreur lors de la sauvegarde du stockage anime:', error);
        }
    }    /**
     * Filtrer une liste d'animes pour exclure ceux dans doNotDisplay
     */
    private filterOutDoNotDisplay(animes: AnimePlanning[]): AnimePlanning[] {
        const storage = this.getStorage();
        const doNotDisplayIds = new Set(storage.doNotDisplay.map(anime => anime.id));
        const filtered = animes.filter(anime => !doNotDisplayIds.has(anime.id));
        
        const hiddenCount = animes.length - filtered.length;
        if (hiddenCount > 0) {
            console.log(`🚫 ${hiddenCount} anime(s) masqué(s) filtré(s)`);
        }
        
        return filtered;
    }
    
    /**
     * Normaliser le nom d'un anime pour regrouper VF/VOSTFR
     */
    private normalizeAnimeName(title: string): string {
        // Supprimer les mentions de langue et normaliser
        return title
            .replace(/\s*\(VF\)$/i, '')
            .replace(/\s*\(VOSTFR\)$/i, '')
            .replace(/\s*\(VJSTFR\)$/i, '')
            .replace(/\s*VF$/i, '')
            .replace(/\s*VOSTFR$/i, '')
            .replace(/\s*VJSTFR$/i, '')
            .trim()
            .toLowerCase();
    }    /**
     * Déduplication des animes par nom normalisé
     * Garde la version VOSTFR en priorité, sinon VF
     */
    private deduplicateAnimes(animes: AnimePlanning[]): AnimePlanning[] {
        const animeMap = new Map<string, AnimePlanning>();
        
        animes.forEach(anime => {
            const normalizedName = this.normalizeAnimeName(anime.title);
            const existing = animeMap.get(normalizedName);
            
            if (!existing) {
                animeMap.set(normalizedName, anime);
                console.log(`➕ Anime ajouté à la déduplication: ${anime.title}`);
            } else {
                // Priorité : VOSTFR > VF
                const currentIsVostfr = anime.title.includes('VOSTFR');
                const existingIsVostfr = existing.title.includes('VOSTFR');
                
                if (currentIsVostfr && !existingIsVostfr) {
                    animeMap.set(normalizedName, anime);
                    console.log(`🔄 Anime remplacé: "${existing.title}" → "${anime.title}" (VOSTFR priorité)`);
                } else {
                    console.log(`❌ Doublon ignoré: "${anime.title}" (déjà: "${existing.title}")`);
                }
            }
        });
        
        const result = Array.from(animeMap.values());
        console.log(`📊 Déduplication: ${animes.length} → ${result.length} animes (${animes.length - result.length} doublons supprimés)`);
        
        return result;
    }

    /**
     * Créer un Set des noms normalisés depuis une liste d'animes
     */
    private createNormalizedNameSet(animes: AnimePlanning[]): Set<string> {
        return new Set(animes.map(anime => this.normalizeAnimeName(anime.title)));
    }

    /**
     * Trouver les animes qui ne sont plus dans la nouvelle liste
     */
    private findAnimesToMoveToOld(currentAnimes: AnimePlanning[], newAnimes: AnimePlanning[]): AnimePlanning[] {
        const newNormalizedNames = this.createNormalizedNameSet(newAnimes);
        return currentAnimes.filter(anime => {
            const normalizedName = this.normalizeAnimeName(anime.title);
            return !newNormalizedNames.has(normalizedName);
        });
    }

    /**
     * Trouver les nouveaux animes qui n'étaient pas dans le storage
     */
    private findNewAnimes(newAnimes: AnimePlanning[], existingAnimes: AnimePlanning[]): AnimePlanning[] {
        const existingNormalizedNames = this.createNormalizedNameSet(existingAnimes);
        return newAnimes.filter(anime => {
            const normalizedName = this.normalizeAnimeName(anime.title);
            return !existingNormalizedNames.has(normalizedName);
        });
    }

    /**
     * Sauvegarder une nouvelle liste d'animes - VERSION SIMPLIFIÉE
     * 1. Compare nouvelle liste avec celle en storage
     * 2. Met les animes qui ne sont plus dans la nouvelle liste vers "old"
     * 3. Met les animes qui sont nouveaux vers "new" et "current"
     */
    saveAnimes(newAnimes: AnimePlanning[]): void {
        const storage = this.getStorage();
          // 1. Déduplication de la liste entrante (VOSTFR > VF) - TEMPORAIREMENT DÉSACTIVÉE
        const deduplicatedNewAnimes = newAnimes; // this.deduplicateAnimes(newAnimes);
        
        // 2. Trouver les animes actuels qui ne sont plus dans la nouvelle liste
        const animesToMoveToOld = this.findAnimesToMoveToOld(storage.currentAnime, deduplicatedNewAnimes);
        
        // 3. Trouver tous les animes existants (current + old + hidden + new)
        const allExistingAnimes = [
            ...storage.currentAnime,
            ...storage.oldAnime,
            ...storage.doNotDisplay,
            ...storage.newAnime
        ];
        
        // 4. Trouver les vrais nouveaux animes
        const trulyNewAnimes = this.findNewAnimes(deduplicatedNewAnimes, allExistingAnimes);
        
        // 5. Mettre à jour le storage
        storage.currentAnime = deduplicatedNewAnimes;
        storage.oldAnime = [...storage.oldAnime, ...animesToMoveToOld];
        storage.newAnime = [...storage.newAnime, ...trulyNewAnimes];
        storage.lastUpdate = new Date().toISOString();
        
        this.setStorage(storage);
        
        console.log('📊 Mise à jour du cache:', {
            nouveaux_animes: deduplicatedNewAnimes.length,
            anciens_déplacés: animesToMoveToOld.length,
            nouveaux_détectés: trulyNewAnimes.length,
            total_current: storage.currentAnime.length,
            total_old: storage.oldAnime.length,
            total_new: storage.newAnime.length
        });
    }
    /**
     * Récupérer tous les animes actuels (filtrés pour exclure doNotDisplay)
     */
    getCurrentAnimes(): AnimeStorageResult {
        try {
            const storage = this.getStorage();
            const filteredAnimes = this.filterOutDoNotDisplay(storage.currentAnime);
            return {
                success: true,
                data: filteredAnimes
            };
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }    /**
     * Récupérer les animes d'un jour spécifique (filtrés pour exclure doNotDisplay)
     */
    getCurrentAnimesByDay(day: string): AnimeStorageResult {
        try {
            const storage = this.getStorage();
            const dayFilteredAnimes = storage.currentAnime.filter(
                anime => anime.dayOfWeek.toLowerCase() === day.toLowerCase()
            );
            const filteredAnimes = this.filterOutDoNotDisplay(dayFilteredAnimes);
            
            return {
                success: true,
                data: filteredAnimes
            };
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }

    /**
     * Récupérer les anciens animes
     */
    getOldAnimes(): AnimeStorageResult {
        try {
            const storage = this.getStorage();
            return {
                success: true,
                data: storage.oldAnime
            };
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }    /**
     * Récupérer la liste des animes à ne pas afficher
     */
    getDoNotDisplayAnimes(): AnimeStorageResult {
        try {
            const storage = this.getStorage();
            return {
                success: true,
                data: storage.doNotDisplay
            };
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }    /**
     * Récupérer tous les nouveaux animes (filtrés pour exclure doNotDisplay)
     */
    getNewAnimes(): AnimeStorageResult {
        try {
            const storage = this.getStorage();
            const filteredAnimes = this.filterOutDoNotDisplay(storage.newAnime);
            return {
                success: true,
                data: filteredAnimes
            };
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }    /**
     * Récupérer les nouveaux animes d'un jour spécifique (filtrés pour exclure doNotDisplay)
     */
    getNewAnimesByDay(day: string): AnimeStorageResult {
        try {
            const storage = this.getStorage();
            const dayFilteredAnimes = storage.newAnime.filter(
                anime => anime.dayOfWeek.toLowerCase() === day.toLowerCase()
            );
            const filteredAnimes = this.filterOutDoNotDisplay(dayFilteredAnimes);
            
            return {
                success: true,
                data: filteredAnimes
            };
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }

    /**
     * Ajouter un anime à la liste "ne pas afficher"
     * Le supprime des autres listes s'il y est présent
     */
    addToDoNotDisplay(animeId: string): { success: boolean; message: string } {
        try {
            const storage = this.getStorage();
            
            // Chercher l'anime dans toutes les listes
            let animeToHide: AnimePlanning | null = null;
            
            // Chercher dans currentAnime
            const currentIndex = storage.currentAnime.findIndex(anime => anime.id === animeId);
            if (currentIndex !== -1) {
                animeToHide = storage.currentAnime.splice(currentIndex, 1)[0];
            }
            
            // Chercher dans newAnime si pas trouvé
            if (!animeToHide) {
                const newIndex = storage.newAnime.findIndex(anime => anime.id === animeId);
                if (newIndex !== -1) {
                    animeToHide = storage.newAnime.splice(newIndex, 1)[0];
                }
            }
            
            // Chercher dans oldAnime si pas encore trouvé
            if (!animeToHide) {
                const oldIndex = storage.oldAnime.findIndex(anime => anime.id === animeId);
                if (oldIndex !== -1) {
                    animeToHide = storage.oldAnime.splice(oldIndex, 1)[0];
                }
            }
            
            if (!animeToHide) {
                return {
                    success: false,
                    message: 'Anime non trouvé dans les listes'
                };
            }
            
            // Vérifier s'il n'est pas déjà dans doNotDisplay
            const alreadyHidden = storage.doNotDisplay.some(anime => anime.id === animeId);
            if (alreadyHidden) {
                return {
                    success: false,
                    message: 'Anime déjà dans la liste "ne pas afficher"'
                };
            }
            
            // Ajouter à doNotDisplay
            storage.doNotDisplay.push(animeToHide);
            storage.lastUpdate = new Date().toISOString();
            
            this.setStorage(storage);
            
            return {
                success: true,
                message: `Anime "${animeToHide.title}" ajouté à la liste "ne pas afficher"`
            };
        } catch (error) {
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Erreur lors de l\'ajout'
            };
        }
    }

    /**
     * Retirer un anime de la liste "ne pas afficher" et le remettre dans currentAnime
     */
    removeFromDoNotDisplay(animeId: string): { success: boolean; message: string } {
        try {
            const storage = this.getStorage();
            
            const index = storage.doNotDisplay.findIndex(anime => anime.id === animeId);
            if (index === -1) {
                return {
                    success: false,
                    message: 'Anime non trouvé dans la liste "ne pas afficher"'
                };
            }
            
            const animeToRestore = storage.doNotDisplay.splice(index, 1)[0];
            
            // Le remettre dans currentAnime s'il n'y est pas déjà
            const alreadyInCurrent = storage.currentAnime.some(anime => anime.id === animeId);
            if (!alreadyInCurrent) {
                storage.currentAnime.push(animeToRestore);
            }
            
            storage.lastUpdate = new Date().toISOString();
            this.setStorage(storage);
            
            return {
                success: true,
                message: `Anime "${animeToRestore.title}" retiré de la liste "ne pas afficher"`
            };
        } catch (error) {
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Erreur lors de la suppression'
            };
        }
    }

    /**
     * Marquer un nouvel anime comme "vu" (le déplace de newAnime vers currentAnime)
     */
    markNewAnimeAsSeen(animeId: string): { success: boolean; message: string } {
        try {
            const storage = this.getStorage();
            
            const index = storage.newAnime.findIndex(anime => anime.id === animeId);
            if (index === -1) {
                return {
                    success: false,
                    message: 'Anime non trouvé dans la liste des nouveaux animes'
                };
            }
            
            const animeToMove = storage.newAnime.splice(index, 1)[0];
            
            // Vérifier s'il n'est pas déjà dans currentAnime
            const alreadyInCurrent = storage.currentAnime.some(anime => anime.id === animeId);
            if (!alreadyInCurrent) {
                storage.currentAnime.push(animeToMove);
            }
            
            storage.lastUpdate = new Date().toISOString();
            this.setStorage(storage);
            
            return {
                success: true,
                message: `Nouvel anime "${animeToMove.title}" marqué comme vu`
            };
        } catch (error) {
            return {
                success: false,
                message: error instanceof Error ? error.message : 'Erreur lors du marquage'
            };
        }
    }

    /**
     * Vider la liste des nouveaux animes
     */
    clearNewAnimes(): void {
        const storage = this.getStorage();
        storage.newAnime = [];
        storage.lastUpdate = new Date().toISOString();
        this.setStorage(storage);
    }    // Fonctions get spécifiques pour chaque jour (depuis currentAnime)
    getCurrentLundiAnimes(): AnimeStorageResult {
        return this.getCurrentAnimesByDay('Lundi');
    }

    getCurrentMardiAnimes(): AnimeStorageResult {
        return this.getCurrentAnimesByDay('Mardi');
    }

    getCurrentMercrediAnimes(): AnimeStorageResult {
        return this.getCurrentAnimesByDay('Mercredi');
    }

    getCurrentJeudiAnimes(): AnimeStorageResult {
        return this.getCurrentAnimesByDay('Jeudi');
    }

    getCurrentVendrediAnimes(): AnimeStorageResult {
        return this.getCurrentAnimesByDay('Vendredi');
    }

    getCurrentSamediAnimes(): AnimeStorageResult {
        return this.getCurrentAnimesByDay('Samedi');
    }

    getCurrentDimancheAnimes(): AnimeStorageResult {
        return this.getCurrentAnimesByDay('Dimanche');
    }

    // Fonctions get spécifiques pour chaque jour (depuis newAnime)
    getNewLundiAnimes(): AnimeStorageResult {
        return this.getNewAnimesByDay('Lundi');
    }

    getNewMardiAnimes(): AnimeStorageResult {
        return this.getNewAnimesByDay('Mardi');
    }

    getNewMercrediAnimes(): AnimeStorageResult {
        return this.getNewAnimesByDay('Mercredi');
    }

    getNewJeudiAnimes(): AnimeStorageResult {
        return this.getNewAnimesByDay('Jeudi');
    }

    getNewVendrediAnimes(): AnimeStorageResult {
        return this.getNewAnimesByDay('Vendredi');
    }

    getNewSamediAnimes(): AnimeStorageResult {
        return this.getNewAnimesByDay('Samedi');
    }

    getNewDimancheAnimes(): AnimeStorageResult {
        return this.getNewAnimesByDay('Dimanche');
    }

    /**
     * Récupérer les animes d'aujourd'hui depuis le cache
     */
    getCurrentTodayAnimes(): AnimeStorageResult {
        const today = new Date();
        const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
        const todayName = dayNames[today.getDay()];
        
        return this.getCurrentAnimesByDay(todayName);
    }    /**
     * Récupérer des statistiques depuis le cache (filtrées pour exclure doNotDisplay)
     */
    getCurrentStats(): {
        totalCurrent: number;
        totalOld: number;
        totalDoNotDisplay: number;
        totalNew: number;
        animesByDay: Record<string, number>;
        newAnimesByDay: Record<string, number>;
        lastUpdate?: string;
    } {
        const storage = this.getStorage();
        const animesByDay: Record<string, number> = {};
        const newAnimesByDay: Record<string, number> = {};
        
        // Filtrer les animes pour exclure doNotDisplay
        const filteredCurrentAnimes = this.filterOutDoNotDisplay(storage.currentAnime);
        const filteredNewAnimes = this.filterOutDoNotDisplay(storage.newAnime);
        
        // Compter les animes actuels par jour (filtrés)
        filteredCurrentAnimes.forEach(anime => {
            animesByDay[anime.dayOfWeek] = (animesByDay[anime.dayOfWeek] || 0) + 1;
        });
        
        // Compter les nouveaux animes par jour (filtrés)
        filteredNewAnimes.forEach(anime => {
            newAnimesByDay[anime.dayOfWeek] = (newAnimesByDay[anime.dayOfWeek] || 0) + 1;
        });
        
        return {
            totalCurrent: filteredCurrentAnimes.length,
            totalOld: storage.oldAnime.length,
            totalDoNotDisplay: storage.doNotDisplay.length,
            totalNew: filteredNewAnimes.length,
            animesByDay,
            newAnimesByDay,
            lastUpdate: storage.lastUpdate
        };
    }

    /**
     * Vérifier si le cache contient des données
     */
    hasCache(): boolean {
        const storage = this.getStorage();
        return storage.currentAnime.length > 0;
    }

    /**
     * Vider complètement le cache
     */
    clearCache(): void {
        const storage = this.initStorage();
        this.setStorage(storage);
    }

    /**
     * Vider seulement les anciens animes
     */
    clearOldAnimes(): void {
        const storage = this.getStorage();
        storage.oldAnime = [];
        this.setStorage(storage);
    }

    /**
     * Récupérer tous les animes actuels SANS filtrage doNotDisplay (pour administration)
     */
    getCurrentAnimesRaw(): AnimeStorageResult {
        try {
            const storage = this.getStorage();
            return {
                success: true,
                data: storage.currentAnime
            };
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }

    /**
     * Récupérer les nouveaux animes SANS filtrage doNotDisplay (pour administration)
     */
    getNewAnimesRaw(): AnimeStorageResult {
        try {
            const storage = this.getStorage();
            return {
                success: true,
                data: storage.newAnime
            };
        } catch (error) {
            return {
                success: false,
                data: null,
                error: error instanceof Error ? error.message : 'Erreur de récupération'
            };
        }
    }

    /**
     * Récupérer des statistiques complètes SANS filtrage (pour administration)
     */
    getCompleteStats(): {
        totalCurrentRaw: number;
        totalCurrentFiltered: number;
        totalOld: number;
        totalDoNotDisplay: number;
        totalNewRaw: number;
        totalNewFiltered: number;
        animesByDayRaw: Record<string, number>;
        animesByDayFiltered: Record<string, number>;
        newAnimesByDayRaw: Record<string, number>;
        newAnimesByDayFiltered: Record<string, number>;
        lastUpdate?: string;
    } {
        const storage = this.getStorage();
        const animesByDayRaw: Record<string, number> = {};
        const animesByDayFiltered: Record<string, number> = {};
        const newAnimesByDayRaw: Record<string, number> = {};
        const newAnimesByDayFiltered: Record<string, number> = {};
        
        // Filtrer les animes pour exclure doNotDisplay
        const filteredCurrentAnimes = this.filterOutDoNotDisplay(storage.currentAnime);
        const filteredNewAnimes = this.filterOutDoNotDisplay(storage.newAnime);
        
        // Compter les animes actuels par jour (bruts)
        storage.currentAnime.forEach(anime => {
            animesByDayRaw[anime.dayOfWeek] = (animesByDayRaw[anime.dayOfWeek] || 0) + 1;
        });
        
        // Compter les animes actuels par jour (filtrés)
        filteredCurrentAnimes.forEach(anime => {
            animesByDayFiltered[anime.dayOfWeek] = (animesByDayFiltered[anime.dayOfWeek] || 0) + 1;
        });
        
        // Compter les nouveaux animes par jour (bruts)
        storage.newAnime.forEach(anime => {
            newAnimesByDayRaw[anime.dayOfWeek] = (newAnimesByDayRaw[anime.dayOfWeek] || 0) + 1;
        });
        
        // Compter les nouveaux animes par jour (filtrés)
        filteredNewAnimes.forEach(anime => {
            newAnimesByDayFiltered[anime.dayOfWeek] = (newAnimesByDayFiltered[anime.dayOfWeek] || 0) + 1;
        });
        
        return {
            totalCurrentRaw: storage.currentAnime.length,
            totalCurrentFiltered: filteredCurrentAnimes.length,
            totalOld: storage.oldAnime.length,
            totalDoNotDisplay: storage.doNotDisplay.length,
            totalNewRaw: storage.newAnime.length,
            totalNewFiltered: filteredNewAnimes.length,
            animesByDayRaw,
            animesByDayFiltered,
            newAnimesByDayRaw,
            newAnimesByDayFiltered,
            lastUpdate: storage.lastUpdate
        };
    }
}

// Instance singleton
export const animeStorageService = new AnimeStorageService();

// Fonctions d'export pour utilisation facile
export const saveAnimes = (animes: AnimePlanning[]) => animeStorageService.saveAnimes(animes);
export const getCurrentAnimes = () => animeStorageService.getCurrentAnimes();
export const getCurrentAnimesByDay = (day: string) => animeStorageService.getCurrentAnimesByDay(day);
export const getOldAnimes = () => animeStorageService.getOldAnimes();
export const getDoNotDisplayAnimes = () => animeStorageService.getDoNotDisplayAnimes();
export const getNewAnimes = () => animeStorageService.getNewAnimes();
export const getNewAnimesByDay = (day: string) => animeStorageService.getNewAnimesByDay(day);

// Fonctions pour chaque jour (depuis currentAnime)
export const getCurrentLundiAnimes = () => animeStorageService.getCurrentLundiAnimes();
export const getCurrentMardiAnimes = () => animeStorageService.getCurrentMardiAnimes();
export const getCurrentMercrediAnimes = () => animeStorageService.getCurrentMercrediAnimes();
export const getCurrentJeudiAnimes = () => animeStorageService.getCurrentJeudiAnimes();
export const getCurrentVendrediAnimes = () => animeStorageService.getCurrentVendrediAnimes();
export const getCurrentSamediAnimes = () => animeStorageService.getCurrentSamediAnimes();
export const getCurrentDimancheAnimes = () => animeStorageService.getCurrentDimancheAnimes();

// Fonctions pour chaque jour (depuis newAnime)
export const getNewLundiAnimes = () => animeStorageService.getNewLundiAnimes();
export const getNewMardiAnimes = () => animeStorageService.getNewMardiAnimes();
export const getNewMercrediAnimes = () => animeStorageService.getNewMercrediAnimes();
export const getNewJeudiAnimes = () => animeStorageService.getNewJeudiAnimes();
export const getNewVendrediAnimes = () => animeStorageService.getNewVendrediAnimes();
export const getNewSamediAnimes = () => animeStorageService.getNewSamediAnimes();
export const getNewDimancheAnimes = () => animeStorageService.getNewDimancheAnimes();

// Fonctions de gestion
export const addToDoNotDisplay = (animeId: string) => animeStorageService.addToDoNotDisplay(animeId);
export const removeFromDoNotDisplay = (animeId: string) => animeStorageService.removeFromDoNotDisplay(animeId);
export const markNewAnimeAsSeen = (animeId: string) => animeStorageService.markNewAnimeAsSeen(animeId);

// Fonctions utilitaires
export const getCurrentTodayAnimes = () => animeStorageService.getCurrentTodayAnimes();
export const getCurrentStats = () => animeStorageService.getCurrentStats();
export const hasAnimeCache = () => animeStorageService.hasCache();
export const clearAnimeCache = () => animeStorageService.clearCache();
export const clearOldAnimes = () => animeStorageService.clearOldAnimes();
export const clearNewAnimes = () => animeStorageService.clearNewAnimes();

// Fonctions d'administration (sans filtrage doNotDisplay)
export const getCurrentAnimesRaw = () => animeStorageService.getCurrentAnimesRaw();
export const getNewAnimesRaw = () => animeStorageService.getNewAnimesRaw();
export const getCompleteStats = () => animeStorageService.getCompleteStats();
