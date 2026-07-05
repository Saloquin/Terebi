import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Calendar, ChevronLeft, ChevronRight } from 'lucide-react';
import { api, ApiError } from '../api/client';
import AnimeCard from '../components/AnimeCard';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import { getHiddenIds, hideAnime, unhideAnime } from '../lib/storage';
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
  const [hiddenIds, setHiddenIds] = useState<Set<number>>(() => new Set(getHiddenIds()));
  const [showHidden, setShowHidden] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [rateLimited, setRateLimited] = useState(false);
  const [planningSource, setPlanningSource] = useState<'anilist' | 'jikan' | 'kitsu'>('anilist');

  const load = useCallback(async (signal: AbortSignal) => {
    setLoading(true);
    setError(null);
    setRateLimited(false);
    setPlanningSource('anilist');
    try {
      let s: AniListSeason;
      let y: number;

      if (yearParam && seasonParam) {
        s = seasonParam.toUpperCase() as AniListSeason;
        y = parseInt(yearParam, 10);
      } else {
        const current = await api.getCurrentSeason();
        if (signal.aborted) return;
        s = current.season as AniListSeason;
        y = current.year;
      }

      setSeason(s);
      setYear(y);

      const planningData = await api.getPlanning(s, y, signal);
      if (signal.aborted) return;

      setMedia(planningData.media);
      setPlanningSource(planningData.source ?? 'anilist');
      setHiddenIds(new Set(getHiddenIds()));
    } catch (e) {
      if (signal.aborted) return;
      if (e instanceof ApiError && e.isRateLimit) {
        setRateLimited(true);
      }
      setError(e instanceof Error ? e.message : 'Erreur de chargement');
    } finally {
      if (!signal.aborted) setLoading(false);
    }
  }, [seasonParam, yearParam]);

  useEffect(() => {
    const controller = new AbortController();
    load(controller.signal);
    return () => controller.abort();
  }, [load]);

  const retry = () => {
    const controller = new AbortController();
    load(controller.signal);
  };

  const toggleHidden = (id: number) => {
    const updated = hiddenIds.has(id) ? unhideAnime(id) : hideAnime(id);
    setHiddenIds(new Set(updated));
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
          message={
            rateLimited
              ? `${error} AniList limite à ~30 requêtes/minute — attendez une minute avant de réessayer.`
              : error
          }
          onRetry={retry}
        />
      )}

      {!loading && !error && (
        <>
          {planningSource !== 'anilist' && (
            <div
              role="status"
              className="rounded-lg border border-amber-500/40 bg-amber-500/10 px-4 py-3 text-sm text-amber-100"
            >
              Planning via MyAnimeList (AniList indisponible)
              <span className="ml-2 text-xs text-amber-200/80">
                Source : {planningSource === 'jikan' ? 'MAL/Jikan' : 'Kitsu'}
              </span>
            </div>
          )}
          <div className="overflow-x-auto -mx-4 px-4 pb-2 lg:overflow-visible lg:mx-0 lg:px-0">
            <div className="flex gap-3 min-w-max lg:grid lg:grid-cols-7 lg:min-w-0">
              {scheduled.map(group => (
                <section
                  key={group.dayIndex}
                  className="flex flex-col w-44 shrink-0 lg:w-auto lg:min-w-0"
                >
                  <h2 className="text-sm font-semibold mb-3 text-center sticky top-0 bg-surface py-1 z-10">
                    <span className="lg:hidden">{group.dayShort}</span>
                    <span className="hidden lg:inline">{group.day}</span>
                    {group.items.length > 0 && (
                      <span className="block text-xs font-normal text-gray-500">
                        {group.items.length}
                      </span>
                    )}
                  </h2>
                  <div className="flex flex-col gap-3 flex-1">
                    {group.items.length === 0 ? (
                      <p className="text-xs text-gray-600 text-center py-4">—</p>
                    ) : (
                      group.items.map(({ media: m, time, episode }) => (
                        <AnimeCard
                          key={m.id}
                          media={m}
                          hidden={hiddenIds.has(m.id)}
                          onToggleHidden={() => toggleHidden(m.id)}
                          airingTime={time}
                          airingEpisode={episode}
                          compact
                          externalLink={planningSource !== 'anilist' ? m.siteUrl : undefined}
                        />
                      ))
                    )}
                  </div>
                </section>
              ))}
            </div>
          </div>

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
                    externalLink={planningSource !== 'anilist' ? m.siteUrl : undefined}
                  />
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </div>
  );
}
