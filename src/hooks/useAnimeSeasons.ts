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
        if (!slug) return;

        const fetchSeasons = async () => {
            setLoading(true);
            setError(null);
            try {
                const response = await fetch(`/api/animes/seasons/${slug}`);
                if (!response.ok) throw new Error('Failed to fetch seasons');
                const json = await response.json();
                if (json.success) {
                    setData(json.data);
                } else {
                    setError(json.error || 'Unknown error');
                }
            } catch (err) {
                setError(err instanceof Error ? err.message : 'Unknown error');
            } finally {
                setLoading(false);
            }
        };

        fetchSeasons();
    }, [slug]);

    return { data, loading, error };
};
