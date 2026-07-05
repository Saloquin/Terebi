# Système de Reclassification des Animes

## Vue d'ensemble

Le système classe automatiquement les animes dans les bonnes catégories en fonction des saisons vues :

- **À regarder** (towatch) : 0 saisons vues
- **En cours** (inprogress) : 1+ saisons vues mais pas toutes les régulières
- **Complétés** (completed) : Toutes les saisons régulières vues, mais pas les supplémentaires
- **Déjà vu** (viewed) : Tout vu (régulières + supplémentaires)

## Logique de Classification

### Cas 1: 0 saisons vues → À regarder
```
anime.viewedSeasons.length === 0
→ Classé dans "À regarder"
```

### Cas 2: 1+ saisons vues, pas de données de saisons → En cours
```
anime.viewedSeasons.length > 0 && !anime.seasons
→ Classé dans "En cours" (on présume que c'est commencé)
```

### Cas 3: Toutes les régulières vues, mais pas tous les supplémentaires → Complétés
```
anime.seasons = [Regular1, Regular2, Special1, Film1]
anime.viewedSeasons = [Regular1, Regular2]
→ Classé dans "Complétés" (régulières finies)
```

### Cas 4: Tout vu → Déjà vu
```
anime.seasons = [Regular1, Regular2, Special1, Film1]
anime.viewedSeasons = [Regular1, Regular2, Special1, Film1]
→ Classé dans "Déjà vu" (tout est vu)
```

## Reclassification Automatique

### Quand ça se déclenche ?

1. **En temps réel** : Quand on marque une saison dans AnimeDetailPage
   - Appelle `reclassifyAnime(anime.id)`
   - Reclassifie immédiatement l'anime spécifique

2. **Bouton "Mettre à jour"** : Dans la page "À regarder"
   - Appelle `reclassifyAllAnimes()`
   - Reclassifie TOUS les animes de toutes les listes

### Flux complet

```
1. Utilisateur marque une saison
   ↓
2. saveSeasons() sauvegarde dans localStorage + seasons data
   ↓
3. reclassifyAnime() évalue et déplace à la bonne catégorie
   ↓
4. Utilisateur voit le changement en temps réel
   ↓
5. Bouton "Mettre à jour" reclassifie tout si besoin
```

## Données stockées

Chaque anime stocké avec :
```typescript
{
  id: string;
  title: string;
  image: string;
  url: string;
  fullUrl: string;
  dayOfWeek: string;
  type: AnimeType;
  viewedSeasons?: string[];  // Saisons vues
  seasons?: Season[];         // Données complètes des saisons
  viewedAt?: string;          // ISO timestamp
}
```

## Test Cases

Voir `anime.storage.test.ts` pour 6 cas de test :
- 0 saisons vues
- 1 saison vue sur 2 régulières
- Toutes régulières vues + spéciaux
- Tout vu
- Pas de données de saisons
- Scénario complexe avec OAV et spéciaux

## Exécuter les tests

Dans la console du navigateur :
```javascript
// Après que l'app soit chargée, importer et exécuter
window.testAnimeClassification?.runTests()
```

Ou en dev :
```typescript
import { runTests } from './services/api/anime.storage.test';
runTests();
```

## Migration des données

Les données existantes sont automatiquement reclassifiées au premier "Mettre à jour" via `reclassifyAllAnimes()`.

## Remarques importantes

- Les données `seasons` avec type (regular/special/film) sont essentielles pour la classification correcte
- Sans données `seasons`, on présume que tout anime avec `viewedSeasons` est "En cours"
- Un anime ne peut être que dans UNE liste à la fois
- La reclassification préserve toutes les autres propriétés
