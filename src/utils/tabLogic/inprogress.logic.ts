import { AnimePlanning, Season } from '../../types/anime.types';
import { readStorage, writeStorage } from './storage.utils';

/**
 * Récupère les animes en cours de lecture (au moins 1 saison vue mais pas toutes)
 */
export const getInProgressAnime = (): AnimePlanning[] => {
    const storage = readStorage();
    if (!storage.towatch) return [];

    return storage.towatch.filter((anime: AnimePlanning) => {
        if (!anime.viewedSeasons || anime.viewedSeasons.length === 0) {
            return false; // Pas commencé
        }

        if (!anime.seasons) {
            return true; // Au moins 1 saison vue et pas de données de saisons
        }

        // Compter seulement les saisons régulières
        const regularSeasons = anime.seasons.filter(s => s.type === 'regular');
        const viewedRegularSeasons = anime.viewedSeasons.filter(viewed =>
            regularSeasons.some(s => s.name === viewed)
        );

        // En cours = au moins 1 saison vue ET pas toutes les saisons régulières vues
        return viewedRegularSeasons.length > 0 && viewedRegularSeasons.length < regularSeasons.length;
    });
};

/**
 * Récupère les animes "À regarder complétés" (toutes les saisons régulières vues)
 */
export const getCompletedToWatchAnime = (): AnimePlanning[] => {
    const storage = readStorage();
    if (!storage.towatch) return [];

    return storage.towatch.filter((anime: AnimePlanning) => {
        if (!anime.viewedSeasons || anime.viewedSeasons.length === 0) {
            return false; // Aucune saison vue
        }

        if (!anime.seasons || anime.seasons.length === 0) {
            return false; // Pas de données de saisons
        }

        // Compter seulement les saisons régulières
        const regularSeasons = anime.seasons.filter(s => s.type === 'regular');
        
        if (regularSeasons.length === 0) {
            return false; // Pas de saisons régulières
        }

        // Vérifier que toutes les saisons régulières sont vues
        const viewedRegularSeasons = anime.viewedSeasons.filter(viewed =>
            regularSeasons.some(s => s.name === viewed)
        );

        return viewedRegularSeasons.length === regularSeasons.length;
    });
};

/**
 * Récupère les animes "À regarder" (aucune saison vue)
 */
export const getNotStartedToWatchAnime = (): AnimePlanning[] => {
    const storage = readStorage();
    if (!storage.towatch) return [];

    return storage.towatch.filter((anime: AnimePlanning) => {
        return !anime.viewedSeasons || anime.viewedSeasons.length === 0;
    });
};
