import { parse, HTMLElement } from 'node-html-parser';
import puppeteer from 'puppeteer-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';
import * as fs from 'fs';
import { AnimePlanning } from '../types/anime.types';

puppeteer.use(StealthPlugin());

class AnimeScraperService {
    private baseUrl: string;
    private cache: AnimePlanning[] | null = null;
    private cacheTimestamp: Date | null = null;
    private cacheDuration = 10 * 60 * 1000; // 10 minutes

    constructor() {
        this.baseUrl = process.env.ANIME_BASE_URL || 'https://anime-sama.one';
    }

    private isCacheValid(): boolean {
        if (!this.cache || !this.cacheTimestamp) return false;
        return Date.now() - this.cacheTimestamp.getTime() < this.cacheDuration;
    }

    private isValidAnimeEntry(nom: string, type: string): boolean {
        if (!nom || nom.trim().length === 0) return false;
        if (type === 'VF') return false;
        
        const normalizedName = nom.trim().toLowerCase();
        const hasReasonableLength = normalizedName.length >= 2;
        const hasLetter = /[a-zA-Zà-ÿ]/.test(normalizedName);
        
        return hasReasonableLength && hasLetter;
    }

    async fetchPlanning(): Promise<AnimePlanning[]> {
        // Vérifier le cache
        if (this.isCacheValid() && this.cache) {
            console.log('📦 Utilisation du cache');
            return this.cache;
        }

        console.log('🌐 Récupération via navigateur headless...');
        console.log(`📍 URL: ${this.baseUrl}/planning/`);
        
        let browser;
        try {
            browser = await puppeteer.launch({
                headless: 'new' as any,
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-blink-features=AutomationControlled',
                    '--window-size=1920,1080',
                ],
            });
            const page = await browser.newPage();
            await page.setViewport({ width: 1920, height: 1080 });
            
            // Naviguer vers la page planning
            await page.goto(`${this.baseUrl}/planning/`, {
                waitUntil: 'networkidle2',
                timeout: 60000,
            });

            // Attendre que le contenu de planning soit rendu (JS côté client)
            console.log('⏳ Attente du rendu du contenu...');
            try {
                await page.waitForSelector('.anime-card-premium, .scan-card-premium, [id="0"]', {
                    timeout: 30000,
                });
                console.log('✅ Contenu planning détecté');
            } catch {
                console.log('⚠️ Sélecteurs planning non trouvés, attente supplémentaire...');
                await new Promise(resolve => setTimeout(resolve, 5000));
            }

            const html = await page.content();

            // Sauvegarder le HTML pour debug
            fs.writeFileSync('debug-planning.html', html, 'utf-8');
            console.log('💾 HTML sauvegardé dans debug-planning.html');

            const animes = this.parsePlanning(html);
            
            // Mettre en cache
            this.cache = animes;
            this.cacheTimestamp = new Date();
            
            console.log(`✅ ${animes.length} animes récupérés`);
            return animes;

        } catch (error) {
            console.error('❌ Erreur de scraping:', error);
            throw error;
        } finally {
            if (browser) await browser.close();
        }
    }

    private parsePlanning(html: string): AnimePlanning[] {
        const root = parse(html);
        const animes: AnimePlanning[] = [];
        
        const dayIds = ['0', '1', '2', '3', '4', '5', '6'];
        const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
        
        dayIds.forEach((dayId, dayIndex) => {
            const daySection = root.querySelector(`[id="${dayId}"]`);
            
            if (daySection) {
                let dayTitle = dayNames[dayIndex];
                const titleElement = daySection.querySelector('.titreJours');
                if (titleElement) {
                    const text = titleElement.text.trim();
                    const dayMatch = text.match(/Sorties du (\w+)/i);
                    if (dayMatch) {
                        dayTitle = dayMatch[1];
                    }
                }
                
                const animeCards = daySection.querySelectorAll('.anime-card-premium, .scan-card-premium');
                
                animeCards.forEach((card: HTMLElement) => {
                    const anchor = card.querySelector('a');
                    if (!anchor) return;
                    
                    const url = anchor.getAttribute('href') || '';
                    const title = card.querySelector('.card-title')?.text.trim() || '';
                    const imageElement = card.querySelector('.card-image');
                    const imageUrl = imageElement?.getAttribute('src') || '';
                    
                    const isAnime = card.classNames.includes('anime-card-premium');
                    const contentType = isAnime ? 'Anime' : 'Scan';
                    
                    // Détecter la langue
                    const flagImg = card.querySelector('.flag-icon');
                    let language = 'VOSTFR';
                    if (flagImg) {
                        const flagSrc = flagImg.getAttribute('src') || '';
                        if (flagSrc.includes('flag_fr.png')) {
                            language = 'VF';
                        }
                    }
                    
                    // Récupérer l'heure
                    let time = '';
                    const timeElements = card.querySelectorAll('.info-text');
                    timeElements.forEach((elem: HTMLElement) => {
                        const text = elem.text.trim();
                        if (text.match(/^\d+h\d+$/) || text === '?') {
                            time = text;
                        }
                    });
                    
                    // Récupérer la saison
                    let seasonInfo = '';
                    timeElements.forEach((elem: HTMLElement) => {
                        const text = elem.text.trim();
                        if (text.startsWith('Saison ')) {
                            seasonInfo = text;
                        }
                    });
                    
                    if (this.isValidAnimeEntry(title, language)) {
                        const stableId = `${dayTitle.toLowerCase()}-${title.toLowerCase().replace(/[^a-z0-9]/g, '')}-${time || 'no-time'}-${language}`;
                        
                        // Déterminer le type final
                        let type: 'VOSTFR' | 'VF' | 'Scan' | 'ScanVF';
                        if (contentType === 'Scan') {
                            type = language === 'VF' ? 'ScanVF' : 'Scan';
                        } else {
                            type = language as 'VOSTFR' | 'VF';
                        }
                        
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
                            fullUrl: url ? `${this.baseUrl}${url}` : undefined
                        });
                    }
                });
            }
        });
        
        return animes;
    }

    getAnimesByDay(day: string): AnimePlanning[] {
        if (!this.cache) return [];
        return this.cache.filter(
            anime => anime.dayOfWeek.toLowerCase() === day.toLowerCase()
        );
    }

    getTodayAnimes(): AnimePlanning[] {
        const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
        const today = dayNames[new Date().getDay()];
        return this.getAnimesByDay(today);
    }

    clearCache(): void {
        this.cache = null;
        this.cacheTimestamp = null;
        console.log('🗑️ Cache vidé');
    }
}

export const animeScraperService = new AnimeScraperService();
