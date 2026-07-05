import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { ExternalLink, Play } from 'lucide-react';
import { ApiError, api } from '../api/client';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import type { AniListMedia } from '../types/anilist';
import { displayTitle, stripHtml } from '../types/anilist';

export default function AnimeDetailPage() {
  const { anilistId } = useParams();
  const id = parseInt(anilistId || '', 10);

  const [media, setMedia] = useState<AniListMedia | null>(null);
  const [inToWatch, setInToWatch] = useState(false);
  const [inViewed, setInViewed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [authError, setAuthError] = useState(false);
  const [samaLoading, setSamaLoading] = useState<'watch' | 'catalog' | null>(null);
  const [samaError, setSamaError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!Number.isFinite(id)) {
      setError('ID invalide');
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    setAuthError(false);
    try {
      const [anime, towatch, viewed] = await Promise.all([
        api.getAnime(id),
        api.getToWatch(),
        api.getViewed(),
      ]);
      setMedia(anime);
      setInToWatch(towatch.some(e => e.anilistId === id));
      setInViewed(viewed.some(e => e.anilistId === id));
    } catch (e) {
      if (e instanceof ApiError && e.isAnilistAuth) {
        setAuthError(true);
      }
      setError(e instanceof Error ? e.message : 'Erreur de chargement');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  const openSama = async (mode: 'watch' | 'catalog') => {
    if (!media) return;
    setSamaLoading(mode);
    setSamaError(null);
    try {
      const title = displayTitle(media);
      const seasonNum =
        media.season && media.seasonYear
          ? 1
          : 1;
      const result =
        mode === 'watch'
          ? await api.resolveSama(title, seasonNum)
          : await api.resolveSama(title);
      window.open(result.url, '_blank', 'noopener,noreferrer');
    } catch (e) {
      setSamaError(e instanceof Error ? e.message : 'Résolution anime-sama échouée');
    } finally {
      setSamaLoading(null);
    }
  };

  const toggleToWatch = async () => {
    try {
      if (inToWatch) await api.removeFromWatch(id);
      else await api.addToWatch(id);
      setInToWatch(!inToWatch);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur');
    }
  };

  const toggleViewed = async () => {
    try {
      if (inViewed) await api.removeViewed(id);
      else await api.addViewed(id);
      setInViewed(!inViewed);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur');
    }
  };

  if (loading) return <LoadingSpinner />;
  if (error || !media) {
    return (
      <ErrorMessage
        message={error || 'Anime introuvable'}
        onRetry={load}
        showSettingsLink={authError}
      />
    );
  }

  const title = displayTitle(media);
  const banner = media.bannerImage || media.coverImage?.large;
  const description = stripHtml(media.description);

  return (
    <div className="space-y-6">
      {banner && (
        <div className="relative h-48 md:h-64 rounded-xl overflow-hidden">
          <img src={banner} alt="" className="w-full h-full object-cover opacity-60" />
          <div className="absolute inset-0 bg-gradient-to-t from-surface to-transparent" />
        </div>
      )}

      <div className="flex flex-col md:flex-row gap-6">
        {media.coverImage?.large && (
          <img
            src={media.coverImage.large}
            alt={title}
            className="w-40 rounded-xl shadow-lg shrink-0 -mt-16 md:-mt-24 relative z-10"
          />
        )}
        <div className="flex-1 space-y-4">
          <div>
            <h1 className="text-3xl font-bold">{title}</h1>
            {media.title.english && media.title.english !== title && (
              <p className="text-gray-400">{media.title.english}</p>
            )}
          </div>

          <div className="flex flex-wrap gap-2 text-sm">
            {media.format && (
              <span className="px-2 py-0.5 rounded bg-surface-raised border border-surface-border">
                {media.format}
              </span>
            )}
            {media.status && (
              <span className="px-2 py-0.5 rounded bg-surface-raised border border-surface-border">
                {media.status}
              </span>
            )}
            {media.averageScore != null && (
              <span className="px-2 py-0.5 rounded bg-surface-raised border border-surface-border">
                {media.averageScore / 10}/10
              </span>
            )}
            {media.episodes != null && (
              <span className="px-2 py-0.5 rounded bg-surface-raised border border-surface-border">
                {media.episodes} ép.
              </span>
            )}
          </div>

          {media.genres && (
            <p className="text-sm text-gray-400">{media.genres.join(' · ')}</p>
          )}

          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => openSama('watch')}
              disabled={samaLoading !== null}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-accent hover:bg-accent-hover text-white font-medium disabled:opacity-50"
            >
              <Play className="w-4 h-4" aria-hidden />
              {samaLoading === 'watch' ? 'Résolution…' : 'Regarder'}
            </button>
            <button
              type="button"
              onClick={() => openSama('catalog')}
              disabled={samaLoading !== null}
              className="px-4 py-2 rounded-lg border border-surface-border hover:bg-surface-raised disabled:opacity-50"
            >
              {samaLoading === 'catalog' ? 'Résolution…' : 'Fiche anime-sama'}
            </button>
            <button
              type="button"
              onClick={toggleToWatch}
              className={`px-4 py-2 rounded-lg border ${
                inToWatch
                  ? 'border-accent text-accent'
                  : 'border-surface-border hover:bg-surface-raised'
              }`}
            >
              {inToWatch ? 'Retirer de la liste' : 'À regarder'}
            </button>
            <button
              type="button"
              onClick={toggleViewed}
              className={`px-4 py-2 rounded-lg border ${
                inViewed
                  ? 'border-green-500 text-green-400'
                  : 'border-surface-border hover:bg-surface-raised'
              }`}
            >
              {inViewed ? 'Marqué vu' : 'Marquer vu'}
            </button>
            {media.siteUrl && (
              <a
                href={media.siteUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-surface-border hover:bg-surface-raised"
              >
                <ExternalLink className="w-4 h-4" aria-hidden />
                AniList
              </a>
            )}
          </div>

          {samaError && <ErrorMessage message={samaError} />}
        </div>
      </div>

      {description && (
        <div className="prose prose-invert max-w-none">
          <h2 className="text-lg font-semibold mb-2">Synopsis</h2>
          <p className="text-gray-300 text-sm leading-relaxed whitespace-pre-line">
            {description.length > 800 ? `${description.slice(0, 800)}…` : description}
          </p>
        </div>
      )}
    </div>
  );
}
