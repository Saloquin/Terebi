# Architecture Scalable — Spec Design
*Date : 2026-09-07*

## Contexte

Terebi a vocation à devenir une plateforme de streaming anime extensible (style Mihon pour le streaming). L'architecture actuelle fonctionne mais concentre la logique métier dans les pages Flutter (fichiers de 800–1 644 lignes), ce qui rendra l'ajout de nouvelles sources et fonctionnalités de plus en plus coûteux.

## Objectif

Introduire une couche **Controllers** (Riverpod `Notifier`) entre les repositories/services et l'UI, de sorte que :
- Chaque page/widget ne fait que **lire de l'état** et **appeler des méthodes** sur son controller
- Toute la logique métier et les mutations DB vivent dans des controllers testables
- Les providers globaux ne vivent plus dans des fichiers de page

## Architecture cible

```
lib/
├── src/
│   ├── domain/          ← inchangé (Dart pur, déjà propre)
│   ├── data/            ← inchangé (repositories)
│   ├── services/        ← inchangé (intégration anime-sama)
│   ├── controllers/     ← NOUVEAU
│   │   ├── player/
│   │   │   ├── player_controller.dart      # Notifier : état + logique lecteur
│   │   │   ├── player_state.dart           # PlayerState (immutable)
│   │   │   └── episode_resolver.dart       # logique navigation épisodes (pur)
│   │   ├── library/
│   │   │   ├── library_controller.dart     # Notifier : filtrage, tri, recheck
│   │   │   └── library_state.dart          # LibraryState
│   │   ├── catalog/
│   │   │   ├── catalog_controller.dart     # Notifier : recherche, filtres
│   │   │   └── catalog_state.dart          # CatalogState
│   │   └── media_detail/
│   │       ├── media_detail_controller.dart # Notifier : mutations bibliothèque
│   │       └── media_detail_state.dart
│   ├── app/
│   │   ├── providers.dart                  ← providers globaux déplacés ici
│   │   └── providers/                      ← (futur découpage thématique)
│   └── ui/
│       ├── pages/       ← allégées : consomment controllers, aucun ref.read(repo)
│       └── widgets/     ← inchangé
```

## Règle d'or

> **Aucune page ou widget ne doit importer un repository, un service, ou un autre fichier de page.**
> Les imports UI → App se limitent à : `providers.dart`, `controllers/`, `domain/models/`, `widgets/`.

## Contrat des Controllers

Chaque controller suit ce pattern :

```dart
// State : immutable, copyWith
class PlayerState {
  final bool loading;
  final bool ready;
  final String? error;
  final int currentEpisode;
  // ...
  const PlayerState({...});
  PlayerState copyWith({...}) => ...;
}

// Controller : Notifier<State>
class PlayerController extends Notifier<PlayerState> {
  @override
  PlayerState build() => const PlayerState(...);

  // Méthodes publiques appelées par l'UI
  Future<void> loadAndPlay({required String title, required int episode}) async {
    state = state.copyWith(loading: true);
    // logique ici, via ref.read(...)
    state = state.copyWith(loading: false, ready: true);
  }
}

// Provider global
final playerControllerProvider = NotifierProvider<PlayerController, PlayerState>(
  PlayerController.new,
);
```

## Système d'extensions (futur)

`MediaId` sera un value object `(id: int, source: String)` où `source` vaut `'animesama'` aujourd'hui. Les controllers et repositories seront agnostiques à la source — ils reçoivent le `source` en paramètre. Ce changement n'est pas dans le scope de ce refactoring mais l'architecture doit ne pas l'empêcher.

## Priorités d'implémentation

1. **PlayerController** — le plus critique (1 644 lignes, import circulaire avec library_page)
2. **Déplacer les providers de library_page vers providers.dart** — casse l'import circulaire
3. **LibraryController** — logique recheck + mutations statut
4. **CatalogController** — recherche + filtres
5. **MediaDetailController** — mutations bibliothèque depuis la fiche

## Ce qui ne change PAS

- `domain/` — aucune modification
- `data/` — aucune modification
- `services/` — aucune modification
- Les providers existants dans `providers.dart` — déplacés, pas réécrits
- L'UI visible — aucun changement fonctionnel pour l'utilisateur
