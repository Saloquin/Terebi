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

export interface SamaResolveResult {
  title: string;
  matchedTitle?: string;
  slug?: string;
  url: string;
  cached: boolean;
}

export interface UserListEntry {
  anilistId: number;
  addedAt: string;
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
