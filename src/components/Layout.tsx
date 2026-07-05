import { Link, NavLink, Outlet } from 'react-router-dom';

const navClass = ({ isActive }: { isActive: boolean }) =>
  `px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
    isActive
      ? 'bg-accent text-white'
      : 'text-gray-400 hover:text-white hover:bg-surface-raised'
  }`;

export default function Layout() {
  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-surface-border bg-surface-raised/80 backdrop-blur sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between gap-4">
          <Link to="/planning" className="text-lg font-bold text-white tracking-tight">
            Anime Dashboard
          </Link>
          <nav className="flex flex-wrap gap-1">
            <NavLink to="/planning" className={navClass} end>
              Planning
            </NavLink>
            <NavLink to="/catalog" className={navClass}>
              Catalogue
            </NavLink>
            <NavLink to="/towatch" className={navClass}>
              À regarder
            </NavLink>
            <NavLink to="/viewed" className={navClass}>
              Déjà vu
            </NavLink>
          </nav>
        </div>
      </header>
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}
