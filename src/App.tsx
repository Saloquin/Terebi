import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar/Navbar';
import DashboardPage from './pages/Dashboard/Dashboard';
import FloatingEditButton from './components/Dashboard/FloatingEditButton/FloatingEditButton';
import AnimePage from './pages/Anime/Anime';

const App: React.FC = () => {

    return (
    <Router>
      <div className="min-h-screen bg-gray-900">
        <Navbar/>        
        <main className="flex-1">
          <Routes>
            <Route 
              path="/" 
              element={
                <DashboardPage/>
              } 
            />
            <Route 
              path="/anime" 
              element={<AnimePage />} 
            />
            <Route 
              path="*" 
              element={
                <DashboardPage/>
              } 
            />
          </Routes>
        </main>
      </div>
    </Router>
  );
};

export default App;