import { animeStorage } from '../../services/api/anime.storage';
import { STORAGE_KEY } from './storage.utils';
import { AnimePlanning } from '../../types/anime.types';

describe('Planning Logic & Storage Flow', () => {
    beforeEach(() => {
        localStorage.clear();
        // Force the storage initialization
        animeStorage.readStorage();
    });

    const createAnime = (title: string, time: string | null = null, type: 'VOSTFR'|'VF' = 'VOSTFR', dayOfWeek = 'Lundi'): AnimePlanning => ({
        id: `${title.toLowerCase().replace(/[^a-z0-9]/g, '')}-${type.toLowerCase()}`,
        title,
        image: '',
        url: '',
        dayOfWeek,
        time: time || undefined,
        type
    });

    test('E2E: Anime with volatile time (null / ?) gets overwritten correctly by valid time', () => {
        // Step 1: Initial api scrape has an anime with unknown time '?'
        const animeUnknown = createAnime('One Piece', '?');
        
        animeStorage.syncWithApi([animeUnknown]);
        
        let storage = animeStorage.readStorage();
        expect(storage.current).toHaveLength(1);
        expect(storage.current[0].time).toBe('?');
        expect(storage.new).toHaveLength(1);
        expect(storage.new[0].time).toBe('?');
        
        // Step 2: Next week's api scrape receives the identical anime but with correct time '18h30'
        const animeProper = createAnime('One Piece', '18h30');
        
        animeStorage.syncWithApi([animeProper]);
        
        storage = animeStorage.readStorage();
        
        // The anime in 'current' MUST be overwrited and its time must be updated
        expect(storage.current).toHaveLength(1);
        expect(storage.current[0].time).toBe('18h30');
        
        // It shouldn't crash, and shouldn't add duplicates
        expect(storage.current[0].id).toBe('onepiece-vostfr');
    });

    test('E2E: Hide, restore, and clear flow', () => {
        const animeA = createAnime('Naruto', '10h00', 'VOSTFR', 'Dimanche');
        const animeB = createAnime('Bleach', '11h00', 'VOSTFR', 'Lundi');

        animeStorage.syncWithApi([animeA, animeB]);
        
        // Hide Naruto
        animeStorage.hideAnime(animeA.id);
        
        let storage = animeStorage.readStorage();
        expect(storage.hidden).toContain(animeA.id);
        
        // getPlanningAnime ignores hidden items
        const planningList = animeStorage.getCurrent();
        expect(planningList.find(a => a.id === animeA.id)).toBeUndefined();
        expect(planningList.find(a => a.id === animeB.id)).toBeDefined();

        // Restore Naruto
        animeStorage.restoreAnime(animeA.id);
        
        storage = animeStorage.readStorage();
        expect(storage.hidden).not.toContain(animeA.id);
        expect(animeStorage.getCurrent().find(a => a.id === animeA.id)).toBeDefined();
        
        // Now API drops Naruto (Naruto moves to old logic)
        animeStorage.syncWithApi([animeB]);
        
        storage = animeStorage.readStorage();
        expect(storage.current).toHaveLength(1);
        expect(storage.current[0].id).toBe(animeB.id);
        expect(storage.old).toHaveLength(1);
        expect(storage.old[0].id).toBe(animeA.id);
        
        // Hide Naruto which is now in old
        animeStorage.hideAnime(animeA.id);
        expect(animeStorage.getHidden().find(a => a.id === animeA.id)).toBeDefined();
        
        // Removing from old should also remove from hidden to avoid memory leaks
        animeStorage.removeFromOld(animeA.id);
        
        storage = animeStorage.readStorage();
        expect(storage.old).toHaveLength(0);
        expect(storage.hidden).not.toContain(animeA.id);
    });

    test('E2E: Anime switching valid time (eg: changes hours) should update without duplications', () => {
        // Monday 18h
        const animeT1 = createAnime('Mob Psycho', '18h00', 'VOSTFR', 'Lundi');
        animeStorage.syncWithApi([animeT1]);
        
        let storage = animeStorage.readStorage();
        expect(storage.current[0].time).toBe('18h00');
        
        // Suddendly schedule changes: Monday 19h
        const animeT2 = createAnime('Mob Psycho', '19h00', 'VOSTFR', 'Lundi');
        animeStorage.syncWithApi([animeT2]);
        
        storage = animeStorage.readStorage();
        expect(storage.current).toHaveLength(1);
        expect(storage.current[0].time).toBe('19h00');
        expect(storage.current[0].id).toBe('mobpsycho-vostfr');
    });
});
