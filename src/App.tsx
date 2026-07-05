import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useLocation, useNavigate } from 'react-router-dom';
import AnimePage from './pages/Anime';
import { CatalogPage } from './pages/Catalog/CatalogPage';
import { ToWatchPage } from './pages/ToWatch/ToWatchPage';
import AnimeDetailPage from './pages/AnimeDetail/AnimeDetailPage';
import { AnimePlanning } from './types/anime.types';

const Navigation = () => {
    const location = useLocation();
    
    return (
        <div className="sticky top-0 z-50 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
            <div className="max-w-6xl mx-auto px-4 flex gap-4 justify-between">
                <div className="flex gap-4">
                    <Link
                        to="/planning"
                        className={`py-3 px-6 font-medium border-b-2 transition-colors ${
                            location.pathname === '/planning' || location.pathname === '/'
                                ? 'border-blue-600 text-blue-600'
                                : 'border-transparent text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                        }`}
                    >
                        Planning
                    </Link>
                    <Link
                        to="/catalog"
                        className={`py-3 px-6 font-medium border-b-2 transition-colors ${
                            location.pathname === '/catalog'
                                ? 'border-blue-600 text-blue-600'
                                : 'border-transparent text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                        }`}
                    >
                        Catalogue
                    </Link>
                </div>
                <Link
                    to="/towatch"
                    className={`py-3 px-6 font-medium border-b-2 transition-colors ${
                        location.pathname === '/towatch'
                            ? 'border-blue-600 text-blue-600'
                            : 'border-transparent text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                    }`}
                >
                    À regarder
                </Link>
            </div>
        </div>
    );
};

const AnimeRouter = () => {
    const navigate = useNavigate();
    const [selectedAnime, setSelectedAnime] = useState<AnimePlanning | null>(null);

    const handleSelectAnime = (anime: AnimePlanning) => {
        setSelectedAnime(anime);
        navigate('/detail');
    };

    const handleBackFromDetail = () => {
        setSelectedAnime(null);
        navigate(-1);
    };

    return (
        <div>
            <Navigation />
            <Routes>
                <Route path="/" element={<AnimePage selectedAnime={selectedAnime} onDeselectAnime={() => setSelectedAnime(null)} />} />
                <Route path="/planning" element={<AnimePage selectedAnime={selectedAnime} onDeselectAnime={() => setSelectedAnime(null)} />} />
                <Route path="/catalog" element={<CatalogPage onSelectAnime={handleSelectAnime} />} />
                <Route path="/towatch" element={<ToWatchPage onSelectAnime={handleSelectAnime} />} />
                <Route 
                    path="/detail" 
                    element={
                        selectedAnime ? (
                            <AnimeDetailPage 
                                anime={selectedAnime} 
                                onBack={handleBackFromDetail} 
                                theme={document.documentElement.classList.contains('dark') ? 'dark' : 'light'} 
                            />
                        ) : (
                            <div className="p-8 text-center">Aucun anime sélectionné. <Link to="/planning" className="text-blue-500">Retour au planning</Link></div>
                        )
                    } 
                />
            </Routes>
        </div>
    );
};

const App: React.FC = () => {
    return (
        <Router>
            <AnimeRouter />
        </Router>
    );
};

export default App;