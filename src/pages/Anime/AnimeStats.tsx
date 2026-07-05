import React from 'react';
import { AnimeStats as AnimeStatsType } from '../../types/anime.types';

interface AnimeStatsProps {
    stats: AnimeStatsType;
    loading?: boolean;
    onRefresh?: () => void;
    onClearNew?: () => void;
    onClearOld?: () => void;
}

export const AnimeStats: React.FC<AnimeStatsProps> = ({
    stats,
    loading = false,
    onRefresh,
    onClearNew,
    onClearOld,
}) => {
    const total = stats.totalCurrent + stats.totalNew + stats.totalOld;

    return (
        <div className="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 mb-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
                {/* Stats */}
                <div className="flex flex-wrap gap-6">
                    {/* Total */}
                    <div className="text-center">
                        <div className="text-3xl font-bold text-gray-800 dark:text-gray-200">
                            {total}
                        </div>
                        <div className="text-sm text-gray-500 dark:text-gray-400">
                            Total
                        </div>
                    </div>

                    {/* Current */}
                    <div className="text-center">
                        <div className="text-2xl font-bold text-blue-600">
                            {stats.totalCurrent}
                        </div>
                        <div className="text-sm text-gray-500 dark:text-gray-400">
                            Planning
                        </div>
                    </div>

                    {/* New */}
                    <div className="text-center">
                        <div className="text-2xl font-bold text-green-600 flex items-center gap-1">
                            {stats.totalNew}
                            {stats.totalNew > 0 && (
                                <span className="text-xs animate-pulse">✨</span>
                            )}
                        </div>
                        <div className="text-sm text-gray-500 dark:text-gray-400">
                            Nouveaux
                        </div>
                    </div>

                    {/* Old */}
                    <div className="text-center">
                        <div className="text-2xl font-bold text-orange-600">
                            {stats.totalOld}
                        </div>
                        <div className="text-sm text-gray-500 dark:text-gray-400">
                            Anciens
                        </div>
                    </div>

                    {/* Hidden */}
                    <div className="text-center">
                        <div className="text-2xl font-bold text-gray-500">
                            {stats.totalHidden}
                        </div>
                        <div className="text-sm text-gray-500 dark:text-gray-400">
                            Masqués
                        </div>
                    </div>
                </div>

                {/* Actions */}
                <div className="flex gap-2">
                    {stats.totalNew > 0 && onClearNew && (
                        <button
                            onClick={onClearNew}
                            className="px-3 py-2 bg-green-100 dark:bg-green-900 text-green-700 dark:text-green-300 rounded-lg hover:bg-green-200 dark:hover:bg-green-800 transition-colors text-sm font-medium"
                        >
                            ✓ Tout marquer comme vu
                        </button>
                    )}
                    
                    {stats.totalOld > 0 && onClearOld && (
                        <button
                            onClick={onClearOld}
                            className="px-3 py-2 bg-orange-100 dark:bg-orange-900 text-orange-700 dark:text-orange-300 rounded-lg hover:bg-orange-200 dark:hover:bg-orange-800 transition-colors text-sm font-medium"
                        >
                            🗑️ Vider les anciens
                        </button>
                    )}
                    
                    {onRefresh && (
                        <button
                            onClick={onRefresh}
                            disabled={loading}
                            className={`
                                px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 
                                transition-colors text-sm font-medium flex items-center gap-2
                                ${loading ? 'opacity-50 cursor-not-allowed' : ''}
                            `}
                        >
                            <span className={loading ? 'animate-spin' : ''}>🔄</span>
                            {loading ? 'Chargement...' : 'Rafraîchir'}
                        </button>
                    )}
                </div>
            </div>

            {/* Days breakdown */}
            {Object.keys(stats.byDay).length > 0 && (
                <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                    <div className="flex flex-wrap gap-2">
                        {Object.entries(stats.byDay).map(([day, count]) => (
                            <div
                                key={day}
                                className="px-3 py-1 bg-gray-100 dark:bg-gray-700 rounded-full text-sm"
                            >
                                <span className="text-gray-600 dark:text-gray-400">{day}:</span>
                                <span className="ml-1 font-medium text-gray-800 dark:text-gray-200">{count}</span>
                            </div>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
};

export default AnimeStats;
