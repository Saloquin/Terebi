import { AnimePlanning } from '../../types/anime.types';
import { readStorage, writeStorage } from './storage.utils';

/**
 * Récupère les animes marqués "À voir"
 */
export const getToWatchAnime = (): AnimePlanning[] => {
    const storage = readStorage();
    return storage.towatch || [];
};

/**
 * Marque un anime comme "À voir"
 */
export const markAsToWatch = (anime: AnimePlanning): void => {
    const storage = readStorage();
    
    if (!storage.towatch) {
        storage.towatch = [];
    }

    // Vérifier si l'anime est déjà marqué "à voir"
    const exists = storage.towatch.some((a: AnimePlanning) => 
        a.title.toLowerCase().replace(/[^a-z0-9]/g, '') === 
        anime.title.toLowerCase().replace(/[^a-z0-9]/g, '')
    );

    if (!exists) {
        storage.towatch.push(anime);
        writeStorage(storage);
        console.log(`⭐ Ajouté à "À voir": ${anime.title}`);
    }
};

/**
 * Retire un anime de "À voir"
 */
export const removeFromToWatch = (id: string): void => {
    const storage = readStorage();
    
    if (!storage.towatch) {
        storage.towatch = [];
    }

    storage.towatch = storage.towatch.filter((a: AnimePlanning) => 
        a.title.toLowerCase().replace(/[^a-z0-9]/g, '') !== 
        id.toLowerCase().replace(/[^a-z0-9]/g, '')
    );

    writeStorage(storage);
    console.log(`✖️ Retiré de "À voir": ${id}`);
};

/**
 * Vérifie si un anime est dans "À voir"
 */
export const isInToWatch = (title: string): boolean => {
    const storage = readStorage();
    if (!storage.towatch) return false;

    const normalized = title.toLowerCase().replace(/[^a-z0-9]/g, '');
    return storage.towatch.some((a: AnimePlanning) => 
        a.title.toLowerCase().replace(/[^a-z0-9]/g, '') === normalized
    );
};

