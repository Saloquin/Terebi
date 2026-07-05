import React, { useState, useEffect } from 'react';
import { AnimePlanning, AnimeViewed } from '../../types/anime.types';
import { useAnimeSeasons } from '../../hooks/useAnimeSeasons';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    Checkbox,
    FormGroup,
    FormControlLabel,
    Box,
    Typography,
    Chip,
    Divider,
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';

interface AnimeDetailPanelProps {
    anime: AnimePlanning | null;
    onMarkAsViewed: (selectedSeasons: string[]) => void;
    isOpen: boolean;
    onClose: () => void;
}

export const AnimeDetailPanel: React.FC<AnimeDetailPanelProps> = ({
    anime,
    onMarkAsViewed,
    isOpen,
    onClose,
}) => {
    const { data: seasons, loading: loadingSeasons } = useAnimeSeasons(anime?.fullUrl || '');
    const [selectedSeasons, setSelectedSeasons] = useState<string[]>([]);

    useEffect(() => {
        if (anime?.viewedSeasons) {
            setSelectedSeasons(anime.viewedSeasons);
        }
    }, [anime]);

    if (!anime) return null;

    const handleSeasonToggle = (seasonName: string) => {
        setSelectedSeasons(prev =>
            prev.includes(seasonName)
                ? prev.filter(s => s !== seasonName)
                : [...prev, seasonName]
        );
    };

    const handleConfirm = () => {
        onMarkAsViewed(selectedSeasons);
        setSelectedSeasons([]);
        onClose();
    };

    const handleCancel = () => {
        setSelectedSeasons(anime.viewedSeasons || []);
        onClose();
    };

    return (
        <Dialog
            open={isOpen}
            onClose={handleCancel}
            maxWidth="sm"
            fullWidth
            PaperProps={{
                sx: {
                    backgroundColor: 'inherit',
                    backgroundImage: 'inherit',
                }
            }}
        >
            <DialogTitle className="dark:bg-gray-800 dark:text-white">
                Marquer "{anime.title}" comme regardé
            </DialogTitle>

            <Divider className="dark:bg-gray-700" />

            <DialogContent className="dark:bg-gray-800 dark:text-white">
                <Box sx={{ py: 2 }}>
                    <Typography variant="subtitle2" className="dark:text-gray-300 mb-3">
                        Sélectionnez les saisons que vous avez regardées :
                    </Typography>

                    {loadingSeasons && (
                        <Typography className="text-gray-500 dark:text-gray-400">
                            Chargement des saisons...
                        </Typography>
                    )}

                    {!loadingSeasons && seasons?.seasons && seasons.seasons.length > 0 ? (
                        <FormGroup>
                            {seasons.seasons.map((season) => (
                                <FormControlLabel
                                    key={season.name}
                                    control={
                                        <Checkbox
                                            checked={selectedSeasons.includes(season.name)}
                                            onChange={() => handleSeasonToggle(season.name)}
                                            sx={{
                                                color: 'inherit',
                                                '&.Mui-checked': {
                                                    color: '#3b82f6',
                                                },
                                            }}
                                        />
                                    }
                                    label={
                                        <Box className="flex items-center gap-2">
                                            <span>{season.name}</span>
                                            {selectedSeasons.includes(season.name) && (
                                                <CheckCircleIcon sx={{ fontSize: 18, color: '#10b981' }} />
                                            )}
                                        </Box>
                                    }
                                    sx={{
                                        mb: 1,
                                        '& .MuiFormControlLabel-label': {
                                            color: 'inherit',
                                        },
                                    }}
                                />
                            ))}
                        </FormGroup>
                    ) : (
                        <Typography variant="body2" className="text-gray-500 dark:text-gray-400">
                            Impossible de charger les saisons pour cet anime.
                        </Typography>
                    )}

                    {selectedSeasons.length > 0 && (
                        <Box sx={{ mt: 3 }}>
                            <Typography variant="subtitle2" className="dark:text-gray-300 mb-2">
                                Sélectionné ({selectedSeasons.length}) :
                            </Typography>
                            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                                {selectedSeasons.map((season) => (
                                    <Chip
                                        key={season}
                                        label={season}
                                        onDelete={() => handleSeasonToggle(season)}
                                        color="primary"
                                        variant="outlined"
                                        size="small"
                                        sx={{
                                            borderColor: '#3b82f6',
                                            color: '#3b82f6',
                                            '& .MuiChip-deleteIcon': {
                                                color: '#3b82f6',
                                                '&:hover': {
                                                    color: '#1e40af',
                                                },
                                            },
                                        }}
                                    />
                                ))}
                            </Box>
                        </Box>
                    )}
                </Box>
            </DialogContent>

            <Divider className="dark:bg-gray-700" />

            <DialogActions className="dark:bg-gray-800">
                <Button
                    onClick={handleCancel}
                    sx={{ color: 'inherit' }}
                >
                    Annuler
                </Button>
                <Button
                    onClick={handleConfirm}
                    variant="contained"
                    sx={{
                        backgroundColor: '#10b981',
                        '&:hover': {
                            backgroundColor: '#059669',
                        },
                    }}
                >
                    Confirmer
                </Button>
            </DialogActions>
        </Dialog>
    );
};
