import React from 'react';
import { ViewMode } from '../../types/anime.types';
import CalendarMonthIcon from '@mui/icons-material/CalendarMonth';
import FiberNewIcon from '@mui/icons-material/FiberNew';
import InventoryIcon from '@mui/icons-material/Inventory';
import VisibilityOffIcon from '@mui/icons-material/VisibilityOff';
import DeleteIcon from '@mui/icons-material/Delete';
import SearchIcon from '@mui/icons-material/Search';
import CloseIcon from '@mui/icons-material/Close';

interface AnimeFiltersProps {
    viewMode: ViewMode;
    onViewModeChange: (mode: ViewMode) => void;
    searchQuery: string;
    onSearchChange: (query: string) => void;
    counts: {
        planning: number;
        nouveaux: number;
        anciens: number;
        masques: number;
    };
    onClear?: () => void;
}

const VIEW_MODES: { value: ViewMode; label: string; icon: React.ReactNode }[] = [
    { value: 'planning', label: 'Planning', icon: <CalendarMonthIcon sx={{ fontSize: 16 }} /> },
    { value: 'nouveaux', label: 'Nouveaux', icon: <FiberNewIcon sx={{ fontSize: 16 }} /> },
    { value: 'anciens', label: 'Anciens', icon: <InventoryIcon sx={{ fontSize: 16 }} /> },
    { value: 'masques', label: 'Masqués', icon: <VisibilityOffIcon sx={{ fontSize: 16 }} /> },
];

export const AnimeFilters: React.FC<AnimeFiltersProps> = ({
    viewMode,
    onViewModeChange,
    searchQuery,
    onSearchChange,
    counts,
    onClear,
}) => {
    return (
        <div className="flex flex-wrap items-center gap-3 mb-4">
            {/* View Mode Tabs */}
            {VIEW_MODES.map(mode => (
                <button
                    key={mode.value}
                    onClick={() => onViewModeChange(mode.value)}
                    className={`
                        px-3 py-1.5 rounded-lg font-medium transition-all text-sm
                        flex items-center gap-1.5
                        ${viewMode === mode.value
                            ? 'bg-blue-600 text-white shadow-md'
                            : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600'
                        }
                    `}
                >
                    <span>{mode.icon}</span>
                    <span>{mode.label}</span>
                    <span className={`
                        px-1.5 py-0.5 text-xs rounded-full
                        ${viewMode === mode.value
                            ? 'bg-white/20'
                            : 'bg-gray-400/20'
                        }
                    `}>
                        {counts[mode.value]}
                    </span>
                </button>
            ))}

            {/* Clear button */}
            {onClear && (
                <button
                    onClick={() => {
                        if (window.confirm('Vider cette liste ?')) onClear();
                    }}
                    className="px-3 py-1.5 rounded-lg font-medium transition-all text-sm flex items-center gap-1.5 bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400 hover:bg-red-200 dark:hover:bg-red-900/50"
                >
                    <DeleteIcon sx={{ fontSize: 16 }} /> Vider
                </button>
            )}

            {/* Search */}
            <div className="flex-1 min-w-[200px] max-w-[300px] ml-auto">
                <div className="relative">
                    <input
                        type="text"
                        value={searchQuery}
                        onChange={(e) => onSearchChange(e.target.value)}
                        placeholder="Rechercher..."
                        className="w-full px-3 py-1.5 pl-8 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-800 dark:text-gray-200 text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                    <span className="absolute left-2.5 top-1/2 transform -translate-y-1/2 text-gray-400">
                        <SearchIcon sx={{ fontSize: 16 }} />
                    </span>
                    {searchQuery && (
                        <button
                            onClick={() => onSearchChange('')}
                            className="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600 text-sm"
                        >
                            <CloseIcon sx={{ fontSize: 14 }} />
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
};

export default AnimeFilters;
