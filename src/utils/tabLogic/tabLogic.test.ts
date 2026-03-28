import {
    getHiddenAnime,
    getNewAnime,
    getOldAnime,
    getPlanningAnime,
    getTabLogic,
    newMarkAsSeen,
    removeOldAnime,
    restoreHiddenAnime,
} from './index';
import { AnimeStorage } from '../../types/anime.types';
import { STORAGE_KEY } from './storage.utils';
import { TabHandlers, TabActionBindings } from './types';

const makeHandlers = (): TabHandlers => ({
    hideAnime: jest.fn(),
    restoreAnime: jest.fn(),
    markAsSeen: jest.fn(),
    removeFromOld: jest.fn(),
});

const assertBindings = (bindings: TabActionBindings) => {
    expect(bindings).toHaveProperty('isHiddenList');
    expect(bindings).toHaveProperty('isNewList');
    expect(bindings).toHaveProperty('isOldList');
};

describe('tab logic', () => {
    beforeEach(() => {
        localStorage.clear();
    });

    test('planning: empty message + hide only', () => {
        const handlers = makeHandlers();
        const logic = getTabLogic('planning');
        const bindings = logic.bindActions(handlers);

        expect(logic.emptyMessage).toBe('Aucun anime dans le planning');
        expect(bindings.onHide).toBe(handlers.hideAnime);
        expect(bindings.onMarkSeen).toBeUndefined();
        expect(bindings.onRemoveOld).toBeUndefined();
        expect(bindings.onRestore).toBeUndefined();
        expect(bindings.isHiddenList).toBe(false);
        assertBindings(bindings);
    });

    test('nouveaux: remove from new only', () => {
        const handlers = makeHandlers();
        const logic = getTabLogic('nouveaux');
        const bindings = logic.bindActions(handlers);

        expect(logic.emptyMessage).toBe('Pas de nouveaux animes détectés');
        expect(bindings.onMarkSeen).toBe(handlers.markAsSeen);
        expect(bindings.onHide).toBeUndefined();
        expect(bindings.onRemoveOld).toBeUndefined();
        expect(bindings.onRestore).toBeUndefined();
        expect(bindings.isNewList).toBe(true);
        assertBindings(bindings);
    });

    test('anciens: remove from old only', () => {
        const handlers = makeHandlers();
        const logic = getTabLogic('anciens');
        const bindings = logic.bindActions(handlers);

        expect(logic.emptyMessage).toBe('Pas d\'anciens animes');
        expect(bindings.onRemoveOld).toBe(handlers.removeFromOld);
        expect(bindings.onHide).toBeUndefined();
        expect(bindings.onMarkSeen).toBeUndefined();
        expect(bindings.onRestore).toBeUndefined();
        expect(bindings.isOldList).toBe(true);
        assertBindings(bindings);
    });

    test('masques: remove from hidden only', () => {
        const handlers = makeHandlers();
        const logic = getTabLogic('masques');
        const bindings = logic.bindActions(handlers);

        expect(logic.emptyMessage).toBe('Aucun anime masqué');
        expect(bindings.onRestore).toBe(handlers.restoreAnime);
        expect(bindings.onHide).toBeUndefined();
        expect(bindings.onMarkSeen).toBeUndefined();
        expect(bindings.onRemoveOld).toBeUndefined();
        expect(bindings.isHiddenList).toBe(true);
        assertBindings(bindings);
    });

    test('getPlanningAnime: returns planning without hidden and sorted', () => {
        const storage: AnimeStorage = {
            current: [
                { id: '2', title: 'B', image: '', url: '', dayOfWeek: 'Mardi', type: 'VOSTFR' },
                { id: '1', title: 'A', image: '', url: '', dayOfWeek: 'Lundi', type: 'VOSTFR' },
            ],
            new: [],
            old: [],
            hidden: ['2'],
            towatch: [],
            lastUpdate: new Date().toISOString(),
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(storage));

        const planning = getPlanningAnime();
        expect(planning).toHaveLength(1);
        expect(planning[0].id).toBe('1');
    });

    test('new logic: getNewAnime + newMarkAsSeen', () => {
        const storage: AnimeStorage = {
            current: [],
            new: [
                { id: 'n1', title: 'N1', image: '', url: '', dayOfWeek: 'Lundi', type: 'VOSTFR' },
                { id: 'n2', title: 'N2', image: '', url: '', dayOfWeek: 'Mardi', type: 'VOSTFR' },
            ],
            old: [],
            hidden: ['n2'],
            towatch: [],
            lastUpdate: new Date().toISOString(),
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(storage));

        expect(getNewAnime().map(a => a.id)).toEqual(['n1']);
        expect(newMarkAsSeen('n1')).toBe(true);

        const after = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}') as AnimeStorage;
        expect(after.new.map(a => a.id)).toEqual(['n2']);
    });

    test('old logic: getOldAnime + removeOldAnime removes hidden too', () => {
        const storage: AnimeStorage = {
            current: [],
            new: [],
            old: [
                { id: 'o1', title: 'O1', image: '', url: '', dayOfWeek: 'Jeudi', type: 'VOSTFR' },
                { id: 'o2', title: 'O2', image: '', url: '', dayOfWeek: 'Vendredi', type: 'VOSTFR' },
            ],
            hidden: ['o1'],
            towatch: [],
            lastUpdate: new Date().toISOString(),
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(storage));

        expect(getOldAnime().map(a => a.id)).toEqual(['o2']);
        expect(removeOldAnime('o1')).toBe(true);

        const after = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}') as AnimeStorage;
        expect(after.old.map(a => a.id)).toEqual(['o2']);
        expect(after.hidden).toEqual([]);
    });

    test('hidden logic: getHiddenAnime + restoreHiddenAnime', () => {
        const storage: AnimeStorage = {
            current: [{ id: 'c1', title: 'C1', image: '', url: '', dayOfWeek: 'Lundi', type: 'VOSTFR' }],
            new: [{ id: 'n1', title: 'N1', image: '', url: '', dayOfWeek: 'Mardi', type: 'VOSTFR' }],
            old: [{ id: 'o1', title: 'O1', image: '', url: '', dayOfWeek: 'Mercredi', type: 'VOSTFR' }],
            hidden: ['n1', 'o1'],
            towatch: [],
            lastUpdate: new Date().toISOString(),
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(storage));

        expect(getHiddenAnime().map(a => a.id)).toEqual(['n1', 'o1']);
        expect(restoreHiddenAnime('n1')).toBe(true);

        const after = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}') as AnimeStorage;
        expect(after.hidden).toEqual(['o1']);
    });
});
