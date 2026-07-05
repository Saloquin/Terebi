import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Calendar, ChevronLeft, ChevronRight } from 'lucide-react';
import { ApiError, api } from '../api/client';
import AnimeCard from '../components/AnimeCard';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import type { AniListMedia, AniListSeason } from '../types/anilist';
import {
  SEASON_LABELS,
  groupMediaByWeekday,
  nextSeason,
  prevSeason,
} from '../types/anilist';

export default function PlanningPage() {
  const { year: yearParam, season: seasonParam } = useParams();
  const navigate = useNavigate();

  const [season, setSeason] = useState<AniListSeason>('WINTER');
  const [year, setYear] = useState(new Date().getFullYear());
  const [media, setMedia] = useState<AniListMedia[]>([]);
  const [hiddenIds, setHiddenIds] = useState<Set<number>>(new Set());
  const [showHidden, setShowHidden] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [authError, setAuthError] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    setAuthError(false);
    try {
      let s: AniListSeason;
      let y: number;

      if (yearParam && seasonParam) {
        s = seasonParam.toUpperCase() as AniListSeason;
        y = parseInt(yearParam, 10);
      } else {
        const current = await api.getCurrentSeason();
        s = current.season as AniListSeason;
        y = current.year;
      }

      setSeason(s);
      setYear(y);

      const [seasonData, hidden] = await Promise.all([
        api.getSeason(s, y),
        api.getHidden(),
      ]);
      setMedia(seasonData.media);
      setHiddenIds(new Set(hidden));
    } catch (e) {
      if (e instanceof ApiError && e.isAnilistAuth) {
        setAuthError(true);
      }
      setError(e instanceof Error ? e.message : 'Erreur de chargement');
    } finally {
      setLoading(false);
    }
  }, [seasonParam, yearParam]);

  useEffect(() => {
    load();
  }, [load]);

  const toggleHidden = async (id: number) => {
    try {
      const updated = hiddenIds.has(id)
        ? await api.unhideAnime(id)
        : await api.hideAnime(id);
      setHiddenIds(new Set(updated));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur');
    }
  };

  const filtered = media.filter(m => showHidden || !hiddenIds.has(m.id));
  const { scheduled, unscheduled } = groupMediaByWeekday(filtered);
  const prev = prevSeason(season, year);
  const next = nextSeason(season, year);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <Calendar className="w-6 h-6 text-accent" aria-hidden />
            {SEASON_LABELS[season]} {year}
          </h1>
          <p className="text-sm text-gray-400 mt-1">
            Saison de diffusion · {filtered.length} anime{filtered.length !== 1 ? 's' : ''}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Link
            to={`/planning/${prev.year}/${prev.season}`}
            className="inline-flex items-center gap-1 px-3 py-1.5 text-sm rounded-lg border border-surface-border hover:bg-surface-raised"
          >
            <ChevronLeft className="w-4 h-4" aria-hidden />
            {SEASON_LABELS[prev.season]} {prev.year}
          </Link>
          <button
            type="button"
            onClick={() => navigate('/planning')}
            className="px-3 py-1.5 text-sm rounded-lg border border-accent text-accent hover:bg-accent/10"
          >
            Saison actuelle
          </button>
          <Link
            to={`/planning/${next.year}/${next.season}`}
            className="inline-flex items-center gap-1 px-3 py-1.5 text-sm rounded-lg border border-surface-border hover:bg-surface-raised"
          >
            {SEASON_LABELS[next.season]} {next.year}
            <ChevronRight className="w-4 h-4" aria-hidden />
          </Link>
        </div>
      </div>

      <label className="flex items-center gap-2 text-sm text-gray-400 cursor-pointer w-fit">
        <input
          type="checkbox"
          checked={showHidden}
          onChange={e => setShowHidden(e.target.checked)}
          className="rounded border-surface-border"
        />
        Afficher les animes masqués ({hiddenIds.size})
      </label>

      {loading && <LoadingSpinner />}
      {error && (
        <ErrorMessage
          message={error}
          onRetry={load}
          showSettingsLink={authError}
        />
      )}

      {!loading && !error && (
        <div className="space-y-10">
          {scheduled.map(group => (
            <section key={group.day}>
              <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-accent" aria-hidden />
                {group.day}
                <span className="text-sm font-normal text-gray-500">
                  ({group.items.length})
                </span>
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                {group.items.map(({ media: m, time, episode }) => (
                  <AnimeCard
                    key={m.id}
                    media={m}
                    hidden={hiddenIds.has(m.id)}
                    onToggleHidden={() => toggleHidden(m.id)}
                    airingTime={time}
                    airingEpisode={episode}
                  />
                ))}
              </div>
            </section>
          ))}

          {unscheduled.length > 0 && (
            <section>
              <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-gray-500" aria-hidden />
                Horaire inconnu
                <span className="text-sm font-normal text-gray-500">
                  ({unscheduled.length})
                </span>
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                {unscheduled.map(m => (
                  <AnimeCard
                    key={m.id}
                    media={m}
                    hidden={hiddenIds.has(m.id)}
                    onToggleHidden={() => toggleHidden(m.id)}
                  />
                ))}
              </div>
            </section>
          )}
        </div>
      )}
    </div>
  );
}
