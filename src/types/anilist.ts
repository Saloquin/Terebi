export type AniListSeason = 'WINTER' | 'SPRING' | 'SUMMER' | 'FALL';

export interface AniListMedia {
  id: number;
  title: { romaji?: string; english?: string; native?: string };
  coverImage?: { large?: string; medium?: string };
  bannerImage?: string;
  description?: string;
  format?: string;
  status?: string;
  episodes?: number;
  duration?: number;
  season?: AniListSeason;
  seasonYear?: number;
  genres?: string[];
  averageScore?: number;
  startDate?: { year?: number; month?: number; day?: number };
  nextAiringEpisode?: { airingAt: number; episode: number };
  siteUrl?: string;
  studios?: { nodes: Array<{ name: string }> };
}

export interface ApiResponse<T> {
  success: boolean;
  data: T | null;
  error?: string;
  code?: string;
  timestamp: string;
}

export interface SeasonPageData {
  season: AniListSeason;
  year: number;
  page: number;
  perPage: number;
  pageInfo: {
    total?: number;
    currentPage: number;
    lastPage: number;
    hasNextPage: boolean;
  };
  media: AniListMedia[];
}

export interface PlanningPageData {
  season: AniListSeason;
  year: number;
  media: AniListMedia[];
}

export interface SamaResolveResult {
  title: string;
  matchedTitle?: string;
  slug?: string;
  url: string;
  cached: boolean;
}

export type MediaListStatus =
  | 'CURRENT'
  | 'PLANNING'
  | 'COMPLETED'
  | 'PAUSED'
  | 'DROPPED'
  | 'REPEATING';

export interface MediaListEntry {
  id: number;
  mediaId: number;
  status: MediaListStatus;
  progress: number;
  updatedAt: number;
  media?: AniListMedia;
}

export const SEASON_LABELS: Record<AniListSeason, string> = {
  WINTER: 'Hiver',
  SPRING: 'Printemps',
  SUMMER: 'Été',
  FALL: 'Automne',
};

export function displayTitle(media: AniListMedia): string {
  return media.title.romaji || media.title.english || media.title.native || 'Sans titre';
}

export function prevSeason(season: AniListSeason, year: number): { season: AniListSeason; year: number } {
  const order: AniListSeason[] = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];
  const idx = order.indexOf(season);
  if (idx <= 0) return { season: 'FALL', year: year - 1 };
  return { season: order[idx - 1], year };
}

export function nextSeason(season: AniListSeason, year: number): { season: AniListSeason; year: number } {
  const order: AniListSeason[] = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];
  const idx = order.indexOf(season);
  if (idx >= order.length - 1) return { season: 'WINTER', year: year + 1 };
  return { season: order[idx + 1], year };
}

export function stripHtml(html?: string): string {
  if (!html) return '';
  return html.replace(/<[^>]+>/g, '').replace(/&[^;]+;/g, ' ').trim();
}

export const FRENCH_WEEKDAYS = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
] as const;

export const FRENCH_WEEKDAYS_SHORT = [
  'Lun',
  'Mar',
  'Mer',
  'Jeu',
  'Ven',
  'Sam',
  'Dim',
] as const;

export const PLANNING_TIMEZONE = 'Europe/Paris';

export function weekdayIndex(date: Date, timeZone = PLANNING_TIMEZONE): number {
  const weekday = new Intl.DateTimeFormat('en-US', { timeZone, weekday: 'short' }).format(date);
  const map: Record<string, number> = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };
  return map[weekday] ?? 0;
}

export function formatAiringTime(airingAt: number, timeZone = PLANNING_TIMEZONE): string {
  return new Date(airingAt * 1000).toLocaleTimeString('fr-FR', {
    hour: '2-digit',
    minute: '2-digit',
    timeZone,
  });
}

export interface ScheduledAnime {
  media: AniListMedia;
  airingAt: number;
  time: string;
  episode: number;
}

export interface WeekdayGroup {
  day: string;
  dayShort: string;
  dayIndex: number;
  items: ScheduledAnime[];
}

export function groupMediaByWeekday(media: AniListMedia[]): {
  scheduled: WeekdayGroup[];
  unscheduled: AniListMedia[];
} {
  const groups = new Map<number, WeekdayGroup>();
  const unscheduled: AniListMedia[] = [];

  for (const m of media) {
    const next = m.nextAiringEpisode;
    if (next?.airingAt) {
      const date = new Date(next.airingAt * 1000);
      const dayIndex = weekdayIndex(date);
      if (!groups.has(dayIndex)) {
        groups.set(dayIndex, {
          day: FRENCH_WEEKDAYS[dayIndex],
          dayShort: FRENCH_WEEKDAYS_SHORT[dayIndex],
          dayIndex,
          items: [],
        });
      }
      groups.get(dayIndex)!.items.push({
        media: m,
        airingAt: next.airingAt,
        time: formatAiringTime(next.airingAt),
        episode: next.episode,
      });
    } else {
      unscheduled.push(m);
    }
  }

  const scheduled = FRENCH_WEEKDAYS.map((day, dayIndex) => {
    const group = groups.get(dayIndex);
    return {
      day,
      dayShort: FRENCH_WEEKDAYS_SHORT[dayIndex],
      dayIndex,
      items: group?.items.sort((a, b) => a.airingAt - b.airingAt) ?? [],
    };
  });

  return { scheduled, unscheduled };
}
