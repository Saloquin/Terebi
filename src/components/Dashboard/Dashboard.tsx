import React, { useState, useEffect } from 'react';
import { Responsive, WidthProvider } from 'react-grid-layout';
import EditActionBar from './EditActionBar/EditActionBar';
import { DashboardCard as CardType, DashboardLayout } from '../../types';
import {
    TodayAnimeCard,
    NewAnimeCard,
    NextAnimeCard,
    TomorrowAnimeCard
} from './CustomCards';
import { useLocalStorage } from '../../hooks/useLocalStorage';
import { useDashboardAnimeManager } from '../../hooks/useDashboardAnimeManager';
import 'react-grid-layout/css/styles.css';
import 'react-resizable/css/styles.css';
import { EyeOff } from 'lucide-react';
import FloatingEditButton from './FloatingEditButton/FloatingEditButton';


const ResponsiveGridLayout = WidthProvider(Responsive);


const Dashboard = () => {
    const [isEditMode, setIsEditMode] = useState(false);

    useDashboardAnimeManager({
        autoRefreshInterval: 5, // 5 minutes
        initialFetch: true
    });

    const availableCards: CardType[] = [
        {
            id: 'todayanime',
            title: 'Animes d\'aujourd\'hui',
            component: TodayAnimeCard,
            minSize: { w: 3, h: 6 }
        },
        {
            id: 'newanime',
            title: 'Nouveaux Animes',
            component: NewAnimeCard,
            minSize: { w: 3, h: 6 }
        },
        {
            id: 'nextanime',
            title: 'Prochain Anime',
            component: NextAnimeCard,
            minSize: { w: 4, h: 4 }
        },
        {
            id: 'tomorrownanime',
            title: 'Animes de demain',
            component: TomorrowAnimeCard,
            minSize: { w: 3, h: 6 }
        }
    ];
    const defaultLayout: DashboardLayout[] = [
        { i: 'todayanime', x: 0, y: 3, w: 3, h: 4 },
        { i: 'nextanime', x: 3, y: 3, w: 4, h: 3 },
        { i: 'newanime', x: 7, y: 3, w: 3, h: 4 },
        { i: 'tomorrownanime', x: 10, y: 3, w: 3, h: 4 },
    ];
    const [visibleCards, setVisibleCards] = useLocalStorage<string[]>(
        'visible_cards',
        availableCards.map((c: CardType) => c.id)
    );

    const [layout, setLayout] = useLocalStorage<DashboardLayout[]>(
        'dashboard_layout',
        defaultLayout.map((item: DashboardLayout) => ({
            ...item,
            w: Math.max(item.w, 3),
            h: Math.max(item.h, 2)
        }))
    );

    // Backup des états pour l'annulation
    const [backupVisibleCards, setBackupVisibleCards] = useState<string[]>(visibleCards);
    const [backupLayout, setBackupLayout] = useState<DashboardLayout[]>(layout);
    // Sauvegarder les backups quand on entre en mode édition

    useEffect(() => {
        if (isEditMode) {
            setBackupVisibleCards([...visibleCards]);
            setBackupLayout([...layout]);
        }
    }, [isEditMode]); const handleSave = () => {
        // Les données sont automatiquement sauvegardées grâce à useLocalStorage
        setBackupVisibleCards([...visibleCards]);
        setBackupLayout([...layout]);
        setIsEditMode(false);
    };

    const handleCancel = () => {
        setVisibleCards([...backupVisibleCards]);
        setLayout([...backupLayout]);
        setIsEditMode(false);
    };

    const handleToggleEditMode = () => {
        setIsEditMode(!isEditMode);
    };

    const handleLayoutChange = (newLayout: any[]) => {
        const dashboardLayout: DashboardLayout[] = newLayout.map(item => {
            const cardInfo = availableCards.find(card => card.id === item.i);
            const minW = cardInfo ? cardInfo.minSize.w : 3;
            const minH = cardInfo ? cardInfo.minSize.h : 2;
            return {
                i: item.i,
                x: item.x,
                y: item.y,
                w: Math.max(item.w, minW),
                h: Math.max(item.h, minH)
            };
        });
        setLayout(dashboardLayout);
    };

    const handleResize = (layout: any[], oldItem: any, newItem: any, placeholder: any, e: any, element: any) => {
        const cardInfo = availableCards.find(card => card.id === newItem.i);
        const minW = cardInfo ? cardInfo.minSize.w : 3;
        const minH = cardInfo ? cardInfo.minSize.h : 2;

        if (newItem.w < minW) {
            newItem.w = minW;
        }
        if (newItem.h < minH) {
            newItem.h = minH;
        }
    };
    const handleToggleCard = (cardId: string) => {
        if (visibleCards.includes(cardId)) {
            setVisibleCards(visibleCards.filter(id => id !== cardId));
        } else {
            setVisibleCards([...visibleCards, cardId]);
            const existingLayoutItem = layout.find(item => item.i === cardId);
            if (!existingLayoutItem) {
                const cardInfo = availableCards.find((card: CardType) => card.id === cardId);
                if (cardInfo) {
                    const newLayoutItem: DashboardLayout = {
                        i: cardId,
                        x: 0,
                        y: 0,
                        w: Math.max(cardInfo.minSize.w, 3), // Taille minimale de 3
                        h: Math.max(cardInfo.minSize.h, 2)  // Taille minimale de 2
                    };
                    setLayout([...layout, newLayoutItem]);
                }
            }
        }
    };

    const displayedCards = availableCards.filter((card: CardType) => visibleCards.includes(card.id)); const displayedLayout = layout
        .filter(item => visibleCards.includes(item.i))
        .map(item => {
            const cardInfo = availableCards.find(card => card.id === item.i);
            const minW = cardInfo ? cardInfo.minSize.w : 3;
            const minH = cardInfo ? cardInfo.minSize.h : 2;

            return {
                ...item,
                minW: minW,
                minH: minH,
                maxW: 16,
                maxH: 8
            };
        });
    return (
        <div className="p-4 bg-gray-900 min-h-screen">
            <div className="max-w-full mx-auto px-4">
                <div className="flex justify-between items-center mb-6"></div>
                <div className={`transition-all duration-300 ${isEditMode ? 'dashboard-edit-mode' : ''}`}>
                    <ResponsiveGridLayout
                        className="layout"
                        layouts={{ lg: displayedLayout }}
                        breakpoints={{ lg: 1200, md: 996, sm: 768, xs: 480, xxs: 0 }}
                        cols={{ lg: 16, md: 12, sm: 8, xs: 4, xxs: 2 }}
                        rowHeight={60}
                        onLayoutChange={handleLayoutChange}
                        onResize={handleResize}
                        isDraggable={isEditMode}
                        isResizable={isEditMode}
                        compactType={null}
                        preventCollision={false}>
                        {displayedCards.map((card: CardType) => {
                            const CardComponent = card.component;
                            return (
                                <div key={card.id} className="card h-full relative group border-l-4 border-l-blue-500">
                                    {isEditMode && (
                                        <button
                                            onClick={(e) => {
                                                e.preventDefault();
                                                e.stopPropagation();
                                                handleToggleCard(card.id);
                                            }}
                                            onMouseDown={(e) => {
                                                e.preventDefault();
                                                e.stopPropagation();
                                            }}
                                            onMouseUp={(e) => {
                                                e.preventDefault();
                                                e.stopPropagation();
                                            }}
                                            className="absolute top-2 right-2 w-8 h-8 bg-red-600 hover:bg-red-700 text-white rounded-full flex items-center justify-center text-sm transition-all duration-200 z-50 shadow-lg border-2 border-white/20 hover:scale-110 cursor-pointer"
                                            title="Masquer cette carte"
                                        >
                                            <EyeOff size={16} />
                                        </button>
                                    )}
                                    <CardComponent title={card.title} />
                                </div>
                            );
                        })}
                    </ResponsiveGridLayout>
                </div>        {displayedCards.length === 0 && (
                    <div className="text-center py-12">
                        <div className="bg-gray-800 rounded-lg shadow-lg p-8 border border-gray-700">
                            <div className="text-6xl mb-6">🎯</div>
                            <h3 className="text-2xl font-semibold text-gray-200 mb-4">No cards visible</h3>
                            <p className="text-gray-400 mb-6">Use edit mode to show some cards</p>
                        </div>
                    </div>
                )}
            </div>            <EditActionBar
                isVisible={isEditMode}
                onSave={handleSave}
                onCancel={handleCancel}
                predefinedCards={availableCards}
                visibleCards={visibleCards}
                onToggleCard={handleToggleCard}
            />
            <FloatingEditButton
                isEditMode={isEditMode}
                onToggleEditMode={handleToggleEditMode}
            />
        </div>

    );
};

export default Dashboard;
