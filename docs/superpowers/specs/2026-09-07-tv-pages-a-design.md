# TV Pages Sous-projet A — Catalogue, Bibliothèque, Fiche détail

## Objectif

Remplacer les pages desktop utilisées par `AppShellTv` (Catalogue, Bibliothèque, navigation vers MediaDetailPage) par des versions TV optimisées télécommande/D-pad, dans le style Netflix.

## Architecture

Fichiers parallèles dans `lib/src/ui/tv/` — aucun `if (isTv)` dans le code partagé.  
`AppShellTv` remplace `CatalogPage`, `LibraryPage` par les versions TV dans `_destinations`.  
La navigation vers la fiche détail (depuis catalogue et bibliothèque) pousse `MediaDetailPageTv` via `Navigator.push`.

### Fichiers créés

| Fichier | Rôle |
|---|---|
| `lib/src/ui/tv/catalog_page_tv.dart` | Page catalogue TV |
| `lib/src/ui/tv/library_page_tv.dart` | Page bibliothèque TV |
| `lib/src/ui/tv/media_detail_page_tv.dart` | Fiche détail TV |
| `lib/src/ui/tv/widgets/tv_genre_grid.dart` | Grille de genres navigable D-pad |
| `lib/src/ui/tv/widgets/tv_side_panel.dart` | Panneau latéral gauche générique (saisons, statut) |

### Fichier modifié

| Fichier | Changement |
|---|---|
| `lib/src/ui/tv/app_shell_tv.dart` | Remplace `CatalogPage()` par `CatalogPageTv()`, `LibraryPage()` par `LibraryPageTv()` |

---

## 1. CatalogPageTv

### État

```dart
class _CatalogPageTvState extends ConsumerState<CatalogPageTv> {
  String _query = '';             // résultat confirmé du clavier
  String? _selectedGenre;         // null = pas de filtre genre actif
  bool _hideLibrary = false;      // persisté dans SettingsKeys.catalogHideLibrary
  CatalogSortField _sort = CatalogSortField.titleAsc;
}
```

### Layout

```
┌─────────────────────────────────────────────────┐
│  [Rechercher]   [Masquer biblio toggle]           │  ← barre supérieure
├─────────────────────────────────────────────────┤
│  Vue A : grille de genres (défaut)               │
│  Vue B : résultats (si _query non vide           │
│           ou _selectedGenre != null)             │
└─────────────────────────────────────────────────┘
```

**Barre supérieure :**
- Bouton `TvFocusable` "Rechercher" (icône `Icons.search`) — `autofocus: true`
- OK → ouvre `_TvSearchDialog` (même pattern que `catalog_page.dart` ligne 172-184 — `showDialog<String>` avec `AlertDialog` isolée portant un `TextField` autofocus)
- Toggle `_hideLibrary` : `TvFocusable` avec `Icons.visibility_off` / `Icons.visibility`

**Vue A — TvGenreGrid (défaut, `_query.isEmpty && _selectedGenre == null`) :**
- Widget `TvGenreGrid` (voir section dédiée)
- Sélection d'un genre → `setState(() => _selectedGenre = genre)` → Vue B

**Vue B — résultats :**
- Provider : `_query.isNotEmpty` → `_searchResultsProvider(_query)` (existant dans `catalog_page.dart`)  
- `_selectedGenre != null` → `animeSamaByGenreProvider(_selectedGenre!)` (provider global existant)
- Grille 4 colonnes, ratio 2:3 (portrait), `GridView.builder` horizontal scrollable
- Chaque tuile : `AnimeSamaImage(slug:, fit: BoxFit.cover)` + titre en bas + badge statut bibliothèque
- Badge : `ref.watch(libraryStatusMapProvider)` — même logique que desktop
- `TvFocusable(onPressed: () => Navigator.push(... MediaDetailPageTv(...)))` sur chaque tuile
- Bouton retour (en haut à gauche ou flèche Retour) → `setState(() => _selectedGenre = null; _query = '')` → Vue A

### TvGenreGrid (widget extrait)

```dart
class TvGenreGrid extends StatelessWidget {
  final void Function(String genre) onGenreSelected;
  const TvGenreGrid({super.key, required this.onGenreSelected});
}
```

- Grille 4 colonnes, tiles de genre depuis `CatalogGenre.values` (enum existant dans `lib/src/domain/catalog_genre.dart`)
- Chaque tuile : `TvFocusable` + icône + label
- `autofocus: true` sur la première tuile

### Providers réutilisés (pas de nouveau provider)

- `_searchResultsProvider` — copié depuis `catalog_page.dart` (provider privé, pas exporté) → déclaré privé dans `catalog_page_tv.dart` identiquement
- `animeSamaByGenreProvider` — provider global existant dans `providers.dart`
- `libraryStatusMapProvider` — provider global existant

---

## 2. LibraryPageTv

### Layout

```
┌─────────────────────────────────────────────────┐
│  [En cours]  [Planifié]  [Terminé]  [...]        │  ← onglets TvFocusable
├─────────────────────────────────────────────────┤
│                                                  │
│  Grille verticale d'entrées (onglet actif)       │
│  vignette 16:9 + titre + progression             │
│                                                  │
└─────────────────────────────────────────────────┘
```

### État

```dart
class _LibraryPageTvState extends ConsumerState<LibraryPageTv> {
  ListStatus _activeTab = ListStatus.current;
}
```

Pas de tri ni filtre — simplement par `updatedAt` desc (tri par défaut de la bibliothèque). Pas de filtre genre/année (trop complexe télécommande).

### Onglets

- `TvFocusable` par statut dans l'ordre `_statusOrder` (même ordre que desktop)
- `autofocus: true` sur l'onglet "En cours"
- Badge compteur sur chaque onglet : `ref.watch(countByStatusProvider)`
- Indicateur de sélection : soulignement animé (même pattern que `_TvTabItem` dans `app_shell_tv.dart`)

### Grille d'entrées

- Provider : `ref.watch(entriesByStatusProvider(_activeTab))`
- Tri : `updatedAt` desc — `entries.sortedBy((e) => e.updatedAt).reversed` (`package:collection` — déjà dépendance transitive, importer `package:collection/collection.dart`)
- `GridView.builder` 4 colonnes, ratio 16:9
- Chaque tuile :
  - `AnimeSamaImage(slug: media?.animeSamaSlug ?? '', fallbackUrl: media?.coverImage, fit: BoxFit.cover)`
  - Media résolu via `ref.watch(listEntryProvider(entry.mediaId))` puis `mediaRepositoryProvider`
  - Titre en overlay bas
  - Barre de progression (`entry.progress / totalEpisodes`) — best-effort, 0 si inconnu
  - `TvFocusable(onPressed: () => Navigator.push(... MediaDetailPageTv(mediaId: entry.mediaId)))`

### Providers réutilisés

- `entriesByStatusProvider` — global existant
- `countByStatusProvider` — global existant
- `mediaRepositoryProvider` — global existant

---

## 3. MediaDetailPageTv

### Constructeur

```dart
class MediaDetailPageTv extends ConsumerStatefulWidget {
  final int mediaId;
  final String? displayTitle;

  const MediaDetailPageTv({
    super.key,
    required this.mediaId,
    this.displayTitle,
  });
}
```

Même signature que `MediaDetailPage` — réutilise les mêmes providers locaux (`_mediaDetailProvider`, `_resolvedSlugProvider`, `seasonProgressRefreshProvider`, `_planningTitlesProvider`) copiés depuis `media_detail_page.dart`. Ces providers sont privés donc copiés, pas importés.

### Layout plein écran Netflix

```
┌────────────────────────────────────────────────────────────────┐
│  [image de fond floue plein écran]                              │
│  [gradient sombre gauche + bas]                                 │
│                                                                 │
│  Panneau gauche (saisons) si ouvert ──┐                         │
│  ┌──────────────┐                    │                         │
│  │ Saison 1     │◄───────────────────┘                         │
│  │ Saison 2     │                                              │
│  │ Saison 3     │                                              │
│  └──────────────┘                                              │
│                                                                 │
│  Titre (grand, blanc)                    [ Lire ]              │
│  Synopsis (2-3 lignes, blanc54)          [ Ajouter/Modifier ]  │
│  Genres (chips)                          [ Saisons ▶ ]         │
│  Statut biblio                                                  │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### Image de fond

```dart
AnimeSamaImage(
  slug: media.animeSamaSlug ?? '',
  banner: true,  // bannière large
  fallbackUrl: media.bannerImage ?? media.coverImage,
  fit: BoxFit.cover,
)
```
+ `ColorFiltered` ou `BackdropFilter(filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4))`  
+ gradient : `LinearGradient` horizontal (gauche noir87 → transparent) + vertical (bas noir → transparent)

### Colonne boutons (droite)

Tous `TvFocusable` en colonne verticale, alignée droite, centrée verticalement :

1. **Lire** (`autofocus: true`) — `resumePlayback(context, ref, media)` (fonction existante dans `resume_helper.dart`)
2. **Ajouter** / **Modifier** — ouvre `TvSidePanel` à gauche avec les statuts `ListStatus.values` + option "Retirer"  
3. **Saisons** (si `seasons.length > 1`) — ouvre `TvSidePanel` à gauche avec la liste des saisons

### TvSidePanel (widget extrait)

```dart
class TvSidePanel extends StatelessWidget {
  final String title;
  final List<TvSidePanelItem> items;
  final void Function(TvSidePanelItem) onSelected;
  final VoidCallback onClose;
  const TvSidePanel({...});
}

class TvSidePanelItem {
  final String label;
  final dynamic value;  // ListStatus ou int (index saison)
  const TvSidePanelItem({required this.label, required this.value});
}
```

- Panneau gauche, largeur 280px, fond `Colors.black87`
- Liste verticale de `TvFocusable`, `autofocus: true` sur le premier item
- Flèche Retour (ou focus perdu à droite) → `onClose()`
- Utilisé pour les saisons ET pour le changement de statut

### Gestion saison active

- Lecture depuis `SettingsKeys.animeSamaSeasonFor(mediaId)` (même logique que `resume_helper.dart`)
- Écriture au choix d'une saison via `settingsRepositoryProvider.set(...)`

### Providers copiés (privés dans media_detail_page.dart)

- `_mediaDetailProvider` — StreamProvider.family, identique
- `_resolvedSlugProvider` — FutureProvider.family, identique
- `_planningTitlesProvider` — FutureProvider, identique
- `seasonProgressRefreshProvider` — StateProvider, identique (renommé local)

---

## 4. Mise à jour AppShellTv

Dans `_destinations` de `app_shell_tv.dart` :

```dart
// Avant :
_Destination(Icons.search, 'Catalogue', CatalogPage()),
_Destination(Icons.video_library_outlined, 'Bibliothèque', LibraryPage()),

// Après :
_Destination(Icons.search, 'Catalogue', CatalogPageTv()),
_Destination(Icons.video_library_outlined, 'Bibliothèque', LibraryPageTv()),
```

Imports ajoutés :
```dart
import 'catalog_page_tv.dart';
import 'library_page_tv.dart';
```
Imports supprimés :
```dart
import '../pages/catalog_page.dart';
import '../pages/library_page.dart';
```

---

## 5. Navigation vers MediaDetailPageTv

Partout dans les fichiers TV où on navigue vers un détail :

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MediaDetailPageTv(
      mediaId: mediaId,
      displayTitle: displayTitle,
    ),
  ),
);
```

**Depuis `home_page_tv.dart`** : les tuiles `_TvTile` et le hero "Détails" naviguent déjà via `MediaDetailPage` — mettre à jour pour utiliser `MediaDetailPageTv`.

---

## 6. Tests

Pas de tests UI (flutter_tester bloqué par EDR). Tests `dart test` non applicables pour des widgets purs.  
Vérification manuelle :
1. `dart analyze lib/` → no issues
2. Sur Android TV : D-pad navigue dans la grille genres → résultats → fiche détail
3. Bibliothèque : onglets D-pad, entrées visibles, navigation vers fiche
4. Fiche détail : hero fond, bouton Lire focus, panneau saisons/statut s'ouvre à gauche

---

## Résumé des fichiers

| Fichier | Action |
|---|---|
| `lib/src/ui/tv/catalog_page_tv.dart` | Créer |
| `lib/src/ui/tv/library_page_tv.dart` | Créer |
| `lib/src/ui/tv/media_detail_page_tv.dart` | Créer |
| `lib/src/ui/tv/widgets/tv_genre_grid.dart` | Créer |
| `lib/src/ui/tv/widgets/tv_side_panel.dart` | Créer |
| `lib/src/ui/tv/app_shell_tv.dart` | Modifier (swap imports + destinations) |
| `lib/src/ui/tv/home_page_tv.dart` | Modifier (MediaDetailPage → MediaDetailPageTv) |
