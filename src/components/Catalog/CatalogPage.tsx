import React, { useState } from 'react';
import { CatalogSearch } from '../Catalog/CatalogSearch';

interface CatalogPageProps {
    theme?: 'light' | 'dark';
}

export const CatalogPage: React.FC<CatalogPageProps> = ({ theme = 'light' }) => {
    const [pageTitle, setPageTitle] = useState('Catalogue');

    return (
        <div className={theme === 'dark' ? 'dark' : ''}>
            <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
                <div className="max-w-6xl mx-auto px-4 py-8">
                    {/* Header */}
                    <div className="mb-8">
                        <h1 className="text-4xl font-bold mb-2">Catalogue Anime</h1>
                        <p className="text-gray-600 dark:text-gray-400">
                            Recherchez et découvrez des animes, mangas et scans
                        </p>
                    </div>

                    {/* Search Component */}
                    <CatalogSearch
                        onSearch={(query, page) => {
                            setPageTitle(`Catalogue - Résultats pour "${query}"`);
                        }}
                    />
                </div>
            </div>
        </div>
    );
};
