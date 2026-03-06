@echo off
echo ================================
echo   MyDashboard - Lancement
echo ================================
echo.

:: Vérifier si le dossier api existe
if not exist "api" (
    echo [ERREUR] Le dossier 'api' n'existe pas!
    echo Verifiez la structure du projet.
    pause
    exit /b 1
)

:: Installer les dépendances API si nécessaire
if not exist "api\node_modules" (
    echo [INFO] Installation des dependances API...
    cd api
    call npm install
    cd ..
    echo.
)

:: Installer les dépendances Frontend si nécessaire
if not exist "node_modules" (
    echo [INFO] Installation des dependances Frontend...
    call npm install
    echo.
)

echo [INFO] Demarrage du backend API sur le port 3001...
start "API Backend" cmd /k "cd api && npm run dev"

:: Attendre un peu que l'API démarre
timeout /t 3 /nobreak >nul

echo [INFO] Demarrage du frontend sur le port 3000...
start "Frontend React" cmd /k "npm start"

echo.
echo ================================
echo   Serveurs demarres !
echo ================================
echo.
echo   - Frontend: http://localhost:3000
echo   - API:      http://localhost:3001
echo.
echo Fermez les fenetres de terminal pour arreter les serveurs.
echo.
