# Refonte de la navigation & du focus Android TV

**Date :** 2026-09-12
**Statut :** Design validé

## Problème

L'UI Android TV a un système de déplacement/sélection peu fluide et peu esthétique.
Deux bugs concrets remontés par l'utilisateur :

1. **On ne voit pas où on est en remontant.** Quand on descend du carrousel (hero
   banner) vers les rangées d'anime, tout va bien. Mais en **remontant**, le focus
   change sans que la page défile en sens inverse : l'élément focalisé reste hors
   écran, invisible.

2. **Blocage sur la navbar.** En remontant plusieurs fois, le focus atteint la
   navbar. Une fois dessus, il n'existe aucun chemin de retour fiable vers le
   contenu : `arrowDown` ne redescend pas. L'utilisateur reste coincé.

### Causes racines (code actuel)

- `TvFocusable` expose `onFocused` mais il n'est **jamais branché** sur
  `Scrollable.ensureVisible`. Aucun scroll-vers-focus n'existe.
- `app_shell_tv.dart:121` fait `FocusScope.of(context).requestFocus(FocusNode())`
  — un `FocusNode` vide qui ne pointe sur rien : anti-pattern qui casse le retour
  au contenu depuis la navbar.
- `autofocus: i == 0` est posé sur la 1re tuile de **chaque** rangée/grille →
  conflits d'autofocus au montage.
- La navigation D-pad repose entièrement sur la `FocusTraversalPolicy` par défaut,
  sans mémorisation de colonne entre rangées ni politique explicite.
- Le highlight (`AnimatedScale` 1.05 + bordure + glow) déborde et est compensé par
  des `+30px`/`+20px` ad hoc sur la hauteur des `ListView`.

## Principe directeur

Un système de focus **centralisé et déclaratif** : chaque élément focalisable
connaît sa position dans un `Scrollable` parent et s'y ancre automatiquement.
On remplace la logique dispersée par 2 primitives réutilisables, appliquées
uniformément aux 5 zones de l'UI TV.

Décisions produit validées :
- **Scroll vertical : ancrage haut style Netflix** (l'élément focalisé se place
  vers le haut de l'écran, ~12 %), y compris dans les grilles.
- **Highlight : zoom + bordure blanche** (façon Netflix), pas d'accent coloré ni
  d'effet projecteur.
- **Techno : Flutter natif** (`Scrollable.ensureVisible`), pas de package tiers.

## Composant 1 — `TvFocusable` (refonte visuelle + scroll)

Le widget `lib/src/ui/widgets/tv_focusable.dart` gagne le scroll-vers-focus
intégré et un highlight refait.

### Scroll auto
Au gain du focus, appelle :
```dart
Scrollable.ensureVisible(
  context,
  alignment: scrollAlignment, // 0.12 par défaut (ancrage haut)
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOutCubic,
);
```
- Flutter remonte **en cascade** tous les `Scrollable` ancêtres (vertical ET
  horizontal). Une tuile dans une rangée horizontale, elle-même dans un `ListView`
  vertical, est donc ancrée sur les deux axes.
- Garde-fou : n'appelle `ensureVisible` que si `Scrollable.maybeOf(context) != null`
  (évite tout crash hors contexte scrollable, ex. boutons de la page détail).
- Débounce implicite : lors d'un maintien D-pad, les events de focus rapides sont
  absorbés — Flutter annule l'animation précédente à chaque nouvel appel.

### Highlight (zoom + bordure blanche)
- `AnimatedScale` à `1.08`, transition 150 ms `Curves.easeOut`.
- Bordure blanche nette 3 px + `boxShadow` blanc doux (glow léger).
- Suppression des compensations d'overflow `+30px`/`+20px` : la marge nécessaire au
  zoom est réservée proprement via un `Padding` autour de la tuile, pas en gonflant
  la hauteur du `ListView`.

### API
- Ajout : `double scrollAlignment` (défaut `0.12`).
- `onFocused` devient purement optionnel (effets métier only, ex. hero banner de
  l'accueil qui réagit au changement de tuile focalisée). Il n'est plus le vecteur
  du scroll.

## Composant 2 — `TvFocusScope` (traversée D-pad maîtrisée)

Nouveau wrapper de page (`lib/src/ui/tv/widgets/tv_focus_scope.dart`) qui remplace
les `Focus.onKeyEvent` dispersés et le `requestFocus(FocusNode())` vide.

- **Politique de traversée** : `FocusTraversalGroup` avec politique directionnelle
  encadrée (navigation spatiale D-pad haut/bas/gauche/droite).
- **Mémorisation de colonne** : quand on descend d'une rangée à la suivante,
  Flutter par défaut retombe sur la 1re tuile. On mémorise l'index horizontal de la
  rangée quittée pour retomber sur la **même colonne** dans la rangée suivante
  (comportement Netflix).
- **Remontée navbar** : depuis la 1re rangée, `arrowUp` remonte à la navbar via un
  mécanisme unique et fiable.
- **Retour au contenu (corrige le blocage navbar)** : `arrowDown` depuis la navbar
  redescend de façon déterministe vers le **dernier élément focalisé** du contenu
  (ou la 1re tuile si aucun mémorisé). Plus de `FocusNode` vide.

## Composant 3 — Application aux 5 zones

| Zone | Fichier | Changement |
|------|---------|-----------|
| **Navbar** | `app_shell_tv.dart` (`_TvTopBar`, `_TvContentArea`) | Highlight via nouveau `TvFocusable`. `arrowDown` redescend au dernier élément focalisé du contenu, de façon déterministe. Suppression du `requestFocus(FocusNode())` vide. |
| **Accueil** | `home_page_tv.dart` | `ensureVisible` alignment 0.12 vertical + horizontal en cascade. `autofocus` unique (1re tuile de la 1re rangée). Le hero banner conserve son `onFocused` métier. |
| **Catalogue** | `catalog_page_tv.dart` (`_ResultsGrid`, `TvGenreGrid`) | `GridView` : ancrage-haut de la ligne focalisée + mémorisation de colonne. |
| **Bibliothèque** | `library_page_tv.dart` (`_LibraryGrid`) | Idem grille catalogue. |
| **Détail** | `media_detail_page_tv.dart` | Focus initial sur « Lire ». Entrée/sortie du panneau latéral (`TvSidePanel`) fiabilisée via le nouveau système. Boutons hors scroll → pas d'`ensureVisible`. |
| **Genres** | `tv_genre_grid.dart` | Idem grilles. |

## Cas limites

- `ensureVisible` conditionné à la présence d'un `Scrollable` ancêtre.
- Un seul `autofocus` par page (évite les sauts au montage).
- Maintien D-pad : animations de scroll qui s'enchaînent proprement (annulation
  auto de l'anim précédente).
- Page détail : le panneau latéral ouvert intercepte `goBack`/`arrowRight` pour se
  fermer sans quitter la page (comportement actuel conservé).

## Tests

Contrainte connue (voir mémoire `dev-env-constraints`) : `flutter_tester` bloqué
par l'EDR → tests via `dart test` uniquement, ou `flutter test` dans le conteneur
Docker (contournement établi).

- Tests widget de `TvFocusable` : état focus → scale/bordure/glow présents ;
  absence de focus → état neutre. Exécutés dans le conteneur Docker.
- Test widget de la mémorisation de colonne du `TvFocusScope` (simulation
  d'événements D-pad) si faisable dans le conteneur.
- Validation manuelle sur device TV pour la fluidité du scroll et l'absence de
  blocage navbar (les deux bugs d'origine servent de scénarios de recette).

## Critères de recette (scénarios utilisateur)

1. Depuis le carrousel, descendre dans les rangées : chaque rangée focalisée
   s'ancre en haut, on voit toujours où on est.
2. Remonter depuis le bas : la page défile en sens inverse, l'élément focalisé
   reste visible à chaque étape.
3. Atteindre la navbar en remontant, puis `arrowDown` : le focus revient au contenu
   (dernière position), aucun blocage.
4. Naviguer horizontalement dans une rangée puis descendre : on retombe sur la même
   colonne.
