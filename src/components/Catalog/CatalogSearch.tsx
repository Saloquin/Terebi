import React, { useState, useCallback } from 'react';
import Search from '@mui/icons-material/Search';
import CircularProgress from '@mui/material/CircularProgress';
import Pagination from '@mui/material/Pagination';
import Box from '@mui/material/Box';
import { createTheme, ThemeProvider } from '@mui/material/styles';

interface CatalogItem {
    id: string;
    title: string;
    image?: string;
    url: string;
    fullUrl: string;
}

interface CatalogSearchProps {
    onSearch?: (query: string, page: number) => void;
}

const paginationTheme = createTheme({
    palette: {
        primary: {
            main: '#3b82f6',
        },
    },
});

export const CatalogSearch: React.FC<CatalogSearchProps> = ({ onSearch }) => {
    const [searchQuery, setSearchQuery] = useState('');
    const [currentPage, setCurrentPage] = useState(1);
    const [results, setResults] = useState<CatalogItem[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [hasSearched, setHasSearched] = useState(false);
    const [totalPages, setTotalPages] = useState(1);

    // Load initial catalog on mount
    React.useEffect(() => {
        loadCatalog('', 1);
    }, []);

    const loadCatalog = useCallback(async (query: string = searchQuery, page: number = 1) => {
        setIsLoading(true);
        setError(null);
        setCurrentPage(page);

        try {
            const url = query.trim()
                ? `/api/animes/catalogue?search=${encodeURIComponent(query)}&page=${page}`
                : `/api/animes/catalogue?page=${page}`;

            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`Erreur API: ${response.status}`);
            }

            const data = await response.json();
            if (data.success && data.data.items) {
                setResults(data.data.items);
                setHasSearched(true);
                // Estimate total pages based on current page
                const estimatedPages = Math.max(page + 2, 10);
                setTotalPages(estimatedPages);
                onSearch?.(query, page);
            } else {
                setError('Aucun résultat trouvé');
                setResults([]);
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Erreur lors du chargement');
            setResults([]);
        } finally {
            setIsLoading(false);
        }
    }, [searchQuery, onSearch]);

    const handleSearch = useCallback(async (query: string = searchQuery, page: number = 1) => {
        if (!query.trim()) {
            // If search is empty, just load the general catalog
            await loadCatalog('', page);
        } else {
            await loadCatalog(query, page);
        }
    }, [searchQuery, loadCatalog]);

    const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
        if (e.key === 'Enter') {
            handleSearch();
        }
    };

    return (
        <div className="space-y-6">
            {/* Search Bar */}
            <div className="flex gap-3">
                <div className="flex-1 flex gap-2">
                    <input
                        type="text"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        onKeyDown={handleKeyDown}
                        placeholder="Rechercher un anime, manga..."
                        className="flex-1 px-4 py-3 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                    <button
                        onClick={() => handleSearch()}
                        disabled={isLoading}
                        className="px-6 py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white rounded-lg font-medium transition-colors flex items-center gap-2"
                    >
                        {isLoading ? (
                            <CircularProgress size={20} className="text-white" />
                        ) : (
                            <Search />
                        )}
                        Rechercher
                    </button>
                </div>
            </div>

            {/* Error Message */}
            {error && (
                <div className="p-4 bg-red-100 dark:bg-red-900/30 border border-red-300 dark:border-red-700 rounded-lg text-red-700 dark:text-red-400">
                    {error}
                </div>
            )}

            {/* Loading State */}
            {isLoading && (
                <div className="flex justify-center py-8">
                    <CircularProgress size={40} />
                </div>
            )}

            {/* Results Grid */}
            {!isLoading && hasSearched && results.length > 0 && (
                <div className="space-y-6">
                    {/* Top Pagination */}
                    <Box className="flex justify-center py-4 bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700">
                        <ThemeProvider theme={paginationTheme}>
                            <Pagination
                                count={totalPages}
                                page={currentPage}
                                onChange={(_, page) => loadCatalog(searchQuery, page)}
                                color="primary"
                                size="large"
                                showFirstButton
                                showLastButton
                            />
                        </ThemeProvider>
                    </Box>

                    <h2 className="text-xl font-bold text-gray-900 dark:text-white">
                        Résultats ({results.length})
                    </h2>
                    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                        {results.map((item) => (
                            <a
                                key={item.id}
                                href={item.fullUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="group rounded-lg overflow-hidden hover:shadow-lg transition-shadow bg-gray-100 dark:bg-gray-700"
                            >
                                {item.image ? (
                                    <img
                                        src={item.image}
                                        alt={item.title}
                                        className="w-full h-48 object-cover group-hover:opacity-80 transition-opacity"
                                    />
                                ) : (
                                    <div className="w-full h-48 bg-gray-300 dark:bg-gray-600 flex items-center justify-center">
                                        <span className="text-gray-500 dark:text-gray-400">Pas d'image</span>
                                    </div>
                                )}
                                <div className="p-3">
                                    <h3 className="font-semibold text-sm text-gray-900 dark:text-white line-clamp-2 group-hover:text-blue-600 dark:group-hover:text-blue-400">
                                        {item.title}
                                    </h3>
                                </div>
                            </a>
                        ))}
                    </div>

                    {/* Bottom Pagination */}
                    <Box className="flex justify-center py-4 bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700">
                        <ThemeProvider theme={paginationTheme}>
                            <Pagination
                                count={totalPages}
                                page={currentPage}
                                onChange={(_, page) => loadCatalog(searchQuery, page)}
                                color="primary"
                                size="large"
                                showFirstButton
                                showLastButton
                            />
                        </ThemeProvider>
                    </Box>
                </div>
            )}

            {/* Empty State */}
            {!isLoading && !hasSearched && (
                <div className="text-center py-12">
                    <Search className="text-6xl text-gray-300 dark:text-gray-600 mx-auto mb-4" />
                    <p className="text-gray-500 dark:text-gray-400">
                        Chargement du catalogue...
                    </p>
                </div>
            )}

            {!isLoading && hasSearched && results.length === 0 && !error && (
                <div className="text-center py-12">
                    <p className="text-gray-500 dark:text-gray-400">
                        Aucun résultat pour votre recherche
                    </p>
                </div>
            )}
        </div>
    );
};
