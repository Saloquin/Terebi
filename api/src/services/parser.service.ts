import { parse, HTMLElement } from 'node-html-parser';
import { AnimePlanning, CatalogAnime } from '../types/anime.types';

export class ParserService {
    private getBaseUrlFromSource(sourceUrl: string): string {
        try {
            return new URL(sourceUrl).origin;
        } catch {
            return sourceUrl;
        }
    }

    private isValidAnimeEntry(title: string, language: string): boolean {
        if (!title || title.trim().length === 0) return false;
        if (language === 'VF') return false;

        const normalizedName = title.trim().toLowerCase();
        const hasReasonableLength = normalizedName.length >= 2;
        const hasLetter = /[a-zA-Zà-ÿ]/.test(normalizedName);

        return hasReasonableLength && hasLetter;
    }

    parsePlanningFromSource(html: string, sourceUrl: string): AnimePlanning[] {
        const baseUrl = this.getBaseUrlFromSource(sourceUrl);
        const root = parse(html);
        const animes: AnimePlanning[] = [];

        const dayIds = ['0', '1', '2', '3', '4', '5', '6'];
        const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

        dayIds.forEach((dayId, dayIndex) => {
            const daySection = root.querySelector(`[id="${dayId}"]`);
            if (!daySection) return;

            let dayTitle = dayNames[dayIndex];
            const titleElement = daySection.querySelector('.titreJours');
            if (titleElement) {
                const text = titleElement.text.trim();
                const dayMatch = text.match(/Sorties du (\w+)/i);
                if (dayMatch) dayTitle = dayMatch[1];
            }

            const animeCards = daySection.querySelectorAll('.anime-card-premium, .scan-card-premium');
            animeCards.forEach((card: HTMLElement) => {
                const anchor = card.querySelector('a');
                if (!anchor) return;

                const url = anchor.getAttribute('href') || '';
                const title = card.querySelector('.card-title')?.text.trim() || '';
                const imageUrl = card.querySelector('.card-image')?.getAttribute('src') || '';

                const isAnime = card.classNames.includes('anime-card-premium');
                const contentType = isAnime ? 'Anime' : 'Scan';

                const flagImg = card.querySelector('.flag-icon');
                let language = 'VOSTFR';
                if (flagImg) {
                    const flagSrc = flagImg.getAttribute('src') || '';
                    if (flagSrc.includes('flag_fr.png')) language = 'VF';
                }

                let time = '';
                let seasonInfo = '';
                const timeElements = card.querySelectorAll('.info-text');
                timeElements.forEach((elem: HTMLElement) => {
                    const text = elem.text.trim();
                    if (text.match(/^\d+h\d+$/) || text === '?') time = text;
                    if (text.startsWith('Saison ')) seasonInfo = text;
                });

                if (!this.isValidAnimeEntry(title, language)) return;

                const stableId = `${dayTitle.toLowerCase()}-${title.toLowerCase().replace(/[^a-z0-9]/g, '')}-${time || 'no-time'}-${language}`;
                const type = contentType === 'Scan'
                    ? (language === 'VF' ? 'ScanVF' : 'Scan')
                    : (language as 'VOSTFR' | 'VF');

                animes.push({
                    id: stableId,
                    title,
                    image: imageUrl || 'https://via.placeholder.com/300x400?text=No+Image',
                    imageUrl: imageUrl || undefined,
                    dayOfWeek: dayTitle,
                    time: time || undefined,
                    type,
                    season: seasonInfo || undefined,
                    status: `${contentType} ${language}${seasonInfo ? ` - ${seasonInfo}` : ''}`,
                    url: url.startsWith('/') ? url.substring(1) : url,
                    fullUrl: url ? `${baseUrl}${url}` : undefined,
                });
            });
        });

        return animes;
    }

    parseCatalogFromSource(html: string, sourceUrl: string): CatalogAnime[] {
        const baseUrl = this.getBaseUrlFromSource(sourceUrl);
        const seenUrls = new Set<string>();
        const items: CatalogAnime[] = [];
        const typeStats = { anime: 0, film: 0, other: 0 };

        // Pure regex approach: match <h2 class="card-title">Title</h2> preceded by <a href="...">
        // We look backwards from each h2 to find its containing <a> tag
        const h2Matches = Array.from(html.matchAll(/<h2\s+class="card-title">([^<]+)<\/h2>/g));

        for (const h2Match of h2Matches) {
            const title = h2Match[1].trim();
            if (!title || title.length < 2) continue;

            // Find the closest preceding <a href="..."> tag
            const h2StartPos = h2Match.index || 0;
            const precedingHtml = html.substring(Math.max(0, h2StartPos - 1000), h2StartPos);
            const aMatch = precedingHtml.match(/<a\s+[^>]*href="([^"]+)"[^>]*>(?!.*<a)[^]*$/);

            if (!aMatch) continue;

            const href = aMatch[1];
            if (!href || href.startsWith('#') || href.startsWith('javascript:')) continue;

            const normalizedHref = href.startsWith('http') ? href : `${baseUrl}${href.startsWith('/') ? href : `/${href}`}`;
            if (seenUrls.has(normalizedHref)) continue;
            seenUrls.add(normalizedHref);

            // Extract info from the card context
            const contextEnd = Math.min(html.length, h2StartPos + 1500);
            const contextStart = Math.max(0, h2StartPos - 1000);
            const context = html.substring(contextStart, contextEnd);

            // Image
            const imgMatch = context.match(/<img[^>]*src="([^"]+)"/);
            const image = imgMatch?.[1];

            // Genres - look for "Genres" followed by list
            const genresMatch = context.match(/Genres[\s\S]*?<p[^>]*>([^<]+)<\/p>/);
            const genres = genresMatch?.[1]
                ?.split(/,/)
                .map(g => g.trim())
                .filter(g => g.length > 0)
                .slice(0, 5) || [];

            // Year - look for a 4-digit year
            const yearMatch = context.match(/\b(19|20)\d{2}\b/);
            const year = yearMatch?.[0];

            // Score - look for "★" or rating pattern
            const scoreMatch = context.match(/★\s*([\d.]+)/);
            const score = scoreMatch ? parseFloat(scoreMatch[1]) : undefined;

            // Status - look for "En cours", "Fini", "Annulé"
            let status: string | undefined;
            if (context.includes('En cours')) status = 'En cours';
            else if (context.includes('Fini')) status = 'Fini';
            else if (context.includes('Annulé')) status = 'Annulé';

            // Type - detect based on URL path if available, or context
            let type: string | undefined;
            const hrefLower = href.toLowerCase();
            const contextLower = context.toLowerCase();
            
            // Primary: Check URL for anime or film indicators
            if (hrefLower.includes('/anime/')) {
                type = 'Anime';
            } else if (hrefLower.includes('/film/')) {
                type = 'Film';
            } else {
                // Secondary: Check context, but be very strict
                // Only mark as Film if we find very specific patterns
                if (context.match(/\[Film\]|\(Film\)|Type:.*Film|Type.*:.*Film|categor.*Film/i) ||
                    contextLower.match(/^film\s|film$/)) {
                    type = 'Film';
                } else {
                    // Default to Anime
                    type = 'Anime';
                }
            }
            
            if (type === 'Film') {
                typeStats.film++;
            } else {
                typeStats.anime++;
            }

            const relativeUrl = href.startsWith('http')
                ? (new URL(href).pathname + (new URL(href).search || ''))
                : (href.startsWith('/') ? href.substring(1) : href);

            items.push({
                id: relativeUrl.toLowerCase().replace(/[^a-z0-9]/g, '-') || `catalog-${items.length + 1}`,
                title,
                image,
                url: relativeUrl,
                fullUrl: normalizedHref,
                genres: genres.length > 0 ? genres : undefined,
                year,
                score,
                status,
                type,
            });
        }

        console.log(`📝 Parser Stats: Anime=${typeStats.anime}, Film=${typeStats.film}, Other=${typeStats.other}`);
        
        // Log items detected as Film for debugging
        const detectedFilms = items.filter(i => i.type === 'Film');
        if (detectedFilms.length > 0 && detectedFilms.length <= 10) {
            console.log(`📽️  Films detected: ${detectedFilms.map(f => f.title).join(', ')}`);
        }
        
        return items;
    }
}

export const parserService = new ParserService();
