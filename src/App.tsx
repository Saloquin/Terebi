import { Navigate, Route, Routes } from 'react-router-dom';
import Layout from './components/Layout';
import AnimeDetailPage from './pages/AnimeDetailPage';
import CatalogPage from './pages/CatalogPage';
import PlanningPage from './pages/PlanningPage';
import UserListPage from './pages/UserListPage';

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Navigate to="/planning" replace />} />
        <Route path="planning" element={<PlanningPage />} />
        <Route path="planning/:year/:season" element={<PlanningPage />} />
        <Route path="catalog" element={<CatalogPage />} />
        <Route
          path="towatch"
          element={
            <UserListPage
              listType="towatch"
              title="À regarder"
              emptyMessage="Votre liste est vide. Ajoutez des animes depuis une fiche détail."
            />
          }
        />
        <Route
          path="viewed"
          element={
            <UserListPage
              listType="viewed"
              title="Déjà vu"
              emptyMessage="Aucun anime marqué comme vu."
            />
          }
        />
        <Route path="anime/:anilistId" element={<AnimeDetailPage />} />
      </Route>
    </Routes>
  );
}
