import React, { useState, useCallback } from 'react';
import Search from '@mui/icons-material/Search';
import CircularProgress from '@mui/material/CircularProgress';
import Pagination from '@mui/material/Pagination';
import Box from '@mui/material/Box';
import Tabs from '@mui/material/Tabs';
import Tab from '@mui/material/Tab';
import { createTheme, ThemeProvider } from '@mui/material/styles';
import { CatalogAnimeCard } from './CatalogAnimeCard';

interface CatalogItem {
    id: string;
    title: string;
    image?: string;
    url: string;
    fullUrl: string;
    genres?: string[];
    year?: string;
    score?: number;
    status?: string;
    type?: string;
}

interface CatalogSearchProps {
    onSearch?: (query: string, page: number) => void;
    onAddToWatch?: (item: CatalogItem) => void;
    onRemoveFromToWatch?: (id: string) => void;
    toWatchTitles?: string[];
    viewedIds?: string[];
    onSelectAnime?: (anime: any) => void;
}

const paginationTheme = createTheme({
    palette: {
        primary: {
            main: '#3b82f6',
        },
    },
    components: {
        MuiPaginationItem: {
            styleOverrides: {
                root: {
                    color: '#3b82f6',
                    fontSize: '1rem',
                    fontWeight: 500,
                    '&:hover': {
                        backgroundColor: 'rgba(59, 130, 246, 0.1)',
                    },
                },
                page: {
                    color: '#3b82f6',
                },
                previousNext: {
                    color: '#3b82f6',
                },
            },
        },
    },
});

export const CatalogSearch: React.FC<CatalogSearchProps> = ({ 
    onSearch, 
    onAddToWatch, 
    onRemoveFromToWatch, 
    toWatchTitles = [], 
    viewedIds = [],
    onSelectAnime
}) => {
    const [searchQuery, setSearchQuery] = useState('');
    const [currentPage, setCurrentPage] = useState(1);
    const [results, setResults] = useState<CatalogItem[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [hasSearched, setHasSearched] = useState(false);
    const [totalPages, setTotalPages] = useState(1);
    const [contentType, setContentType] = useState<number>(0);

    // Load initial catalog on mount
    React.useEffect(() => {
        loadCatalog('', 1);
    }, []);

    const loadCatalog = useCallback(async (query: string = '', page: number = 1, type: number = contentType) => {
        setIsLoading(true);
        setError(null);
        setCurrentPage(page);

        try {
            const typeParam = type === 0 ? 'anime' : 'film';
            const finalQuery = query || searchQuery;
            const url = finalQuery.trim()
                ? `/api/animes/catalogue?search=${encodeURIComponent(finalQuery)}&page=${page}&type=${typeParam}`
                : `/api/animes/catalogue?page=${page}&type=${typeParam}`;

            console.log(`📡 Fetching: ${url}`);
            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`Erreur API: ${response.status}`);
            }

            const data = await response.json();
            if (data.success && data.data.items) {
                setResults(data.data.items);
                setHasSearched(true);
                const pages = data.data.totalPages || page;
                setTotalPages(Math.max(1, pages));
                onSearch?.(finalQuery, page);
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
    }, [searchQuery, contentType, onSearch]);

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

    // Count items by type from results
    const animeCount = results.length; // Since we filter at backend now
    const filmCount = results.length; // Since we filter at backend now

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

            {/* Content Type Tabs */}
            {hasSearched && (
                <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 4 }} className="dark:border-gray-700">
                    <Tabs 
                        value={contentType} 
                        onChange={(e, newValue) => {
                            setContentType(newValue);
                            setCurrentPage(1);
                            loadCatalog('', 1, newValue);
                        }}
                        sx={{
                            '& .MuiTab-root': {
                                color: 'inherit',
                                '&.Mui-selected': {
                                    color: '#2563eb',
                                }
                            },
                            '& .MuiTabs-indicator': {
                                backgroundColor: '#2563eb',
                            }
                        }}
                    >
                        <Tab 
                            label="Animes" 
                            value={0}
                            sx={{ fontSize: '1rem', fontWeight: 500 }}
                        />
                        <Tab 
                            label="Films" 
                            value={1}
                            sx={{ fontSize: '1rem', fontWeight: 500 }}
                        />
                    </Tabs>
                </Box>
            )}

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
                            <CatalogAnimeCard
                                key={item.id}
                                item={item}
                                isInToWatch={toWatchTitles.includes(item.title)}
                                isViewed={viewedIds.includes(item.id)}
                                onAddToWatch={onAddToWatch}
                                onRemoveFromToWatch={onRemoveFromToWatch}
                                onSelectAnime={onSelectAnime}
                            />
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
                <div className="text-center py-16 bg-gradient-to-b from-gray-100 to-gray-50 dark:from-gray-800 dark:to-gray-900 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-600">
                    <div className="text-5xl mb-4">
                        {contentType === 0 ? '🎬' : '🎥'}
                    </div>
                    <p className="text-lg font-semibold text-gray-700 dark:text-gray-300 mb-2">
                        Fin du catalogue {contentType === 0 ? 'Animes' : 'Films'}
                    </p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                        Vous avez atteint la fin des {contentType === 0 ? 'animes' : 'films'} disponibles. 
                        {contentType === 0 ? (
                            <> Essayez l'onglet Films ! </>
                        ) : (
                            <> Essayez l'onglet Animes ! </>
                        )}
                    </p>
                </div>
            )}
        </div>
    );
};
