import { AnimePlanning, AnimeViewed, AnimeStorage, Season } from '../../types/anime.types';

/**
 * Tests pour la logique de reclassification des animes
 */

// Mock data
const createMockAnime = (overrides?: Partial<AnimePlanning>): AnimePlanning => ({
    id: 'test-id-1',
    title: 'Test Anime',
    image: '',
    url: '/catalogue/test-anime/',
    fullUrl: 'https://anime-sama.to/catalogue/test-anime/',
    dayOfWeek: '',
    type: 'VOSTFR',
    ...overrides,
});

const createMockSeason = (overrides?: Partial<Season>): Season => ({
    name: 'Saison 1',
    url: '/catalogue/test-anime/season-1',
    type: 'regular',
    ...overrides,
});

// Test cases
export const testCases = {
    // Cas 1: 0 saisons vues → À regarder
    noSeasonViewed: {
        name: '0 saisons vues → À regarder',
        anime: createMockAnime({
            seasons: [
                createMockSeason({ name: 'Saison 1', type: 'regular' }),
                createMockSeason({ name: 'Saison 2', type: 'regular' }),
            ],
            viewedSeasons: [],
        }),
        expected: 'towatch',
    },

    // Cas 2: 1+ saisons vues mais pas toutes régulières → En cours
    someSeasonViewed: {
        name: '1 saison vue sur 2 régulières → En cours',
        anime: createMockAnime({
            seasons: [
                createMockSeason({ name: 'Saison 1', type: 'regular' }),
                createMockSeason({ name: 'Saison 2', type: 'regular' }),
            ],
            viewedSeasons: ['Saison 1'],
        }),
        expected: 'inprogress',
    },

    // Cas 3: Toutes les saisons régulières vues, mais pas les spéciaux → Complétés
    allRegularViewedWithSpecials: {
        name: 'Toutes saisons régulières vues + spéciaux → Complétés',
        anime: createMockAnime({
            seasons: [
                createMockSeason({ name: 'Saison 1', type: 'regular' }),
                createMockSeason({ name: 'Saison 2', type: 'regular' }),
                createMockSeason({ name: 'Spécial 1', type: 'special' }),
                createMockSeason({ name: 'Film 1', type: 'film' }),
            ],
            viewedSeasons: ['Saison 1', 'Saison 2'],
        }),
        expected: 'completed',
    },

    // Cas 4: Tout est vu (saisons + spéciaux + films) → Déjà vu
    allViewedIncludingSpecials: {
        name: 'Tout vu (saisons + spéciaux + films) → Déjà vu',
        anime: createMockAnime({
            seasons: [
                createMockSeason({ name: 'Saison 1', type: 'regular' }),
                createMockSeason({ name: 'Saison 2', type: 'regular' }),
                createMockSeason({ name: 'Spécial 1', type: 'special' }),
                createMockSeason({ name: 'Film 1', type: 'film' }),
            ],
            viewedSeasons: ['Saison 1', 'Saison 2', 'Spécial 1', 'Film 1'],
        }),
        expected: 'viewed',
    },

    // Cas 5: Pas de données de saisons → En cours (on présume que c'est commencé)
    noSeasonData: {
        name: 'Pas de données seasons mais viewedSeasons → En cours',
        anime: createMockAnime({
            seasons: undefined,
            viewedSeasons: ['Saison 1'],
        }),
        expected: 'inprogress',
    },

    // Cas 6: Saisons vues avec OAV et spéciaux variés
    complexScenario: {
        name: '2 régulières + 1 OAV + 2 spéciaux, 3 vus → Complétés',
        anime: createMockAnime({
            seasons: [
                createMockSeason({ name: 'Saison 1', type: 'regular' }),
                createMockSeason({ name: 'Saison 2', type: 'regular' }),
                createMockSeason({ name: 'OAV 1', type: 'oav' }),
                createMockSeason({ name: 'Spécial 1', type: 'special' }),
                createMockSeason({ name: 'Spécial 2', type: 'special' }),
            ],
            viewedSeasons: ['Saison 1', 'Saison 2', 'OAV 1'],
        }),
        expected: 'completed', // Toutes régulières vues, mais pas les spéciaux
    },
};

/**
 * Fonction pour classifier un anime basée sur ses saisons vues
 * Retourne: 'towatch' | 'inprogress' | 'completed' | 'viewed'
 */
export const classifyAnime = (anime: AnimePlanning): 'towatch' | 'inprogress' | 'completed' | 'viewed' => {
    const viewedSeasons = anime.viewedSeasons || [];

    // CAS 1: Aucune saison vue → À regarder
    if (viewedSeasons.length === 0) {
        return 'towatch';
    }

    // CAS 2: Des saisons ont été vues mais pas de données complètes
    if (!anime.seasons || anime.seasons.length === 0) {
        // On a viewedSeasons mais pas de données de saisons
        // → On présume que c'est partiellement vu (En cours)
        return 'inprogress';
    }

    // CAS 3 & 4: On a les données complètes
    const regularSeasons = anime.seasons.filter(s => s.type === 'regular');
    const allSeasons = anime.seasons;
    
    // Compter les saisons régulières vues
    const viewedRegularSeasons = viewedSeasons.filter(viewed =>
        regularSeasons.some(s => s.name === viewed)
    );

    // Compter TOUTES les saisons vues
    const viewedAllSeasons = viewedSeasons.length;

    // Si aucune saison régulière vues → À regarder
    if (viewedRegularSeasons.length === 0) {
        return 'towatch';
    }

    // Si 1+ régulière vues mais pas toutes → En cours
    if (viewedRegularSeasons.length > 0 && viewedRegularSeasons.length < regularSeasons.length) {
        return 'inprogress';
    }

    // Si toutes les régulières vues mais pas tout → Complétés
    if (viewedRegularSeasons.length === regularSeasons.length && viewedAllSeasons < allSeasons.length) {
        return 'completed';
    }

    // Si tout est vu → Déjà vu
    if (viewedAllSeasons === allSeasons.length) {
        return 'viewed';
    }

    // Fallback
    return 'inprogress';
};

/**
 * Fonction de test
 */
describe('Anime Storage - reclassifyAnime', () => {
    Object.values(testCases).forEach((testCase) => {
        test(testCase.name, () => {
            const result = classifyAnime(testCase.anime);
            expect(result).toBe(testCase.expected);
        });
    });
});
