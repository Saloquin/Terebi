import React from 'react';
import { BrowserRouter, Routes, Route, NavLink, Navigate, useParams, useNavigate, useLocation } from 'react-router-dom';
import AnimePage from './components/Anime';
import { CatalogPage } from './components/Catalog/CatalogPage';
import { ToWatchPage } from './components/ToWatch/ToWatchPage';
import AnimeDetailPage from './components/AnimeDetail/AnimeDetailPage';
import { findAnimeBySlug, extractCatalogSlug } from './utils/anime.utils';
import { AnimePlanning } from './types/anime.types';

const navLinkClass = ({ isActive }: { isActive: boolean }) =>
    `py-3 px-6 font-medium border-b-2 transition-colors ${
        isActive
            ? 'border-blue-600 text-blue-600'
            : 'border-transparent text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
    }`;

const AppLayout: React.FC = () => {
    const navigate = useNavigate();

    const handleSelectAnime = (anime: AnimePlanning) => {
        const catalogSlug = extractCatalogSlug(anime.fullUrl || anime.url);
        if (catalogSlug) {
            navigate(`/anime/${catalogSlug}`, { state: { anime } });
        }
    };

    return (
        <div>
            <div className="sticky top-0 z-50 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
                <div className="max-w-6xl mx-auto px-4 flex gap-4 justify-between">
                    <div className="flex gap-4">
                        <NavLink to="/planning" className={navLinkClass}>
                            Planning
                        </NavLink>
                        <NavLink to="/catalog" className={navLinkClass}>
                            Catalogue
                        </NavLink>
                    </div>
                    <NavLink to="/towatch" className={navLinkClass}>
                        À regarder
                    </NavLink>
                </div>
            </div>

            <Routes>
                <Route path="/" element={<Navigate to="/planning" replace />} />
                <Route path="/planning" element={<AnimePage />} />
                <Route path="/catalog" element={<CatalogPage onSelectAnime={handleSelectAnime} />} />
                <Route path="/towatch" element={<ToWatchPage onSelectAnime={handleSelectAnime} />} />
                <Route path="/anime/:slug" element={<AnimeDetailRoute />} />
                <Route path="*" element={<Navigate to="/planning" replace />} />
            </Routes>
        </div>
    );
};

const AnimeDetailRoute: React.FC = () => {
    const { slug } = useParams<{ slug: string }>();
    const navigate = useNavigate();
    const location = useLocation();
    const locationState = location.state as { anime?: AnimePlanning } | null;

    const anime = locationState?.anime || (slug ? findAnimeBySlug(slug) : null);

    if (!anime || !slug) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-white dark:bg-gray-900">
                <div className="text-center">
                    <p className="text-gray-600 dark:text-gray-400 mb-4">Anime introuvable.</p>
                    <button
                        onClick={() => navigate('/catalog')}
                        className="px-4 py-2 bg-blue-600 text-white rounded-lg"
                    >
                        Retour au catalogue
                    </button>
                </div>
            </div>
        );
    }

    const theme = document.documentElement.classList.contains('dark') ? 'dark' : 'light';

    return (
        <AnimeDetailPage
            anime={anime}
            onBack={() => navigate(-1)}
            theme={theme}
        />
    );
};

const App: React.FC = () => (
    <BrowserRouter>
        <AppLayout />
    </BrowserRouter>
);

export default App;
