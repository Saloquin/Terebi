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

            // Try to find an img tag near the h2 (within the same <a>)
            const contextEnd = Math.min(html.length, h2StartPos + 500);
            const contextStart = Math.max(0, h2StartPos - 2000);
            const context = html.substring(contextStart, contextEnd);

            const imgMatch = context.match(/<img[^>]*src="([^"]+)"/);
            const image = imgMatch?.[1];

            const relativeUrl = href.startsWith('http')
                ? (new URL(href).pathname + (new URL(href).search || ''))
                : (href.startsWith('/') ? href.substring(1) : href);

            items.push({
                id: relativeUrl.toLowerCase().replace(/[^a-z0-9]/g, '-') || `catalog-${items.length + 1}`,
                title,
                image,
                url: relativeUrl,
                fullUrl: normalizedHref,
            });
        }

        return items;
    }
}

export const parserService = new ParserService();
