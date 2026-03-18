# Logique des onglets Anime + cas de test

Ce dossier contient la logique métier par onglet, séparée en fichiers dédiés :

- `planning.logic.ts`
- `new.logic.ts`
- `old.logic.ts`
- `hidden.logic.ts`

L'agrégation est faite dans `index.ts` via `getTabLogic(mode)`.

## Fonctions métier par fichier (localStorage + tri)

### `planning.logic.ts`
- `getPlanningAnime()` : lit le localStorage, retire les masqués, trie par jour/heure/titre
- `planningMarkAsSeen(animeId)` : retire l'anime de `new`

### `new.logic.ts`
- `getNewAnime()` : lit le localStorage, retire les masqués, trie
- `newMarkAsSeen(animeId)` : retire l'anime de `new`

### `old.logic.ts`
- `getOldAnime()` : lit le localStorage, retire les masqués, trie
- `removeOldAnime(animeId)` : retire l'anime de `old` + le retire de `hidden`

### `hidden.logic.ts`
- `getHiddenAnime()` : lit le localStorage, reconstruit la liste cachée à partir de `current + new + old`, trie
- `restoreHiddenAnime(animeId)` : retire l'ID de `hidden`

## Règles métier couvertes

### Planning (`planning`)
- Message vide : `Aucun anime dans le planning`
- Action autorisée : **masquer** (`onHide`)
- Les animes masqués n'apparaissent pas dans cette vue (filtrage fait côté storage `getCurrent()`).

### Nouveaux (`nouveaux`)
- Message vide : `Pas de nouveaux animes détectés`
- Action autorisée : **retirer de nouveaux** (`onMarkSeen`)
- Cette action ne fait rien d'autre que retirer l'anime de la liste `new`.

### Anciens (`anciens`)
- Message vide : `Pas d'anciens animes`
- Action autorisée : **supprimer de anciens** (`onRemoveOld`)
- Effet attendu : suppression de `old` + nettoyage de `hidden` pour cet anime.

### Masqués (`masques`)
- Message vide : `Aucun anime masqué`
- Action autorisée : **supprimer de masqués** (`onRestore`)
- Effet attendu : retrait de l'ID de la liste `hidden` uniquement.

## Cas de test implémentés

Fichier : `tabLogic.test.ts`

1. `planning: empty message + hide only`
   - vérifie le message vide
   - vérifie que seule l'action `onHide` est exposée
2. `nouveaux: remove from new only`
   - vérifie le message vide
   - vérifie que seule l'action `onMarkSeen` est exposée
3. `anciens: remove from old only`
   - vérifie le message vide
   - vérifie que seule l'action `onRemoveOld` est exposée
4. `masques: remove from hidden only`
   - vérifie le message vide
   - vérifie que seule l'action `onRestore` est exposée

Ces tests garantissent que chaque onglet active uniquement les actions attendues et évite les effets de bord entre vues.
