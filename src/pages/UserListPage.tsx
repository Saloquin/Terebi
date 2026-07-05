import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import type { AniListMedia } from '../types/anilist';
import { displayTitle } from '../types/anilist';

interface ListPageProps {
  listType: 'towatch' | 'viewed';
  title: string;
  emptyMessage: string;
}

export default function UserListPage({ listType, title, emptyMessage }: ListPageProps) {
  const [entries, setEntries] = useState<Array<{ anilistId: number; addedAt: string }>>([]);
  const [mediaMap, setMediaMap] = useState<Map<number, AniListMedia>>(new Map());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const list =
        listType === 'towatch' ? await api.getToWatch() : await api.getViewed();
      setEntries(list);
      const results = await Promise.allSettled(
        list.map(e => api.getAnime(e.anilistId))
      );
      const map = new Map<number, AniListMedia>();
      results.forEach((r, i) => {
        if (r.status === 'fulfilled') map.set(list[i].anilistId, r.value);
      });
      setMediaMap(map);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur de chargement');
    } finally {
      setLoading(false);
    }
  }, [listType]);

  useEffect(() => {
    load();
  }, [load]);

  const remove = async (id: number) => {
    try {
      if (listType === 'towatch') await api.removeFromWatch(id);
      else await api.removeViewed(id);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur');
    }
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">{title}</h1>

      {loading && <LoadingSpinner />}
      {error && <ErrorMessage message={error} onRetry={load} />}

      {!loading && !error && entries.length === 0 && (
        <p className="text-gray-400 text-sm">{emptyMessage}</p>
      )}

      {!loading && entries.length > 0 && (
        <ul className="space-y-2">
          {entries.map(entry => {
            const media = mediaMap.get(entry.anilistId);
            const name = media ? displayTitle(media) : `#${entry.anilistId}`;
            const cover = media?.coverImage?.medium;
            return (
              <li
                key={entry.anilistId}
                className="flex items-center gap-4 p-3 rounded-xl bg-surface-raised border border-surface-border"
              >
                {cover && (
                  <img src={cover} alt="" className="w-12 h-16 object-cover rounded" />
                )}
                <div className="flex-1 min-w-0">
                  <Link
                    to={`/anime/${entry.anilistId}`}
                    className="font-medium hover:text-accent truncate block"
                  >
                    {name}
                  </Link>
                  <p className="text-xs text-gray-500">
                    Ajouté le {new Date(entry.addedAt).toLocaleDateString('fr-FR')}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => remove(entry.anilistId)}
                  className="text-sm text-gray-400 hover:text-red-400 px-2 py-1"
                >
                  Retirer
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
