/**
 * Migre le localStorage d'une extension anime-sama vers une autre.
 * Met à jour tous les fullUrl des animes stockés (current, new, old).
 */
export function migrateStorageDomain(oldExt: string, newExt: string): void {
    if (oldExt === newExt) return;

    const oldBase = `https://anime-sama.${oldExt}`;
    const newBase = `https://anime-sama.${newExt}`;

    console.log(`🔄 Migration localStorage: ${oldBase} → ${newBase}`);

    const STORAGE_KEY = 'anime_dashboard_v2';
    const EXT_KEY = 'anime_extension';

    try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) {
            localStorage.setItem(EXT_KEY, newExt);
            return;
        }

        const storage = JSON.parse(raw);
        let count = 0;

        const migrateList = (list: any[]) => {
            if (!Array.isArray(list)) return list;
            return list.map(anime => {
                if (anime.fullUrl && anime.fullUrl.startsWith(oldBase)) {
                    anime.fullUrl = anime.fullUrl.replace(oldBase, newBase);
                    count++;
                }
                return anime;
            });
        };

        storage.current = migrateList(storage.current);
        storage.new = migrateList(storage.new);
        storage.old = migrateList(storage.old);

        localStorage.setItem(STORAGE_KEY, JSON.stringify(storage));
        localStorage.setItem(EXT_KEY, newExt);

        console.log(`✅ Migration terminée: ${count} URLs mises à jour`);
    } catch (error) {
        console.error('❌ Erreur migration localStorage:', error);
    }
}
