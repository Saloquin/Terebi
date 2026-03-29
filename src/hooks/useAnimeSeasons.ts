import { useState, useEffect } from 'react';

interface Season {
    name: string;
    url: string;
    type: 'regular' | 'oav' | 'special' | 'film';
}

interface AnimeSeasons {
    title: string;
    slug: string;
    seasons: Season[];
    totalSeasons: number;
}

export const useAnimeSeasons = (slug: string | null) => {
    const [data, setData] = useState<AnimeSeasons | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        console.log(`📺 useAnimeSeasons called with slug: "${slug}"`);
        if (!slug) {
            console.log('📺 Slug is empty, returning early');
            return;
        }

        const fetchSeasons = async () => {
            setLoading(true);
            setError(null);
            try {
                const url = `/api/animes/seasons/${slug}`;
                console.log(`📺 Fetching seasons from: ${url}`);
                const response = await fetch(url);
                if (!response.ok) throw new Error('Failed to fetch seasons');
                const json = await response.json();
                console.log(`📺 Response received:`, json);
                if (json.success) {
                    console.log(`📺 Setting data:`, json.data);
                    setData(json.data);
                } else {
                    setError(json.error || 'Unknown error');
                }
            } catch (err) {
                const errorMsg = err instanceof Error ? err.message : 'Unknown error';
                console.log(`📺 Error fetching seasons:`, errorMsg);
                setError(errorMsg);
            } finally {
                setLoading(false);
            }
        };

        fetchSeasons();
    }, [slug]);

    return { data, loading, error };
};
