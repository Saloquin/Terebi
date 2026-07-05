import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Trash2 } from 'lucide-react';
import { ApiError, api } from '../api/client';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import type { AniListMedia, MediaListEntry, MediaListStatus } from '../types/anilist';
import { displayTitle } from '../types/anilist';

interface ListPageProps {
  listType: 'towatch' | 'viewed';
  title: string;
  emptyMessage: string;
}

const LIST_STATUSES: Record<ListPageProps['listType'], MediaListStatus[]> = {
  towatch: ['CURRENT', 'PLANNING'],
  viewed: ['COMPLETED'],
};

export default function UserListPage({ listType, title, emptyMessage }: ListPageProps) {
  const [entries, setEntries] = useState<MediaListEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [authError, setAuthError] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    setAuthError(false);

    try {
      await api.getMe();
      const { entries: list } = await api.getLists(LIST_STATUSES[listType]);
      setEntries(list);
    } catch (e) {
      if (e instanceof ApiError && e.isAnilistAuth) {
        setAuthError(true);
      }
      setError(e instanceof Error ? e.message : 'Erreur de chargement');
    } finally {
      setLoading(false);
    }
  }, [listType]);

  useEffect(() => {
    load();
  }, [load]);

  const remove = async (entry: MediaListEntry) => {
    try {
      await api.removeFromList(entry.mediaId);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur');
    }
  };

  const getMedia = (entry: MediaListEntry): AniListMedia | undefined => entry.media;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">{title}</h1>

      {loading && <LoadingSpinner />}
      {error && (
        <ErrorMessage message={error} onRetry={load} showSettingsLink={authError} />
      )}

      {!loading && !error && entries.length === 0 && (
        <p className="text-gray-400 text-sm">{emptyMessage}</p>
      )}

      {!loading && entries.length > 0 && (
        <ul className="space-y-2">
          {entries.map(entry => {
            const media = getMedia(entry);
            const name = media ? displayTitle(media) : `#${entry.mediaId}`;
            const cover = media?.coverImage?.medium;
            return (
              <li
                key={entry.id}
                className="flex items-center gap-4 p-3 rounded-xl bg-surface-raised border border-surface-border"
              >
                {cover && (
                  <img src={cover} alt="" className="w-12 h-16 object-cover rounded" />
                )}
                <div className="flex-1 min-w-0">
                  <Link
                    to={`/anime/${entry.mediaId}`}
                    className="font-medium hover:text-accent truncate block"
                  >
                    {name}
                  </Link>
                  <p className="text-xs text-gray-500">
                    {entry.status}
                    {entry.progress > 0 && ` · ${entry.progress} ép.`}
                    {' · '}
                    {new Date(entry.updatedAt * 1000).toLocaleDateString('fr-FR')}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => remove(entry)}
                  className="inline-flex items-center gap-1 text-sm text-gray-400 hover:text-red-400 px-2 py-1"
                >
                  <Trash2 className="w-4 h-4" aria-hidden />
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
