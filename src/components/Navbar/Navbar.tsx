import React from 'react';
import { Link } from 'react-router-dom';
import { LayoutDashboard, JapaneseYen } from 'lucide-react';


const Navbar = () => {
  return (
    <nav className="bg-gray-800 shadow-lg border-b border-gray-700">
      <div className="max-w-full mx-auto px-6">
        <div className="flex justify-between h-16">
          <div className="flex items-center">
            <Link to="/" className="flex-shrink-0 flex items-center">
              <LayoutDashboard size={24} className="text-blue-400 mr-2" />
              <span className="text-2xl font-bold text-white">Dashboard</span>
            </Link>
          </div>
            <Link to="/anime" className="flex-shrink-0 flex items-center">
              <JapaneseYen size={24} className="text-blue-400 mr-2" />
              <span className="text-2xl font-bold text-white">Anime</span>
            </Link>
          <div className="flex items-center">
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;