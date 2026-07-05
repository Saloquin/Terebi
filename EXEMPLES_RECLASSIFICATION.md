# Exemples Concrets - Reclassification

## Exemple 1: Anime Simple (2 saisons)

### État Initial
```javascript
{
  id: "blue-exorcist",
  title: "Blue Exorcist",
  viewedSeasons: [],
  seasons: [
    { name: "Saison 1", type: "regular" },
    { name: "Saison 2", type: "regular" }
  ]
}
→ Catégorie: À regarder (0 saisons vues)
```

### User marque Saison 1
```javascript
{
  ...
  viewedSeasons: ["Saison 1"]
}

Reclassification:
- Saisons régulières vues: 1
- Saisons régulières totales: 2
- 1 < 2 → EN COURS ✓
```

### User marque Saison 2
```javascript
{
  ...
  viewedSeasons: ["Saison 1", "Saison 2"]
}

Reclassification:
- Saisons régulières vues: 2
- Saisons régulières totales: 2
- 2 == 2 ET aucun supplémentaire → COMPLÉTÉS ✓
```

---

## Exemple 2: Anime Complexe (régulières + spéciaux)

### État Initial
```javascript
{
  id: "attack-on-titan",
  title: "Attack on Titan",
  viewedSeasons: [],
  seasons: [
    { name: "Saison 1", type: "regular" },
    { name: "Saison 2", type: "regular" },
    { name: "Saison 3", type: "regular" },
    { name: "Saison 4", type: "regular" },
    { name: "Spécial OVA 1", type: "special" },
    { name: "Spécial OVA 2", type: "special" },
    { name: "Film 1", type: "film" }
  ]
}
→ Catégorie: À regarder
```

### User marque Saison 1
```javascript
viewedSeasons: ["Saison 1"]

Régulières vues: 1/4
→ EN COURS ✓
```

### User marque toutes les régulières sauf spéciaux
```javascript
viewedSeasons: ["Saison 1", "Saison 2", "Saison 3", "Saison 4"]

Régulières vues: 4/4 ✓
Supplémentaires vues: 0/3
→ COMPLÉTÉS ✓ (régulières terminées)
```

### User marque aussi les spéciaux et le film
```javascript
viewedSeasons: [
  "Saison 1", "Saison 2", "Saison 3", "Saison 4",
  "Spécial OVA 1", "Spécial OVA 2", "Film 1"
]

Régulières vues: 4/4 ✓
Total vus: 7/7 ✓
→ DÉJÀ VU ✓ (tout est vu)
```

---

## Exemple 3: Anime sans données de saisons

### État
```javascript
{
  id: "mystery-anime",
  title: "Mystery Anime",
  viewedSeasons: ["Saison 1"],
  seasons: undefined  // Pas chargé
}

Reclassification:
- viewedSeasons.length > 0 ✓
- !seasons → EN COURS ✓ (fallback)
```

**Note:** Les données de saisons se chargeront quand l'user clique sur le card.

---

## Exemple 4: Reclassification Batch (Bouton "Mettre à jour")

### Avant
```javascript
towatch: [
  { id: "a1", title: "Anime A", viewedSeasons: [] },
  { id: "a2", title: "Anime B", viewedSeasons: ["S1"] }  // ERREUR: devrait être en cours!
]
inprogress: []
completed: []
viewed: []
```

### User clique "Mettre à jour"
```
reclassifyAllAnimes() lance:
- Evaluate "Anime A": 0 saisons → reste towatch ✓
- Evaluate "Anime B": 1 saison vues → DÉPLACER à inprogress ✓

Après:
towatch: [
  { id: "a1", title: "Anime A", viewedSeasons: [] }
]
inprogress: [
  { id: "a2", title: "Anime B", viewedSeasons: ["S1"] }
]
```

---

## Exemple 5: OAV spécial (pas de saisons régulières)

### État
```javascript
{
  id: "standalone-ova",
  title: "Standalone OVA",
  viewedSeasons: [],
  seasons: [
    { name: "OVA Special", type: "oav" }
  ]
}

Reclassification:
- Saisons régulières: 0
- viewedSeasons.length === 0
→ À REGARDER ✓
```

### User marque l'OVA
```javascript
viewedSeasons: ["OVA Special"]

Régulières vues: 0/0 (aucune régulière!)
Total vus: 1/1
→ Cas spécial: tout est vu (pas de régulière) → DÉJÀ VU ✓
```

---

## Logs Exemple (Console Browser)

```
📂 Chargement des données locales...
📺 useAnimeSeasons called with slug: "blue-exorcist"
📺 Fetching seasons from: /api/animes/seasons/blue-exorcist

[User marque Saison 1]
📦 Reclassification: "Blue Exorcist" → En cours (1 saison(s))
🔄 Données mises à jour et reclassifiées depuis localStorage

[User marque Saison 2]
✅ Reclassification: "Blue Exorcist" → Complétés (régulières finies)

[User clique "Mettre à jour"]
🔄 Données mises à jour et reclassifiées depuis localStorage
📦 Reclassification: "Attack on Titan" → En cours (2 saison(s))
✅ Reclassification: "Demon Slayer" → Complétés (régulières finies)
🎉 Reclassification: "Jujutsu Kaisen" → Déjà vu (tout vu)
🔄 Reclassification terminée: 3 anime(s) déplacé(s)
```

---

## Tableau Récapitulatif

| Situation | Résultat | Raison |
|-----------|----------|--------|
| 0 saisons vues | À regarder | Aucune progression |
| 1 saison sur 2 régulières | En cours | Commencé mais pas fini |
| 2 saisons sur 2 + 3 spéciaux pas vus | Complétés | Régulières complètes |
| 2 saisons + 3 spéciaux + film, tout vu | Déjà vu | Tout complet |
| Saisons vues, pas de données | En cours | Fallback prudent |
| OVA uniquement, OVA vu | Déjà vu | Tout est vu (pas de régulière) |
| OVA uniquement, OVA pas vu | À regarder | Pas commencé |

---

## Notes Importantes

1. **Pas d'échecs:** Chaque anime a toujours une catégorie valide
2. **Pas de chevauchement:** Un anime ne peut être que dans UNE liste
3. **Transparent:** Tous les mouvements sont loggés en console
4. **Persistant:** Les changements sont sauvegardés en localStorage
5. **Reversible:** Vous pouvez importer/exporter et reclassifier
