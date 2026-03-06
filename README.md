# MyDashboard

Un dashboard React moderne et personnalisable avec système de drag & drop et sauvegarde en localStorage.

## 🚀 Fonctionnalités

- **Dashboard personnalisable** : Créez et organisez vos cartes comme vous le souhaitez
- **Drag & Drop** : Réorganisez vos cartes par simple glisser-déposer avec `react-grid-layout`
- **Sauvegarde automatique** : Toutes vos modifications sont sauvegardées en localStorage
- **Types de cartes multiples** : Cartes personnalisées, métriques, graphiques et tableaux
- **Navigation moderne** : Interface intuitive avec React Router
- **Design responsive** : S'adapte à tous les écrans avec Tailwind CSS
- **Architecture propre** : Structure MVC avec contrôleurs et services

## 🛠️ Technologies utilisées

- **React 18** avec TypeScript
- **React Router Dom** pour la navigation
- **React Grid Layout** pour le drag & drop
- **Tailwind CSS** pour le styling
- **Lucide React** pour les icônes
- **Architecture MVC** pour une organisation propre du code

## 📦 Installation

```bash
# Cloner le projet
git clone <votre-repo>
cd MyDashboard

# Installer les dépendances
npm install

# Lancer le serveur de développement
npm start
```

## 🏗️ Structure du projet

```
src/
├── components/          # Composants réutilisables
│   ├── Dashboard/       # Composant principal du dashboard
│   ├── DashboardCard/   # Composant de carte
│   └── Navbar/          # Barre de navigation
├── controllers/         # Logique métier
│   └── DashboardController.ts
├── pages/              # Pages de l'application
│   ├── Dashboard/      # Page dashboard
│   ├── Analytics/      # Page analytics
│   └── Settings/       # Page paramètres
├── services/           # Services (storage, API, etc.)
│   └── StorageService.ts
├── types/              # Types TypeScript
│   └── index.ts
└── utils/              # Utilitaires
    └── theme.ts
```

## 💡 Utilisation

### Ajouter une carte
1. Cliquez sur le bouton "Add Card"
2. Renseignez le titre et le contenu
3. Choisissez le type de carte
4. Validez

### Réorganiser les cartes
Utilisez le drag & drop pour déplacer et redimensionner vos cartes. La disposition est sauvegardée automatiquement.

### Supprimer une carte
Survolez une carte et cliquez sur le bouton "×" qui apparaît.

## 🎨 Types de cartes disponibles

- **Custom** : Carte personnalisée avec contenu libre
- **Metric** : Affichage de métriques avec mise en forme spéciale
- **Chart** : Placeholder pour futurs graphiques
- **Table** : Affichage sous forme de tableau

## 📊 Analytics

La page Analytics vous permet de visualiser :
- Nombre total de cartes
- Espace de stockage utilisé
- Nombre d'éléments dans la disposition

## ⚙️ Paramètres

La page Paramètres offre :
- Export de la configuration en JSON
- Import d'une configuration
- Suppression de toutes les données

## 🔧 Personnalisation

Le projet utilise une architecture modulaire permettant d'ajouter facilement :
- Nouveaux types de cartes
- Nouvelles pages
- Nouveaux services de stockage
- Intégrations API

## 📝 Bonnes pratiques implémentées

- **TypeScript** pour la sécurité des types
- **Architecture MVC** pour la séparation des responsabilités
- **Services centralisés** pour la gestion des données
- **Composants réutilisables** pour la maintenabilité
- **Responsive design** pour tous les appareils
- **Code propre** sans commentaires superflus
