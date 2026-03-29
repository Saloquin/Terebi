import React, { useState } from 'react';
import AnimePage from './components/Anime';
import { CatalogPage } from './components/Catalog/CatalogPage';
import { ToWatchPage } from './components/ToWatch/ToWatchPage';
import AnimeDetailPage from './components/AnimeDetail/AnimeDetailPage';
import { AnimePlanning } from './types/anime.types';

const App: React.FC = () => {
    const [currentPage, setCurrentPage] = useState<'anime' | 'catalog' | 'towatch' | 'detail'>('anime');
    const [selectedAnime, setSelectedAnime] = useState<AnimePlanning | null>(null);

    const handleSelectAnime = (anime: AnimePlanning) => {
        setSelectedAnime(anime);
        setCurrentPage('detail');
    };

    const handleBackFromDetail = () => {
        setSelectedAnime(null);
        setCurrentPage('anime');
    };

    const handlePageChange = (page: 'anime' | 'catalog' | 'towatch') => {
        // Clear selected anime when navigating away from detail
        setSelectedAnime(null);
        setCurrentPage(page);
    };

    return (
        <div>
            {/* Navigation Tabs */}
            <div className="sticky top-0 z-50 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
                <div className="max-w-6xl mx-auto px-4 flex gap-4 justify-between">
                    <div className="flex gap-4">
                        <button
                            onClick={() => handlePageChange('anime')}
                            className={`py-3 px-6 font-medium border-b-2 transition-colors ${
                                currentPage === 'anime'
                                    ? 'border-blue-600 text-blue-600'
                                    : 'border-transparent text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                            }`}
                        >
                            Planning
                        </button>
                        <button
                            onClick={() => handlePageChange('catalog')}
                            className={`py-3 px-6 font-medium border-b-2 transition-colors ${
                                currentPage === 'catalog'
                                    ? 'border-blue-600 text-blue-600'
                                    : 'border-transparent text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                            }`}
                        >
                            Catalogue
                        </button>
                    </div>
                    <button
                        onClick={() => handlePageChange('towatch')}
                        className={`py-3 px-6 font-medium border-b-2 transition-colors ${
                            currentPage === 'towatch'
                                ? 'border-blue-600 text-blue-600'
                                : 'border-transparent text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                        }`}
                    >
                        À regarder
                    </button>
                </div>
            </div>

            {/* Page Content */}
            {currentPage === 'anime' && <AnimePage selectedAnime={selectedAnime} onDeselectAnime={() => setSelectedAnime(null)} />}
            {currentPage === 'catalog' && <CatalogPage onSelectAnime={handleSelectAnime} />}
            {currentPage === 'towatch' && <ToWatchPage onSelectAnime={handleSelectAnime} />}
            {currentPage === 'detail' && selectedAnime && <AnimeDetailPage anime={selectedAnime} onBack={handleBackFromDetail} theme={document.documentElement.classList.contains('dark') ? 'dark' : 'light'} />}
        </div>
    );
};

export default App;