# Guide d'Utilisation - Système de Catégorisation

## Pour l'utilisateur

### Ajouter un anime
1. Allez au **Catalogue**
2. Cherchez un anime
3. Cliquez sur **"Ajouter"** → Il va dans "À regarder"

### Regarder des saisons
1. Allez dans **À regarder** → trouvez votre anime
2. Cliquez sur la carte → s'ouvre le détail
3. Cochez les saisons regardées
4. L'anime **se reclassifie automatiquement** :
   - 1+ saison cochée → **"En cours"**
   - Toutes les régulières cochées → **"Complétés"**
   - Tout coché → **"Déjà vu"**

### Bouton "Mettre à jour"
- Situé en haut à droite de "À regarder"
- Reclassifie TOUS les animes si besoin
- Utile après import JSON ou modification manuelle

### Structure des onglets
```
À regarder
├─ En cours : Vous avez commencé (1+ saisons cochées)
├─ À regarder : Pas encore commencé
├─ Complétés : Toutes régulières vues
└─ Déjà vu : Tout vu (y compris spéciaux)
```

---

## Pour les développeurs

### Tester la logique

Dans la console du navigateur (F12) :
```javascript
window.testAnimeClassification.runTests()
```

Résultat attendu :
```
✅ PASS: 0 saisons vues → À regarder
✅ PASS: 1 saison vue sur 2 régulières → En cours
✅ PASS: Toutes saisons régulières vues + spéciaux → Complétés
✅ PASS: Tout vu (saisons + spéciaux + films) → Déjà vu
✅ PASS: Pas de données seasons mais viewedSeasons → En cours
✅ PASS: 2 régulières + 1 OAV + 2 spéciaux, 3 vus → Complétés

📊 Résultats: 6/6 tests réussis
🎉 Tous les tests sont passés!
```

### Flux de reclassification

#### 1. Marquer une saison (temps réel)
```
AnimeDetailPage.handleSeasonToggle()
  ↓
saveSeasons(seasons)
  ├─ Sauvegarde viewedSeasons + seasons data
  └─ Appelle animeStorage.reclassifyAnime(anime.id)
    └─ Vérifie la catégorie correcte
      └─ Déplace si besoin
```

#### 2. Bouton "Mettre à jour" (batch)
```
ToWatchPage.handleUpdateFromLocalStorage()
  ↓
useAnimeData.updateFromLocalStorage()
  ├─ Appelle animeStorage.reclassifyAllAnimes()
  │ └─ Reclassifie TOUS les animes
  └─ loadLocal()
    └─ Rafraîchit l'UI
```

### Structure des données

```typescript
// Dans localStorage (anime_dashboard_v2)
{
  towatch: [
    {
      id: "anime-1",
      title: "Blue Exorcist",
      viewedSeasons: [],
      seasons: [
        { name: "Saison 1", type: "regular" },
        { name: "Saison 2", type: "regular" },
        { name: "Spécial 1", type: "special" }
      ]
    },
    // ... autres animes
  ],
  inprogress: [
    {
      id: "anime-2",
      title: "Attack on Titan",
      viewedSeasons: ["Saison 1"],
      seasons: [...],
    }
  ],
  completed: [...],
  viewed: [...]
}
```

### Ajouter une catégorie (exemple future)

1. Ajouter au type `AnimeStorage` dans `anime.types.ts`
2. Créer getter dans `anime.storage.ts`
3. Ajouter onglet dans `ToWatchPage.tsx`
4. Mettre à jour la logique de `reclassifyAnime()`

---

## Cas limites traités

✅ Anime sans données de saisons → Classé "En cours"  
✅ Anime avec viewedSeasons vide → Classé "À regarder"  
✅ Anime avec spéciaux et films → Correctement classé  
✅ Reclassification partielle → Seul l'anime affecté change  
✅ Import JSON → Reclassification globale via bouton  
✅ Doublons évités → Un anime dans une seule liste  

---

## Performance

- **reclassifyAnime()** : O(n) par anime, O(1) pour la catégorisation
- **reclassifyAllAnimes()** : O(n*m) où n=nombre d'animes, m=catégories
- Pas d'appels API, tout en localStorage
- Instantané pour l'utilisateur

---

## Dépannage

### L'anime ne change pas de catégorie
- ✓ Vérifier que les données `seasons` sont chargées
- ✓ Cliquer "Mettre à jour" pour forcer la reclassification globale
- ✓ Vérifier la console du navigateur pour les logs

### L'anime est dans deux listes
- Impossible par design (vérification stricte)
- Si ça arrive = bug, signaler

### Les données de saisons sont vides
- Cliquer sur l'anime pour charger les saisons depuis l'API
- Elles se sauvegardent au premier marque de saison
