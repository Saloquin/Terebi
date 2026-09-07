# UI TV — Shell + Accueil Netflix-style

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le `isTvProvider` bool par une enum `AppPlatform` à 3 valeurs, créer `AppShellTv` avec barre horizontale fixe, et `HomepageTv` style Netflix (hero plein écran + rangées 16:9 défilantes).

**Architecture:** Approche fichiers parallèles — `AppShellTv` et `HomepageTv` sont des fichiers indépendants qui partagent la logique des providers existants. Le routage se fait via un switch sur `appPlatformProvider` dans le `AppShell` existant (renommé `AppShellDesktop`). Aucun `if (isTv)` ajouté dans le code commun.

**Tech Stack:** Flutter, Riverpod (`StateProvider`, dérivé de `isTvProvider`), `TvFocusable` (existant), `AnimeSamaImage` (existant), `NetworkImage` pour les covers plein écran.

---

## Structure des fichiers

### Fichiers créés
| Fichier | Rôle |
|---|---|
| `lib/src/app/app_platform.dart` | Enum `AppPlatform` + `appPlatformProvider` |
| `lib/src/ui/tv/app_shell_tv.dart` | Shell TV : `TvTopBar` + routing + logique commune |
| `lib/src/ui/tv/home_page_tv.dart` | Accueil TV : hero plein écran + rangées 16:9 |
| `lib/src/ui/tv/widgets/tv_hero_banner.dart` | Hero plein écran avec gradient + boutons |
| `lib/src/ui/tv/widgets/tv_content_row.dart` | Rangée horizontale avec tuiles 16:9 |

### Fichiers modifiés
| Fichier | Changement |
|---|---|
| `lib/src/ui/app_shell.dart` | Renommé `AppShellDesktop` ; switch sur `appPlatformProvider` dans le nouveau `AppShell` |
| `lib/src/app/providers.dart` | Ajouter import + export `appPlatformProvider` |
| `lib/main.dart` | Remplacer `isTvProvider` override par `appPlatformProvider` override |

---

## Task 1 : Créer AppPlatform + appPlatformProvider

**Files:**
- Create: `lib/src/app/app_platform.dart`
- Modify: `lib/src/app/providers.dart`
- Modify: `lib/main.dart`

- [ ] **Étape 1 : Lire main.dart pour voir comment isTvProvider est override au démarrage**

```bash
grep -n "isTvProvider\|detectIsTelevision\|overrideWithValue" lib/main.dart | head -20
```

- [ ] **Étape 2 : Créer lib/src/app/app_platform.dart**

```dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

enum AppPlatform {
  /// Android TV / Fire TV — navigation D-pad, interface Netflix-style.
  tv,
  /// Android téléphone / tablette — interface mobile (sous-projet 2).
  mobile,
  /// Windows / Linux / macOS — NavigationRail, interface actuelle.
  desktop,
}

/// Plateforme détectée au démarrage. Override via ProviderScope dans main.dart.
/// Dérivé de la détection Android TV (isTvProvider) et de la plateforme cible.
final appPlatformProvider = StateProvider<AppPlatform>((ref) {
  // Valeur par défaut basée sur la plateforme de compilation.
  // Surchargée au démarrage dans main.dart après détection Android TV.
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AppPlatform.mobile; // remplacé par .tv si Android TV détecté
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return AppPlatform.desktop;
    default:
      return AppPlatform.desktop;
  }
});
```

- [ ] **Étape 3 : Ajouter l'import dans providers.dart**

Dans `lib/src/app/providers.dart`, ajouter dans le bloc d'imports en haut :
```dart
import 'app_platform.dart';
export 'app_platform.dart';
```

- [ ] **Étape 4 : Modifier main.dart pour override appPlatformProvider**

Lire `lib/main.dart` entièrement, puis trouver le bloc `ProviderScope(overrides: [...])`  où `isTvProvider` est overridé, et ajouter à côté :

```dart
appPlatformProvider.overrideWith((ref) {
  // isTelevision est la variable bool déjà calculée dans bootstrap()
  if (isTelevision) return AppPlatform.tv;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AppPlatform.mobile;
    default:
      return AppPlatform.desktop;
  }
}),
```

Note : `isTvProvider` reste overridé en parallèle pour la rétrocompatibilité avec le code existant.

- [ ] **Étape 5 : Analyser**

```bash
dart analyze lib/src/app/app_platform.dart lib/src/app/providers.dart lib/main.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 6 : Commit**

```bash
git add lib/src/app/app_platform.dart lib/src/app/providers.dart lib/main.dart
git commit -m "feat(tv): add AppPlatform enum + appPlatformProvider (tv/mobile/desktop)"
```

---

## Task 2 : Renommer AppShell en AppShellDesktop + switch AppPlatform

**Files:**
- Modify: `lib/src/ui/app_shell.dart`

La classe `AppShell` devient `AppShellDesktop` (logique interne inchangée). Un nouveau widget `AppShell` devient le routeur principal qui switch sur `appPlatformProvider`.

- [ ] **Étape 1 : Lire app_shell.dart entièrement pour localiser la classe**

```bash
grep -n "class AppShell\|class _AppShell" lib/src/ui/app_shell.dart
```

- [ ] **Étape 2 : Renommer AppShell → AppShellDesktop dans app_shell.dart**

Renommer la classe `AppShell` en `AppShellDesktop` et `_AppShellState` en `_AppShellDesktopState` dans `lib/src/ui/app_shell.dart`.

Utiliser le tool Edit avec `replace_all: true` :
- `AppShell` → `AppShellDesktop` (attention : ne pas toucher les imports)
- `_AppShellState` → `_AppShellDesktopState`

- [ ] **Étape 3 : Ajouter le routeur AppShell à la fin de app_shell.dart**

Ajouter à la fin du fichier, après `AppShellDesktop` :

```dart
import 'tv/app_shell_tv.dart';

/// Point d'entrée unique : route vers le bon shell selon la plateforme.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(appPlatformProvider)) {
      AppPlatform.tv      => const AppShellTv(),
      AppPlatform.mobile  => const AppShellDesktop(), // shell mobile = desktop pour l'instant
      AppPlatform.desktop => const AppShellDesktop(),
    };
  }
}
```

Note : `AppShellTv` sera créé en Task 3. Pour compiler en Task 2, créer un stub temporaire :
```dart
// Stub temporaire — remplacé en Task 3
class AppShellTv extends StatelessWidget {
  const AppShellTv({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('TV Shell — en construction')),
  );
}
```

- [ ] **Étape 4 : Vérifier que main.dart trouve encore AppShell**

```bash
grep -n "AppShell" lib/main.dart
```

`AppShell` étant défini dans le même fichier `app_shell.dart` (juste renommé), les imports existants ne changent pas.

- [ ] **Étape 5 : Analyser**

```bash
dart analyze lib/src/ui/app_shell.dart lib/main.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 6 : Commit**

```bash
git add lib/src/ui/app_shell.dart
git commit -m "refactor(shell): rename AppShell→AppShellDesktop + add AppPlatform router stub"
```

---

## Task 3 : Créer AppShellTv avec TvTopBar

**Files:**
- Create: `lib/src/ui/tv/app_shell_tv.dart`

La `TvTopBar` est incluse dans ce fichier (widget privé `_TvTopBar`). Elle affiche les 6 onglets en `Row` horizontal, fond `Colors.black87`, hauteur 64px. Focus D-pad sur chaque onglet via `TvFocusable`. Badge nouvel épisode sur l'onglet Bibliothèque.

- [ ] **Étape 1 : Créer lib/src/ui/tv/app_shell_tv.dart**

```dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../pages/calendar_page.dart';
import '../pages/catalog_page.dart';
import '../pages/library_page.dart';
import '../pages/settings_page.dart';
import '../pages/stats_page.dart';
import '../widgets/tv_focusable.dart';
import 'home_page_tv.dart';

const int _settingsIndex = 5;
const int _libraryIndex = 3;

class _Destination {
  final IconData icon;
  final String label;
  final Widget page;
  const _Destination(this.icon, this.label, this.page);
}

class AppShellTv extends ConsumerStatefulWidget {
  const AppShellTv({super.key});

  @override
  ConsumerState<AppShellTv> createState() => _AppShellTvState();
}

class _AppShellTvState extends ConsumerState<AppShellTv> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = ref.read(settingsRepositoryProvider);
      final autoUpdate =
          await settings.get(SettingsKeys.autoUpdate, defaultValue: '0');
      if (autoUpdate == '1' && mounted) {
        ref.invalidate(updateCheckProvider);
      }
    });
  }

  static const _destinations = <_Destination>[
    _Destination(Icons.home_outlined, 'Accueil', HomepageTv()),
    _Destination(Icons.search, 'Catalogue', CatalogPage()),
    _Destination(Icons.calendar_month_outlined, 'Calendrier', CalendarPage()),
    _Destination(Icons.video_library_outlined, 'Bibliothèque', LibraryPage()),
    _Destination(Icons.bar_chart, 'Stats', StatsPage()),
    _Destination(Icons.settings_outlined, 'Paramètres', SettingsPage()),
  ];

  void _onSelect(int i) {
    if (i == _index) return;
    if (_index == _settingsIndex && ref.read(settingsDirtyProvider)) {
      ref.read(settingsFlashProvider.notifier).state++;
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(slugMigrationProvider);
    final hasNewEpisode = ref.watch(newEpisodeIdsProvider).maybeWhen(
          data: (ids) => ids.isNotEmpty,
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _TvTopBar(
            destinations: _destinations,
            selectedIndex: _index,
            hasNewEpisode: hasNewEpisode,
            onSelect: _onSelect,
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [for (final d in _destinations) d.page],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvTopBar extends StatelessWidget {
  final List<_Destination> destinations;
  final int selectedIndex;
  final bool hasNewEpisode;
  final void Function(int) onSelect;

  const _TvTopBar({
    required this.destinations,
    required this.selectedIndex,
    required this.hasNewEpisode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'assets/branding/logo_sombre_texte.png',
            height: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 32),
          // Onglets
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                for (int i = 0; i < destinations.length; i++)
                  _TvTabItem(
                    icon: destinations[i].icon,
                    label: destinations[i].label,
                    selected: selectedIndex == i,
                    showBadge: i == _libraryIndex && hasNewEpisode,
                    onPressed: () => onSelect(i),
                    autofocus: i == 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onPressed;
  final bool autofocus;

  const _TvTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showBadge,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: showBadge,
                child: Icon(
                  icon,
                  color: selected ? Colors.white : Colors.white54,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              // Indicateur de sélection
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 2,
                width: selected ? 32 : 0,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Étape 2 : Créer le stub home_page_tv.dart (sera complété en Task 4)**

Créer `lib/src/ui/tv/home_page_tv.dart` avec juste un stub :

```dart
library;

import 'package:flutter/material.dart';

class HomepageTv extends StatelessWidget {
  const HomepageTv({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Accueil TV',
          style: TextStyle(color: Colors.white, fontSize: 32),
        ),
      ),
    );
  }
}
```

- [ ] **Étape 3 : Supprimer le stub AppShellTv dans app_shell.dart**

Dans `lib/src/ui/app_shell.dart`, supprimer le stub `AppShellTv` et garder uniquement l'import `tv/app_shell_tv.dart`.

- [ ] **Étape 4 : Analyser**

```bash
dart analyze lib/src/ui/tv/ lib/src/ui/app_shell.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 5 : Commit**

```bash
git add lib/src/ui/tv/ lib/src/ui/app_shell.dart
git commit -m "feat(tv): AppShellTv with TvTopBar (6 tabs, D-pad, badge)"
```

---

## Task 4 : TvHeroBanner — hero plein écran avec gradient

**Files:**
- Create: `lib/src/ui/tv/widgets/tv_hero_banner.dart`

Le hero occupe toute la hauteur de l'écran moins 64px (TopBar). Image de fond plein écran (cover de l'anime via `AnimeSamaImage` ou `NetworkImage`). Gradient noir en bas sur 50% de hauteur. Par-dessus : titre en grand (48px), genres en petit, deux boutons `TvFocusable` : **▶ Lire** et **ℹ Détails**. Rotation auto toutes les 10s via `Timer.periodic`. Pausée quand le focus est sur le hero.

- [ ] **Étape 1 : Vérifier la signature de AnimeSamaImage**

```bash
grep -n "class AnimeSamaImage\|AnimeSamaImage(" lib/src/ui/widgets/anime_sama_image.dart | head -5
```

- [ ] **Étape 2 : Créer lib/src/ui/tv/widgets/tv_hero_banner.dart**

```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/media.dart';
import '../../widgets/anime_sama_image.dart';
import '../../widgets/tv_focusable.dart';
import '../../pages/media_detail_page.dart';
import '../../pages/resume_helper.dart';

/// Hero plein écran style Netflix pour Android TV.
/// Affiche les [items] en rotation automatique toutes les [rotationSeconds] secondes.
/// Quand le focus descend dans une rangée en dessous, [focusedMedia] peut
/// surcharger l'image de fond (réactivité au focus des rangées).
class TvHeroBanner extends ConsumerStatefulWidget {
  final List<Media> items;
  final int rotationSeconds;
  final Media? focusedMedia; // null = utiliser l'item courant du carousel

  const TvHeroBanner({
    super.key,
    required this.items,
    this.rotationSeconds = 10,
    this.focusedMedia,
  });

  @override
  ConsumerState<TvHeroBanner> createState() => _TvHeroBannerState();
}

class _TvHeroBannerState extends ConsumerState<TvHeroBanner> {
  int _current = 0;
  Timer? _timer;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: widget.rotationSeconds),
      (_) {
        if (!_hasFocus && widget.items.isNotEmpty) {
          setState(() => _current = (_current + 1) % widget.items.length);
        }
      },
    );
  }

  Media? get _displayed {
    if (widget.focusedMedia != null) return widget.focusedMedia;
    if (widget.items.isEmpty) return null;
    return widget.items[_current % widget.items.length];
  }

  void _play(BuildContext context) {
    final media = _displayed;
    if (media == null) return;
    resumeOrPlay(context, ref, media);
  }

  void _openDetail(BuildContext context) {
    final media = _displayed;
    if (media == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaDetailPage(
        media: media,
        animeSamaTitle: media.animeSamaTitle,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final media = _displayed;
    if (media == null) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    return Focus(
      onFocusChange: (v) => setState(() => _hasFocus = v),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            widget.items.length > 1) {
          setState(() => _current =
              (_current - 1 + widget.items.length) % widget.items.length);
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.items.length > 1) {
          setState(() =>
              _current = (_current + 1) % widget.items.length);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: size.width,
        height: size.height - 64, // hauteur totale moins TopBar
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- Fond : cover de l'anime ---
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: KeyedSubtree(
                key: ValueKey(media.mediaId),
                child: AnimeSamaImage(
                  media: media,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),

            // --- Gradient noir bas → transparent haut ---
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black,
                  ],
                ),
              ),
            ),

            // --- Gradient noir gauche (pour le texte) ---
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: [0.4, 1.0],
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),

            // --- Contenu texte + boutons ---
            Positioned(
              left: 64,
              bottom: 80,
              right: size.width * 0.45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Titre
                  Text(
                    media.title.preferred,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Genres
                  if (media.genres.isNotEmpty)
                    Text(
                      media.genres.take(3).join(' • '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Boutons
                  Row(
                    children: [
                      TvFocusable(
                        autofocus: true,
                        onPressed: () => _play(context),
                        child: FilledButton.icon(
                          onPressed: () => _play(context),
                          icon: const Icon(Icons.play_arrow, size: 22),
                          label: const Text('Lire',
                              style: TextStyle(fontSize: 16)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TvFocusable(
                        onPressed: () => _openDetail(context),
                        child: OutlinedButton.icon(
                          onPressed: () => _openDetail(context),
                          icon: const Icon(Icons.info_outline, size: 20,
                              color: Colors.white),
                          label: const Text('Détails',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- Indicateurs de slide (points) ---
            if (widget.items.length > 1)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < widget.items.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _current ? 24 : 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i == _current
                              ? Colors.white
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Étape 3 : Vérifier la signature de resumeOrPlay dans resume_helper.dart**

```bash
grep -n "resumeOrPlay\|Future<void> resumeOrPlay" lib/src/ui/pages/resume_helper.dart
```

Si la signature est différente, adapter l'appel dans `_play()`.

- [ ] **Étape 4 : Analyser**

```bash
dart analyze lib/src/ui/tv/widgets/tv_hero_banner.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 5 : Commit**

```bash
git add lib/src/ui/tv/widgets/tv_hero_banner.dart
git commit -m "feat(tv): TvHeroBanner — fullscreen hero with gradient + Lire/Détails buttons"
```

---

## Task 5 : TvContentRow — rangée horizontale 16:9

**Files:**
- Create: `lib/src/ui/tv/widgets/tv_content_row.dart`

Rangée avec titre à gauche + `ListView` horizontal. Tuiles 300×170px (16:9), `TvFocusable` avec scale ×1.1. Au focus d'une tuile, appelle `onFocused(media)` pour que `HomepageTv` mette à jour le fond du hero.

- [ ] **Étape 1 : Vérifier la signature de MediaCard**

```bash
grep -n "class MediaCard\|MediaCard(" lib/src/ui/widgets/media_card.dart | head -5
```

- [ ] **Étape 2 : Créer lib/src/ui/tv/widgets/tv_content_row.dart**

```dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/media.dart';
import '../../widgets/anime_sama_image.dart';
import '../../widgets/tv_focusable.dart';
import '../../pages/media_detail_page.dart';
import '../../pages/resume_helper.dart';

/// Rangée horizontale défilante style Netflix pour Android TV.
/// Tuiles 16:9 (300×170px), focus avec scale ×1.1.
/// [onFocused] est appelé quand une tuile prend le focus — permet au hero
/// parent de mettre à jour son fond.
class TvContentRow extends ConsumerWidget {
  final String title;
  final List<Media> items;
  final bool withResume;
  final void Function(Media)? onFocused;

  const TvContentRow({
    super.key,
    required this.title,
    required this.items,
    this.withResume = false,
    this.onFocused,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 200, // 170px tuile + padding focus
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 40),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final media = items[i];
                return _TvTile(
                  media: media,
                  withResume: withResume,
                  onFocused: onFocused,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TvTile extends ConsumerWidget {
  final Media media;
  final bool withResume;
  final void Function(Media)? onFocused;

  const _TvTile({
    required this.media,
    required this.withResume,
    this.onFocused,
  });

  void _open(BuildContext context, WidgetRef ref) {
    if (withResume) {
      resumeOrPlay(context, ref, media);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          media: media,
          animeSamaTitle: media.animeSamaTitle,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: TvFocusable(
        onPressed: () => _open(context, ref),
        onFocused: () => onFocused?.call(media),
        child: GestureDetector(
          onTap: () => _open(context, ref),
          child: SizedBox(
            width: 300,
            height: 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimeSamaImage(
                    media: media,
                    fit: BoxFit.cover,
                    width: 300,
                    height: 170,
                  ),
                  // Gradient bas pour le titre
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 1.0],
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  // Titre en bas
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      media.title.preferred,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Icône lecture si withResume
                  if (withResume)
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Étape 3 : Analyser**

```bash
dart analyze lib/src/ui/tv/widgets/tv_content_row.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 4 : Commit**

```bash
git add lib/src/ui/tv/widgets/tv_content_row.dart
git commit -m "feat(tv): TvContentRow — horizontal 16:9 tiles with focus callback"
```

---

## Task 6 : HomepageTv — assemblage hero + rangées

**Files:**
- Modify: `lib/src/ui/tv/home_page_tv.dart` (remplacer le stub)

La page assemble `TvHeroBanner` + rangées `TvContentRow`. Un `ValueNotifier<Media?>` local gère `focusedMedia` — quand une tuile d'une rangée prend le focus, le fond du hero change. La page est un `ConsumerStatefulWidget` qui réutilise les providers existants de `home_page.dart` (importés directement).

- [ ] **Étape 1 : Vérifier les noms des providers dans home_page.dart**

```bash
grep -n "^final _" lib/src/ui/pages/home_page.dart | head -15
```

Les providers `_continueWatchingProvider`, `_recentlyReleasedProvider`, `_recentlyWatchedProvider`, `_classicsProvider`, `_watchedGenresProvider`, `_byGenreProvider` sont privés (`_`). Il faut soit les rendre publics, soit les redéfinir dans `home_page_tv.dart`.

La solution propre : les **extraire dans un fichier partagé** `lib/src/ui/pages/home_providers.dart` (public). Modifier `home_page.dart` pour les importer depuis là.

- [ ] **Étape 2 : Extraire les providers dans home_providers.dart**

Créer `lib/src/ui/pages/home_providers.dart` et y déplacer (couper/coller) les providers suivants depuis `home_page.dart` :
- `_completedIdsProvider` → `completedIdsProvider`
- `_continueWatchingProvider` → `continueWatchingProvider`
- `_recentlyReleasedProvider` → `recentlyReleasedProvider`
- `_recentlyWatchedProvider` → `recentlyWatchedProvider`
- `_classicsProvider` → `classicsProvider`
- `_byGenreProvider` → `byGenreProvider`
- `_watchedGenresProvider` → `watchedGenresProvider`
- `_libraryFilterProvider` → `libraryFilterProvider`
- `_recommendedProvider` → `recommendedProvider`
- La fonction helper `_itemsToMedia` → `itemsToMedia`

Dans `home_page.dart`, ajouter l'import et remplacer les références `_xxxProvider` par `xxxProvider`.

- [ ] **Étape 3 : Analyser après extraction**

```bash
dart analyze lib/src/ui/pages/home_page.dart lib/src/ui/pages/home_providers.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 4 : Remplacer le stub HomepageTv**

Remplacer entièrement `lib/src/ui/tv/home_page_tv.dart` :

```dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/media.dart';
import '../pages/home_providers.dart';
import 'widgets/tv_content_row.dart';
import 'widgets/tv_hero_banner.dart';

class HomepageTv extends ConsumerStatefulWidget {
  const HomepageTv({super.key});

  @override
  ConsumerState<HomepageTv> createState() => _HomepageTvState();
}

class _HomepageTvState extends ConsumerState<HomepageTv> {
  // Media focusé dans une rangée — surcharge le fond du hero.
  Media? _focusedMedia;
  // ScrollController pour remonter au hero avec le D-pad.
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onRowFocus(Media media) {
    if (mounted) setState(() => _focusedMedia = media);
  }

  void _onHeroFocus() {
    if (mounted) setState(() => _focusedMedia = null);
  }

  @override
  Widget build(BuildContext context) {
    final heroItems = ref.watch(recentlyReleasedProvider).maybeWhen(
          data: (items) => items,
          orElse: () => <Media>[],
        );
    final continueItems = ref.watch(continueWatchingProvider).maybeWhen(
          data: (items) => items,
          orElse: () => <Media>[],
        );
    final recentItems = ref.watch(recentlyWatchedProvider).maybeWhen(
          data: (items) => items,
          orElse: () => <Media>[],
        );
    final classicItems = ref.watch(classicsProvider).maybeWhen(
          data: (items) => items,
          orElse: () => <Media>[],
        );
    final genres = ref.watch(watchedGenresProvider).maybeWhen(
          data: (g) => g.take(3).toList(),
          orElse: () => <String>[],
        );

    return Focus(
      onKeyEvent: (_, event) {
        // Flèche haut depuis le début du contenu → remonter au hero.
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (_scrollController.offset <= 0) {
            _onHeroFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ColoredBox(
        color: Colors.black,
        child: ListView(
          controller: _scrollController,
          children: [
            // --- Hero plein écran ---
            Focus(
              onFocusChange: (focused) {
                if (focused) _onHeroFocus();
              },
              child: TvHeroBanner(
                items: heroItems,
                focusedMedia: _focusedMedia,
              ),
            ),

            const SizedBox(height: 24),

            // --- Rangées ---
            if (continueItems.isNotEmpty)
              TvContentRow(
                title: 'Continuer à regarder',
                items: continueItems,
                withResume: true,
                onFocused: _onRowFocus,
              ),
            if (recentItems.isNotEmpty)
              TvContentRow(
                title: 'Regardé récemment',
                items: recentItems,
                withResume: true,
                onFocused: _onRowFocus,
              ),
            TvContentRow(
              title: 'Nouvelles sorties',
              items: heroItems,
              onFocused: _onRowFocus,
            ),
            if (classicItems.isNotEmpty)
              TvContentRow(
                title: 'Les classiques',
                items: classicItems,
                onFocused: _onRowFocus,
              ),
            for (final genre in genres)
              _GenreRow(
                genre: genre,
                onFocused: _onRowFocus,
              ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

/// Rangée par genre — charge les items via byGenreProvider.
class _GenreRow extends ConsumerWidget {
  final String genre;
  final void Function(Media) onFocused;

  const _GenreRow({required this.genre, required this.onFocused});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(byGenreProvider(genre)).maybeWhen(
          data: (i) => i,
          orElse: () => <Media>[],
        );
    if (items.isEmpty) return const SizedBox.shrink();
    return TvContentRow(
      title: genre,
      items: items,
      onFocused: onFocused,
    );
  }
}
```

- [ ] **Étape 5 : Analyser tout**

```bash
dart analyze lib/src/ui/tv/ lib/src/ui/pages/home_providers.dart lib/src/ui/pages/home_page.dart
```

Résultat attendu : `No issues found!`

- [ ] **Étape 6 : Lancer les tests**

```bash
dart test
```

Résultat attendu : tous les tests Dart purs passent (162+).

- [ ] **Étape 7 : Commit**

```bash
git add lib/src/ui/tv/ lib/src/ui/pages/home_providers.dart lib/src/ui/pages/home_page.dart
git commit -m "feat(tv): HomepageTv — Netflix-style hero + horizontal rows with focus-to-hero sync"
```

---

## Task 7 : Vérification finale + push

**Files:** aucun nouveau fichier

- [ ] **Étape 1 : Analyse complète**

```bash
dart analyze lib/
```

Résultat attendu : `No issues found!`

- [ ] **Étape 2 : Tests**

```bash
dart test
```

Résultat attendu : 162+ tests passent.

- [ ] **Étape 3 : Vérifier la structure TV créée**

```bash
find lib/src/ui/tv -type f | sort
```

Résultat attendu :
```
lib/src/ui/tv/app_shell_tv.dart
lib/src/ui/tv/home_page_tv.dart
lib/src/ui/tv/widgets/tv_content_row.dart
lib/src/ui/tv/widgets/tv_hero_banner.dart
```

- [ ] **Étape 4 : Vérifier qu'aucun if (isTv) n'a été ajouté dans le code commun**

```bash
grep -rn "isTvProvider\|isTv ==" lib/src/ui/tv/
```

Résultat attendu : aucune ligne (les fichiers TV n'ont pas besoin de checker `isTv`).

- [ ] **Étape 5 : Push**

```bash
git push
```

---

## Récapitulatif des fichiers après ce plan

```
lib/src/
├── app/
│   ├── app_platform.dart          ← NOUVEAU : enum AppPlatform + provider
│   └── providers.dart             ← +import/export app_platform
├── ui/
│   ├── app_shell.dart             ← AppShellDesktop (renommé) + routeur AppShell
│   ├── tv/                        ← NOUVEAU dossier
│   │   ├── app_shell_tv.dart      ← shell TV (TvTopBar + IndexedStack)
│   │   ├── home_page_tv.dart      ← accueil TV Netflix-style
│   │   └── widgets/
│   │       ├── tv_hero_banner.dart ← hero plein écran + gradient
│   │       └── tv_content_row.dart ← rangée 16:9 défilante
│   └── pages/
│       ├── home_page.dart         ← inchangé (importe home_providers)
│       └── home_providers.dart    ← NOUVEAU : providers extraits de home_page
└── main.dart                      ← +appPlatformProvider override
```
