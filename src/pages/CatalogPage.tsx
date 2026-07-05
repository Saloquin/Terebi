import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import AnimeCard from '../components/AnimeCard';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import type { AniListMedia } from '../types/anilist';

export default function CatalogPage() {
  const [query, setQuery] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [page, setPage] = useState(1);
  const [media, setMedia] = useState<AniListMedia[]>([]);
  const [lastPage, setLastPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const search = useCallback(async (q: string, p: number) => {
    if (!q.trim()) {
      setMedia([]);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const result = await api.search(q, p);
      setMedia(result.media);
      setLastPage(result.pageInfo.lastPage);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur de recherche');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (query) search(query, page);
  }, [query, page, search]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    setQuery(searchInput.trim());
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Catalogue</h1>
        <p className="text-sm text-gray-400 mt-1">Recherche via AniList</p>
      </div>

      <form onSubmit={handleSubmit} className="flex gap-2 max-w-xl">
        <input
          type="search"
          value={searchInput}
          onChange={e => setSearchInput(e.target.value)}
          placeholder="Rechercher un anime…"
          className="flex-1 px-4 py-2 rounded-lg bg-surface-raised border border-surface-border focus:border-accent focus:outline-none"
        />
        <button
          type="submit"
          className="px-4 py-2 rounded-lg bg-accent hover:bg-accent-hover text-white font-medium"
        >
          Rechercher
        </button>
      </form>

      {loading && <LoadingSpinner />}
      {error && <ErrorMessage message={error} onRetry={() => search(query, page)} />}

      {!loading && !error && query && media.length === 0 && (
        <p className="text-gray-400 text-sm">Aucun résultat pour « {query} »</p>
      )}

      {!loading && media.length > 0 && (
        <>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
            {media.map(m => (
              <AnimeCard key={m.id} media={m} />
            ))}
          </div>
          {lastPage > 1 && (
            <div className="flex justify-center gap-2 pt-4">
              <button
                type="button"
                disabled={page <= 1}
                onClick={() => setPage(p => p - 1)}
                className="px-3 py-1.5 text-sm rounded-lg border border-surface-border disabled:opacity-40 hover:bg-surface-raised"
              >
                Précédent
              </button>
              <span className="px-3 py-1.5 text-sm text-gray-400">
                Page {page} / {lastPage}
              </span>
              <button
                type="button"
                disabled={page >= lastPage}
                onClick={() => setPage(p => p + 1)}
                className="px-3 py-1.5 text-sm rounded-lg border border-surface-border disabled:opacity-40 hover:bg-surface-raised"
              >
                Suivant
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
