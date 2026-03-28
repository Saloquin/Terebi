import React, { useState } from 'react';
import { CatalogSearch } from '../Catalog/CatalogSearch';
import { AnimePlanning } from '../../types/anime.types';
import { markAsToWatch, removeFromToWatch } from '../../utils/tabLogic/towatch.logic';
import { useAnimeData } from '../../hooks/useAnimeData';

interface CatalogPageProps {
    theme?: 'light' | 'dark';
}

export const CatalogPage: React.FC<CatalogPageProps> = ({ theme = 'light' }) => {
    const [pageTitle, setPageTitle] = useState('Catalogue');
    const { towatch } = useAnimeData();

    const handleAddToWatch = (item: any) => {
        const anime: AnimePlanning = {
            id: item.id,
            title: item.title,
            image: item.image || '',
            url: item.url,
            fullUrl: item.fullUrl,
            dayOfWeek: '',
            type: 'VOSTFR' as any,
        };
        markAsToWatch(anime);
        alert(`✅ "${item.title}" ajouté à "À voir"!`);
    };

    const handleRemoveFromToWatch = (title: string) => {
        removeFromToWatch(title);
        alert(`❌ "${title}" retiré de "À voir"!`);
    };

    return (
        <div className={theme === 'dark' ? 'dark' : ''}>
            <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
                <div className="max-w-6xl mx-auto px-4 py-8">
                    {/* Header */}
                    <div className="mb-8">
                        <h1 className="text-4xl font-bold mb-2">Catalogue Anime et Films</h1>
                        <p className="text-gray-600 dark:text-gray-400">
                            Découvrez notre sélection d'animes et de films en VOSTFR
                        </p>
                    </div>

                    {/* Search Component */}
                    <CatalogSearch
                        onSearch={(query, page) => {
                            setPageTitle(`Catalogue - Résultats pour "${query}"`);
                        }}
                        onAddToWatch={handleAddToWatch}
                        onRemoveFromToWatch={handleRemoveFromToWatch}
                        toWatchTitles={towatch.map(a => a.title)}
                    />
                </div>
            </div>
        </div>
    );
};
