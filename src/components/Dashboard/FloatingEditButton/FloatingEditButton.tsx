import React from 'react';
import { Edit3} from 'lucide-react';

interface FloatingEditButtonProps {
  isEditMode: boolean;
  onToggleEditMode: () => void;
}

const FloatingEditButton: React.FC<FloatingEditButtonProps> = ({
  isEditMode,
  onToggleEditMode,
}) => {  return (
    <div className="floating-edit-button">
      <button
        onClick={onToggleEditMode}
        className={`
          flex items-center justify-center w-16 h-16 rounded-full shadow-2xl
          transition-all duration-300 transform hover:scale-110 hover:shadow-3xl
          focus:outline-none focus:ring-4 focus:ring-opacity-50
          ${
            isEditMode
              ? 'hidden'
              : 'bg-blue-600 hover:bg-blue-700 focus:ring-blue-300 text-white'
          }
        `}
        title="Enter Edit Mode"
      >
        <Edit3 size={28} className="transition-transform duration-200 hover:rotate-12" />
      </button>
    </div>
  );
};

export default FloatingEditButton;
