import React from 'react';
import { ViewMode } from '../../types/anime.types';

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
}

const VIEW_MODES: { value: ViewMode; label: string; icon: string }[] = [
    { value: 'planning', label: 'Planning', icon: '📅' },
    { value: 'nouveaux', label: 'Nouveaux', icon: '✨' },
    { value: 'anciens', label: 'Anciens', icon: '📦' },
    { value: 'masques', label: 'Masqués', icon: '🙈' },
];

export const AnimeFilters: React.FC<AnimeFiltersProps> = ({
    viewMode,
    onViewModeChange,
    searchQuery,
    onSearchChange,
    counts,
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
                    <span className="absolute left-2.5 top-1/2 transform -translate-y-1/2 text-gray-400 text-sm">
                        🔍
                    </span>
                    {searchQuery && (
                        <button
                            onClick={() => onSearchChange('')}
                            className="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600 text-sm"
                        >
                            ✕
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
};

export default AnimeFilters;
