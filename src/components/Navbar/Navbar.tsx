import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { LayoutDashboard, JapaneseYen, Globe } from 'lucide-react';
import { configApi } from '../../services/api/config.api';


const Navbar = () => {
  const [extension, setExtension] = useState('to');
  const [editingExt, setEditingExt] = useState(false);
  const [inputExt, setInputExt] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    configApi.getConfig().then(c => setExtension(c.extension)).catch(() => {});
  }, []);

  const handleSaveExtension = async () => {
    if (!inputExt.trim()) return;
    setSaving(true);
    try {
      const config = await configApi.setExtension(inputExt.trim());
      setExtension(config.extension);
      setEditingExt(false);
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Erreur');
    } finally {
      setSaving(false);
    }
  };

  return (
    <nav className="bg-gray-800 shadow-lg border-b border-gray-700">
      <div className="max-w-full mx-auto px-6">
        <div className="flex justify-between h-16">
          <div className="flex items-center gap-6">
            <Link to="/" className="flex-shrink-0 flex items-center">
              <LayoutDashboard size={24} className="text-blue-400 mr-2" />
              <span className="text-2xl font-bold text-white">Dashboard</span>
            </Link>
            <Link to="/anime" className="flex-shrink-0 flex items-center">
              <JapaneseYen size={24} className="text-blue-400 mr-2" />
              <span className="text-2xl font-bold text-white">Anime</span>
            </Link>
          </div>
          <div className="flex items-center gap-3">
            <Globe size={16} className="text-gray-400" />
            {editingExt ? (
              <div className="flex items-center gap-2">
                <span className="text-gray-400 text-sm">anime-sama.</span>
                <input
                  type="text"
                  value={inputExt}
                  onChange={(e) => setInputExt(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleSaveExtension()}
                  className="w-16 px-2 py-1 bg-gray-700 border border-gray-600 rounded text-white text-sm focus:outline-none focus:border-blue-500"
                  placeholder="to"
                  autoFocus
                />
                <button
                  onClick={handleSaveExtension}
                  disabled={saving}
                  className="px-2 py-1 bg-green-600 hover:bg-green-700 text-white text-xs rounded transition-colors"
                >
                  {saving ? '...' : '✓'}
                </button>
                <button
                  onClick={() => setEditingExt(false)}
                  className="px-2 py-1 bg-gray-600 hover:bg-gray-500 text-white text-xs rounded transition-colors"
                >
                  ✕
                </button>
              </div>
            ) : (
              <button
                onClick={() => { setInputExt(extension); setEditingExt(true); }}
                className="text-gray-300 hover:text-white text-sm flex items-center gap-1 transition-colors"
                title="Changer l'extension du site"
              >
                anime-sama.<span className="text-blue-400 font-bold">{extension}</span>
              </button>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;