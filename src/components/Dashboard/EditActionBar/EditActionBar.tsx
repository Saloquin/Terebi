import React, { useState } from 'react';
import { Save, X, Plus, Eye, EyeOff } from 'lucide-react';
import { DashboardCard as CardType } from '../../../types';

interface EditActionBarProps {
  isVisible: boolean;
  onSave: () => void;
  onCancel: () => void;
  predefinedCards: CardType[];
  visibleCards: string[];
  onToggleCard: (cardId: string) => void;
}

const EditActionBar: React.FC<EditActionBarProps> = ({
  isVisible,
  onSave,
  onCancel,
  predefinedCards,
  visibleCards,
  onToggleCard,
}) => {
  const [showCardPanel, setShowCardPanel] = useState(false);

  if (!isVisible) return null;

  return (
    <>
      {/* Card Panel */}
      {showCardPanel && (
        <div className="fixed bottom-20 right-6 bg-gray-800 rounded-lg p-4 border border-gray-700 shadow-xl z-40 min-w-72">
          <div className="flex justify-between items-center mb-3">
            <h3 className="text-white text-sm font-medium">Manage Cards</h3>
            <button
              onClick={() => setShowCardPanel(false)}
              className="text-gray-400 hover:text-white"
            >
              <X size={16} />
            </button>
          </div>
          <div className="space-y-2 max-h-60 overflow-y-auto">
            {predefinedCards.map((card) => (
              <div key={card.id} className="flex items-center justify-between p-2 bg-gray-700 rounded">
                <span className="text-gray-300 text-sm">{card.title}</span>
                <button
                  onClick={() => onToggleCard(card.id)}
                  className={`p-1 rounded transition-colors ${
                    visibleCards.includes(card.id)
                      ? 'bg-green-600 hover:bg-green-700 text-white'
                      : 'bg-gray-600 hover:bg-gray-500 text-gray-300'
                  }`}
                >
                  {visibleCards.includes(card.id) ? <Eye size={16} /> : <EyeOff size={16} />}
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Action Bar */}
      <div className="fixed bottom-6 right-6 bg-gray-800 rounded-full p-2 border border-gray-700 shadow-xl z-50 flex items-center gap-2">
        <button
          onClick={() => setShowCardPanel(!showCardPanel)}
          className="flex items-center justify-center w-12 h-12 rounded-full bg-blue-600 hover:bg-blue-700 text-white transition-all duration-200"
          title="Manage Cards"
        >
          <Plus size={20} />
        </button>
        
        <button
          onClick={onSave}
          className="flex items-center justify-center w-12 h-12 rounded-full bg-green-600 hover:bg-green-700 text-white transition-all duration-200"
          title="Save Changes"
        >
          <Save size={20} />
        </button>
        
        <button
          onClick={onCancel}
          className="flex items-center justify-center w-12 h-12 rounded-full bg-red-600 hover:bg-red-700 text-white transition-all duration-200"
          title="Cancel"
        >
          <X size={20} />
        </button>
      </div>
    </>
  );
};

export default EditActionBar;
