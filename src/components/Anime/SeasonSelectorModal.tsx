import React, { useState, useEffect } from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    FormControlLabel,
    Checkbox,
    Box,
    Typography,
    CircularProgress,
} from '@mui/material';
import { AnimePlanning } from '../../types/anime.types';
import { useAnimeSeasons } from '../../hooks/useAnimeSeasons';

interface Season {
    name: string;
    url: string;
    type: 'regular' | 'oav' | 'special' | 'film';
}

interface SeasonSelectorModalProps {
    open: boolean;
    anime: AnimePlanning | null;
    onClose: () => void;
    onConfirm: (viewedSeasons: string[]) => void;
    loading?: boolean;
}

export const SeasonSelectorModal: React.FC<SeasonSelectorModalProps> = ({
    open,
    anime,
    onClose,
    onConfirm,
    loading = false,
}) => {
    const [selectedSeasons, setSelectedSeasons] = useState<Set<string>>(new Set());
    const { data, loading: seasonsLoading } = useAnimeSeasons(anime?.fullUrl || '');
    const seasons: Season[] = data?.seasons || [];

    useEffect(() => {
        if (open) {
            setSelectedSeasons(new Set());
        }
    }, [open, anime]);

    const handleSeasonToggle = (seasonName: string) => {
        const newSelected = new Set(selectedSeasons);
        if (newSelected.has(seasonName)) {
            newSelected.delete(seasonName);
        } else {
            newSelected.add(seasonName);
        }
        setSelectedSeasons(newSelected);
    };

    const handleSelectAll = () => {
        if (selectedSeasons.size === seasons.length) {
            setSelectedSeasons(new Set());
        } else {
            setSelectedSeasons(new Set(seasons.map((s: Season) => s.name)));
        }
    };

    const handleConfirm = () => {
        onConfirm(Array.from(selectedSeasons));
    };

    if (!anime) return null;

    return (
        <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
            <DialogTitle>Sélectionner les saisons regardées</DialogTitle>
            <DialogContent>
                <Box sx={{ mt: 2 }}>
                    <Typography variant="subtitle2" sx={{ mb: 2, fontWeight: 600 }}>
                        {anime.title}
                    </Typography>

                    {seasonsLoading ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', py: 3 }}>
                            <CircularProgress />
                        </Box>
                    ) : seasons.length === 0 ? (
                        <Typography color="textSecondary" sx={{ py: 2 }}>
                            Aucune saison trouvée pour cet anime
                        </Typography>
                    ) : (
                        <>
                            {/* Select All button */}
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={selectedSeasons.size === seasons.length}
                                        indeterminate={
                                            selectedSeasons.size > 0 && selectedSeasons.size < seasons.length
                                        }
                                        onChange={handleSelectAll}
                                    />
                                }
                                label={
                                    <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                                        Toutes les saisons
                                    </Typography>
                                }
                                sx={{ mb: 2 }}
                            />

                            {/* Season list */}
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                                {seasons.map((season: Season) => (
                                    <FormControlLabel
                                        key={season.name}
                                        control={
                                            <Checkbox
                                                checked={selectedSeasons.has(season.name)}
                                                onChange={() => handleSeasonToggle(season.name)}
                                            />
                                        }
                                        label={
                                            <Box>
                                                <Typography variant="body2">
                                                    {season.name}
                                                </Typography>
                                                <Typography variant="caption" color="textSecondary">
                                                    Type: {season.type}
                                                </Typography>
                                            </Box>
                                        }
                                    />
                                ))}
                            </Box>

                            {/* Summary */}
                            <Typography
                                variant="caption"
                                sx={{ display: 'block', mt: 3, color: 'textSecondary' }}
                            >
                                {selectedSeasons.size} saison{selectedSeasons.size > 1 ? 's' : ''} sélectionnée
                                {selectedSeasons.size > 1 ? 's' : ''}
                            </Typography>
                        </>
                    )}
                </Box>
            </DialogContent>
            <DialogActions>
                <Button onClick={onClose} disabled={loading}>
                    Annuler
                </Button>
                <Button
                    onClick={handleConfirm}
                    variant="contained"
                    color="success"
                    disabled={loading || seasons.length === 0}
                >
                    Marquer comme vu
                </Button>
            </DialogActions>
        </Dialog>
    );
};
