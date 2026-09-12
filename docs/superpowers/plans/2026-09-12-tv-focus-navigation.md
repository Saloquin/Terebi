# Refonte de la navigation & du focus Android TV — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre la navigation D-pad de l'UI Android TV fluide — la page suit toujours le focus (scroll-vers-focus ancré en haut style Netflix), le highlight est net (zoom + bordure blanche), et le retour navbar↔contenu ne bloque plus.

**Architecture:** Deux primitives réutilisables. (1) `TvFocusable` refondu appelle `Scrollable.ensureVisible` au gain du focus et remonte en cascade tous les `Scrollable` ancêtres (vertical + horizontal). (2) `TvFocusScope` gère la traversée D-pad : mémorisation de colonne entre rangées, remontée navbar via `arrowUp`, retour au dernier élément focalisé via `arrowDown`. Ces primitives sont ensuite câblées dans les 5 zones TV.

**Tech Stack:** Flutter (natif, `Scrollable.ensureVisible` + `FocusTraversalGroup`), Riverpod, tests widget via `flutter_test` exécutés dans le conteneur Docker `terebi-ci` (`./scripts/flutter-ci.sh test`) car `flutter_tester` est bloqué par l'EDR du poste.

---

## Contexte technique clé

- **Lancer les tests :** `./scripts/flutter-ci.sh test` (jamais `flutter test` en local — bloqué EDR). Nécessite l'image `terebi-ci` construite via `docker build -f Dockerfile.flutter-ci -t terebi-ci .`.
- **Lancer un seul fichier de test :** `./scripts/flutter-ci.sh test test/ui/tv_focusable_test.dart`.
- **Analyse statique :** `./scripts/flutter-ci.sh analyze`.
- **Package du projet :** `terebi` (imports `package:terebi/src/...`).
- **Pattern de test widget établi** (voir `test/ui/widget_test.dart`) : `ProviderScope(overrides: [...])` + `MaterialApp(home: Scaffold(body: ...))`, puis `await tester.pump()`.
- **Couleur d'accent :** `Theme.of(context).colorScheme.primary` — mais le highlight cible est **blanc** (décision produit).

## Structure des fichiers

| Fichier | Rôle | Action |
|---------|------|--------|
| `lib/src/ui/widgets/tv_focusable.dart` | Primitive focus : highlight + scroll auto | Modifier |
| `lib/src/ui/tv/widgets/tv_focus_scope.dart` | Primitive traversée D-pad + mémorisation colonne + pont navbar | Créer |
| `lib/src/ui/tv/app_shell_tv.dart` | Shell : navbar ↔ contenu | Modifier |
| `lib/src/ui/tv/home_page_tv.dart` | Accueil (rangées) | Modifier |
| `lib/src/ui/tv/catalog_page_tv.dart` | Catalogue (grille + genres) | Modifier |
| `lib/src/ui/tv/library_page_tv.dart` | Bibliothèque (grille) | Modifier |
| `lib/src/ui/tv/media_detail_page_tv.dart` | Détail (boutons + panneau) | Modifier |
| `test/ui/tv_focusable_test.dart` | Tests de `TvFocusable` | Créer |
| `test/ui/tv_focus_scope_test.dart` | Tests de `TvFocusScope` | Créer |

---

## Task 1 : `TvFocusable` — highlight blanc + paramètre `scrollAlignment`

**Files:**
- Modify: `lib/src/ui/widgets/tv_focusable.dart`
- Test: `test/ui/tv_focusable_test.dart`

- [ ] **Step 1 : Écrire le test de highlight (échoue)**

Créer `test/ui/tv_focusable_test.dart` :

```dart
/// Tests de TvFocusable : highlight au focus + scroll-vers-focus.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/ui/widgets/tv_focusable.dart';

void main() {
  group('TvFocusable — highlight', () {
    testWidgets('scale 1.0 sans focus, 1.08 avec focus', (tester) async {
      final node = FocusNode();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: node,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ));

      AnimatedScale scaleOf() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleOf().scale, 1.0);

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(scaleOf().scale, 1.08);
    });

    testWidgets('bordure blanche visible au focus', (tester) async {
      final node = FocusNode();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: node,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ));
      node.requestFocus();
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border!.top.color, Colors.white);
    });

    testWidgets('OK/select déclenche onPressed', (tester) async {
      final node = FocusNode();
      var pressed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: node,
            onPressed: () => pressed = true,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ));
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(pressed, isTrue);
    });
  });
}
```

- [ ] **Step 2 : Lancer le test, vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/ui/tv_focusable_test.dart`
Expected: FAIL — le scale actuel est `1.05`, la couleur de bordure est `colorScheme.primary` (pas `Colors.white`).

- [ ] **Step 3 : Modifier `TvFocusable` (highlight blanc + scale 1.08 + scrollAlignment)**

Remplacer le contenu de `lib/src/ui/widgets/tv_focusable.dart` par :

```dart
/// Domaine UI — wrapper de focus clavier/D-pad réutilisable.
///
/// Au gain du focus : (1) ancre l'élément dans ses Scrollable ancêtres via
/// [Scrollable.ensureVisible] (ancrage haut style Netflix), (2) applique un
/// highlight zoom + bordure blanche + glow. Universel (desktop, mobile, TV) —
/// Flutter masque le highlight en mode souris/tactile via
/// [FocusManager.highlightMode].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;

  /// Callback déclenché par la touche OK/Centre (télécommande) ou Entrée.
  final VoidCallback? onPressed;

  /// Appelé quand le focus est acquis — effets métier optionnels (ex. hero
  /// banner). Le scroll-vers-focus est géré en interne, pas via ce callback.
  final VoidCallback? onFocused;

  final bool autofocus;
  final FocusNode? focusNode;

  /// Alignement cible dans le Scrollable au gain du focus.
  /// 0.12 = ancrage haut (rangées verticales, grilles). 0.5 = centré.
  final double scrollAlignment;

  const TvFocusable({
    super.key,
    required this.child,
    this.onPressed,
    this.onFocused,
    this.autofocus = false,
    this.focusNode,
    this.scrollAlignment = 0.12,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _hasFocus = false;

  void _onFocusChange(bool focused) {
    setState(() => _hasFocus = focused);
    if (focused) {
      widget.onFocused?.call();
      _ensureVisible();
    }
  }

  void _ensureVisible() {
    // N'agit que dans un contexte scrollable — évite tout crash hors Scrollable
    // (ex. boutons de la page détail). Flutter remonte en cascade tous les
    // Scrollable ancêtres (vertical ET horizontal).
    if (Scrollable.maybeOf(context) == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: widget.scrollAlignment,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) &&
            widget.onPressed != null) {
          widget.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _hasFocus ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4 : Lancer le test, vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/ui/tv_focusable_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5 : Analyse statique**

Run: `./scripts/flutter-ci.sh analyze`
Expected: aucune nouvelle erreur/warning sur `tv_focusable.dart`.

- [ ] **Step 6 : Commit**

```bash
git add lib/src/ui/widgets/tv_focusable.dart test/ui/tv_focusable_test.dart
git commit -m "feat(tv): TvFocusable highlight blanc + scrollAlignment"
```

---

## Task 2 : `TvFocusable` — scroll-vers-focus vérifié dans une liste

**Files:**
- Test: `test/ui/tv_focusable_test.dart` (ajout d'un groupe)

- [ ] **Step 1 : Ajouter le test de scroll-vers-focus (échoue si régression)**

Ajouter ce groupe dans `test/ui/tv_focusable_test.dart`, avant la dernière `}` de `main()` :

```dart
  group('TvFocusable — scroll-vers-focus', () {
    testWidgets('focus sur une tuile hors écran la ramène en vue',
        (tester) async {
      final controller = ScrollController();
      final lastNode = FocusNode();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: ListView(
              controller: controller,
              children: [
                for (int i = 0; i < 20; i++)
                  TvFocusable(
                    focusNode: i == 19 ? lastNode : null,
                    child: const SizedBox(height: 100, width: 100),
                  ),
              ],
            ),
          ),
        ),
      ));

      // Au départ, la liste est en haut (offset 0), la 20e tuile est hors vue.
      expect(controller.offset, 0);

      lastNode.requestFocus();
      await tester.pumpAndSettle();

      // ensureVisible a défilé la liste pour rendre la 20e tuile visible.
      expect(controller.offset, greaterThan(0));
    });

    testWidgets('sans Scrollable ancêtre, aucun crash au focus',
        (tester) async {
      final node = FocusNode();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: node,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ));
      node.requestFocus();
      await tester.pumpAndSettle();
      // Pas d'exception levée = test réussi.
      expect(tester.takeException(), isNull);
    });
  });
```

- [ ] **Step 2 : Lancer le test, vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/ui/tv_focusable_test.dart`
Expected: PASS (5 tests au total). L'implémentation de la Task 1 satisfait déjà ces tests — ils verrouillent le comportement contre les régressions.

- [ ] **Step 3 : Commit**

```bash
git add test/ui/tv_focusable_test.dart
git commit -m "test(tv): verrouille le scroll-vers-focus de TvFocusable"
```

---

## Task 3 : `TvFocusScope` — pont navbar↔contenu (retour déterministe)

**Files:**
- Create: `lib/src/ui/tv/widgets/tv_focus_scope.dart`
- Test: `test/ui/tv_focus_scope_test.dart`

**Note d'architecture :** `TvFocusScope` remplace l'`InheritedWidget` `TvNavFocusRequest` et le `requestFocus(FocusNode())` vide. Il expose deux `FocusScopeNode` (navbar + contenu) et deux méthodes de pont : `focusNavBar()` et `focusContent()`. `focusContent()` restaure le focus sur le **dernier** nœud focalisé du scope contenu (comportement natif de `FocusScopeNode` qui mémorise son `focusedChild`), ce qui corrige le blocage navbar.

- [ ] **Step 1 : Écrire le test du pont (échoue)**

Créer `test/ui/tv_focus_scope_test.dart` :

```dart
/// Tests de TvFocusScope : pont navbar ↔ contenu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terebi/src/ui/tv/widgets/tv_focus_scope.dart';

void main() {
  group('TvFocusScope — pont navbar/contenu', () {
    testWidgets('focusContent restaure le dernier enfant focalisé',
        (tester) async {
      final controller = TvFocusController();
      final navNode = FocusNode(debugLabel: 'nav');
      final contentA = FocusNode(debugLabel: 'contentA');
      final contentB = FocusNode(debugLabel: 'contentB');

      await tester.pumpWidget(MaterialApp(
        home: TvFocusScope(
          controller: controller,
          navBar: Focus(focusNode: navNode, child: const SizedBox()),
          content: Column(
            children: [
              Focus(focusNode: contentA, child: const SizedBox()),
              Focus(focusNode: contentB, child: const SizedBox()),
            ],
          ),
        ),
      ));

      // L'utilisateur focalise contentB, puis remonte à la navbar.
      contentB.requestFocus();
      await tester.pump();
      controller.focusNavBar();
      await tester.pump();
      expect(navNode.hasFocus, isTrue);

      // arrowDown : le focus revient à contentB (dernier focalisé), pas contentA.
      controller.focusContent();
      await tester.pump();
      expect(contentB.hasFocus, isTrue);
    });
  });
}
```

- [ ] **Step 2 : Lancer le test, vérifier l'échec**

Run: `./scripts/flutter-ci.sh test test/ui/tv_focus_scope_test.dart`
Expected: FAIL — `tv_focus_scope.dart` n'existe pas (erreur d'import).

- [ ] **Step 3 : Créer `TvFocusScope` + `TvFocusController`**

Créer `lib/src/ui/tv/widgets/tv_focus_scope.dart` :

```dart
/// Domaine UI TV — pont de focus entre la navbar et le contenu.
///
/// Sépare le focus en deux [FocusScopeNode] (navbar + contenu) et expose un
/// [TvFocusController] pour passer de l'un à l'autre au D-pad :
/// - [TvFocusController.focusNavBar] : arrowUp depuis le sommet du contenu.
/// - [TvFocusController.focusContent] : arrowDown depuis la navbar — restaure
///   le DERNIER élément focalisé du contenu (corrige le blocage navbar).
library;

import 'package:flutter/material.dart';

/// Contrôleur partagé entre le shell TV et ses pages pour piloter le pont.
class TvFocusController {
  final FocusScopeNode navScope = FocusScopeNode(debugLabel: 'tvNavScope');
  final FocusScopeNode contentScope =
      FocusScopeNode(debugLabel: 'tvContentScope');

  /// Donne le focus à la navbar.
  void focusNavBar() => navScope.requestFocus();

  /// Rend le focus au contenu, sur son dernier enfant focalisé si connu.
  void focusContent() {
    final last = contentScope.focusedChild;
    if (last != null) {
      last.requestFocus();
    } else {
      contentScope.requestFocus();
    }
  }

  void dispose() {
    navScope.dispose();
    contentScope.dispose();
  }
}

/// Enveloppe navbar + contenu dans deux FocusScope distincts pilotés par
/// [controller].
class TvFocusScope extends StatelessWidget {
  final TvFocusController controller;
  final Widget navBar;
  final Widget content;

  const TvFocusScope({
    super.key,
    required this.controller,
    required this.navBar,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FocusScope(node: controller.navScope, child: navBar),
        Expanded(
          child: FocusScope(node: controller.contentScope, child: content),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4 : Lancer le test, vérifier le succès**

Run: `./scripts/flutter-ci.sh test test/ui/tv_focus_scope_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5 : Commit**

```bash
git add lib/src/ui/tv/widgets/tv_focus_scope.dart test/ui/tv_focus_scope_test.dart
git commit -m "feat(tv): TvFocusScope + TvFocusController (pont navbar/contenu)"
```

---

## Task 4 : Câbler `TvFocusScope` dans `AppShellTv`

**Files:**
- Modify: `lib/src/ui/tv/app_shell_tv.dart`

**Objectif :** remplacer `_navFocusScope` + `TvNavFocusRequest` + le `requestFocus(FocusNode())` vide par `TvFocusController`. Fournir le contrôleur aux pages via un `InheritedWidget` léger.

- [ ] **Step 1 : Remplacer l'InheritedWidget et l'état du shell**

Dans `lib/src/ui/tv/app_shell_tv.dart`, remplacer la classe `TvNavFocusRequest` (lignes 20-36) par :

```dart
/// Fournit le [TvFocusController] du shell aux pages TV descendantes.
class TvFocusScopeProvider extends InheritedWidget {
  final TvFocusController controller;

  const TvFocusScopeProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  static TvFocusController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TvFocusScopeProvider>()
      ?.controller;

  @override
  bool updateShouldNotify(TvFocusScopeProvider oldWidget) =>
      controller != oldWidget.controller;
}
```

Ajouter l'import en tête de fichier (après les autres imports `import '...';`) :

```dart
import 'widgets/tv_focus_scope.dart';
```

- [ ] **Step 2 : Remplacer `_navFocusScope` par le contrôleur dans l'état**

Dans `_AppShellTvState`, remplacer la ligne `final _navFocusScope = FocusScopeNode();` (ligne 55) par :

```dart
  final _focus = TvFocusController();
```

Remplacer la méthode `dispose` (lignes 70-74) par :

```dart
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }
```

Remplacer la méthode `_focusNav` (lignes 94-97) par :

```dart
  // Appelé par le contenu quand l'utilisateur appuie arrowUp depuis le sommet.
  void _focusNav() => _focus.focusNavBar();
```

- [ ] **Step 3 : Réécrire le `build` du shell autour de `TvFocusScope`**

Remplacer le corps du `Scaffold` dans `build` (le `body: Column(...)` complet, lignes 107-138) par :

```dart
    return Scaffold(
      backgroundColor: Colors.black,
      body: TvFocusScopeProvider(
        controller: _focus,
        child: TvFocusScope(
          controller: _focus,
          navBar: _TvTopBar(
            destinations: _destinations,
            selectedIndex: _index,
            hasNewEpisode: hasNewEpisode,
            onSelect: (i) {
              _onSelect(i);
              // Après sélection d'un onglet, rendre le focus au contenu.
              _focus.focusContent();
            },
            onArrowDown: _focus.focusContent,
          ),
          content: _TvContentArea(
            index: _index,
            destinations: _destinations,
          ),
        ),
      ),
    );
```

- [ ] **Step 4 : Ajouter `onArrowDown` à `_TvTopBar` et gérer la touche**

Dans `_TvTopBar`, ajouter le champ et le paramètre. Remplacer la déclaration de la classe et son constructeur (lignes 185-197) par :

```dart
class _TvTopBar extends StatelessWidget {
  final List<_Destination> destinations;
  final int selectedIndex;
  final bool hasNewEpisode;
  final void Function(int) onSelect;
  final VoidCallback onArrowDown;

  const _TvTopBar({
    required this.destinations,
    required this.selectedIndex,
    required this.hasNewEpisode,
    required this.onSelect,
    required this.onArrowDown,
  });
```

Envelopper le `Container` retourné par le `build` de `_TvTopBar` dans un `Focus` qui intercepte `arrowDown`. Ajouter l'import `import 'package:flutter/services.dart';` s'il n'est pas déjà présent (il l'est, ligne 4). Remplacer `return Container(` (ligne 200) par :

```dart
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          onArrowDown();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
```

Et fermer le `Focus` : à la fin du `build` de `_TvTopBar`, après la parenthèse fermante du `Container` (juste avant le `;` final), ajouter une parenthèse fermante `)` pour le `Focus`. La fin devient :

```dart
        ],
      ),
    ),
    );
  }
```

- [ ] **Step 5 : Simplifier `_TvContentArea` (retirer l'interception arrowUp morte)**

Remplacer entièrement la classe `_TvContentArea` (lignes 143-183) par :

```dart
/// Zone de contenu du shell. La remontée vers la navbar est gérée par les
/// pages (arrowUp au sommet) via [TvFocusScopeProvider].
class _TvContentArea extends StatelessWidget {
  final int index;
  final List<_Destination> destinations;

  const _TvContentArea({
    required this.index,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: [for (final d in destinations) d.page],
    );
  }
}
```

- [ ] **Step 6 : Analyse statique**

Run: `./scripts/flutter-ci.sh analyze`
Expected: aucune erreur. Si `home_page_tv.dart` référence encore `TvNavFocusRequest`, l'analyse le signalera — c'est corrigé en Task 5.

- [ ] **Step 7 : Commit**

```bash
git add lib/src/ui/tv/app_shell_tv.dart
git commit -m "refactor(tv): AppShellTv utilise TvFocusController (retire FocusNode vide)"
```

---

## Task 5 : Accueil — brancher la remontée navbar sur le nouveau contrôleur

**Files:**
- Modify: `lib/src/ui/tv/home_page_tv.dart`

**Objectif :** remplacer l'appel à `TvNavFocusRequest.maybeOf(context)?.requestNavFocus()` par `TvFocusScopeProvider.maybeOf(context)?.focusNavBar()`. Le scroll-vers-focus est déjà assuré par `TvFocusable` (via `TvContentRow`).

- [ ] **Step 1 : Remplacer l'appel de remontée navbar**

Dans `lib/src/ui/tv/home_page_tv.dart`, dans le `Focus.onKeyEvent` du `build` (lignes 61-73), remplacer :

```dart
          // Remonte le focus à la navbar TV
          TvNavFocusRequest.maybeOf(context)?.requestNavFocus();
          _onHeroFocus();
```

par :

```dart
          // Remonte le focus à la navbar TV
          TvFocusScopeProvider.maybeOf(context)?.focusNavBar();
          _onHeroFocus();
```

L'import `import 'app_shell_tv.dart';` (ligne 9) fournit déjà `TvFocusScopeProvider`.

- [ ] **Step 2 : Analyse statique**

Run: `./scripts/flutter-ci.sh analyze`
Expected: aucune erreur sur `home_page_tv.dart`.

- [ ] **Step 3 : Vérifier que la suite de tests widget existante passe toujours**

Run: `./scripts/flutter-ci.sh test`
Expected: PASS (les tests `HomePage` existants ciblent la version desktop `home_page.dart`, non impactée ; les nouveaux tests TV passent).

- [ ] **Step 4 : Commit**

```bash
git add lib/src/ui/tv/home_page_tv.dart
git commit -m "refactor(tv): accueil utilise TvFocusScopeProvider pour la remontée navbar"
```

---

## Task 6 : Rangées d'accueil — marge de zoom propre (retirer les +30px ad hoc)

**Files:**
- Modify: `lib/src/ui/tv/widgets/tv_content_row.dart`

**Objectif :** le zoom 1.08 déborde la tuile. Aujourd'hui compensé par `rowH = tileH + 30`. On réserve la marge proprement via un `Padding` vertical autour de la rangée, et on garde une hauteur de rangée = hauteur tuile + marge symétrique explicite.

- [ ] **Step 1 : Remplacer le calcul de hauteur et le padding de la rangée**

Dans `lib/src/ui/tv/widgets/tv_content_row.dart`, remplacer le commentaire + calcul (lignes 50-52) :

```dart
    // +30px pour bordure TvFocusable + AnimatedScale overflow
    final rowH = tileH + 30;
```

par :

```dart
    // Marge verticale réservée au zoom (1.08) + bordure 3px du TvFocusable,
    // pour éviter le clipping du highlight sans gonfler la logique de layout.
    const focusMargin = 24.0;
    final rowH = tileH + focusMargin * 2;
```

- [ ] **Step 2 : Centrer les tuiles verticalement dans la rangée**

Dans le même fichier, le `SizedBox(height: rowH, child: ListView.builder(...))` (lignes 69-84) : la `ListView` horizontale doit centrer ses tuiles dans la hauteur `rowH`. Remplacer le `itemBuilder` (lignes 75-83) par une version qui centre chaque tuile :

```dart
              itemBuilder: (context, i) => Center(
                child: _TvTile(
                  media: items[i],
                  tileWidth: tileW,
                  tileHeight: tileH,
                  withResume: withResume,
                  onFocused: onFocused,
                  autofocus: false,
                ),
              ),
```

**Note :** `autofocus: false` sur toutes les tuiles ici — l'autofocus unique est posé à la Task 7.

- [ ] **Step 3 : Analyse statique**

Run: `./scripts/flutter-ci.sh analyze`
Expected: aucune erreur sur `tv_content_row.dart`.

- [ ] **Step 4 : Commit**

```bash
git add lib/src/ui/tv/widgets/tv_content_row.dart
git commit -m "fix(tv): marge de zoom propre dans les rangées (retire +30px ad hoc)"
```

---

## Task 7 : Autofocus unique sur l'accueil

**Files:**
- Modify: `lib/src/ui/tv/widgets/tv_content_row.dart`
- Modify: `lib/src/ui/tv/home_page_tv.dart`

**Objectif :** un seul `autofocus: true` sur toute la page (1re tuile de la 1re rangée), au lieu de `i == 0` sur chaque rangée. On ajoute un paramètre `autofocusFirst` à `TvContentRow`, activé uniquement pour la première rangée affichée.

- [ ] **Step 1 : Ajouter `autofocusFirst` à `TvContentRow`**

Dans `lib/src/ui/tv/widgets/tv_content_row.dart`, ajouter le champ à `TvContentRow`. Remplacer les champs + constructeur (lignes 31-42) par :

```dart
  final String title;
  final List<Media> items;
  final bool withResume;
  final void Function(Media)? onFocused;

  /// Si vrai, la première tuile de cette rangée reçoit l'autofocus initial.
  /// Ne doit être vrai que pour UNE seule rangée de la page.
  final bool autofocusFirst;

  const TvContentRow({
    super.key,
    required this.title,
    required this.items,
    this.withResume = false,
    this.onFocused,
    this.autofocusFirst = false,
  });
```

Dans le `itemBuilder` (modifié en Task 6), passer l'autofocus à la 1re tuile :

```dart
                child: _TvTile(
                  media: items[i],
                  tileWidth: tileW,
                  tileHeight: tileH,
                  withResume: withResume,
                  onFocused: onFocused,
                  autofocus: autofocusFirst && i == 0,
                ),
```

- [ ] **Step 2 : Activer `autofocusFirst` sur la première rangée de l'accueil**

Dans `lib/src/ui/tv/home_page_tv.dart`, la première `TvContentRow` affichée dépend des données. Pour rendre l'autofocus déterministe, l'affecter à la rangée « Continuer à regarder » si présente, sinon la première rangée non vide. Remplacer le bloc des rangées (lignes 89-119) par :

```dart
            if (continueItems.isNotEmpty)
              TvContentRow(
                title: 'Continuer à regarder',
                items: continueItems,
                withResume: true,
                onFocused: _onRowFocus,
                autofocusFirst: true,
              ),
            if (recentItems.isNotEmpty)
              TvContentRow(
                title: 'Regardé récemment',
                items: recentItems,
                withResume: true,
                onFocused: _onRowFocus,
                autofocusFirst: continueItems.isEmpty,
              ),
            if (heroItems.isNotEmpty)
              TvContentRow(
                title: 'Nouvelles sorties',
                items: heroItems,
                onFocused: _onRowFocus,
                autofocusFirst: continueItems.isEmpty && recentItems.isEmpty,
              ),
            if (classicItems.isNotEmpty)
              TvContentRow(
                title: 'Les classiques',
                items: classicItems,
                onFocused: _onRowFocus,
                autofocusFirst: continueItems.isEmpty &&
                    recentItems.isEmpty &&
                    heroItems.isEmpty,
              ),
            for (final genre in genres)
              _GenreRow(
                genre: genre,
                onFocused: _onRowFocus,
              ),
```

- [ ] **Step 3 : Analyse statique**

Run: `./scripts/flutter-ci.sh analyze`
Expected: aucune erreur.

- [ ] **Step 4 : Commit**

```bash
git add lib/src/ui/tv/widgets/tv_content_row.dart lib/src/ui/tv/home_page_tv.dart
git commit -m "fix(tv): autofocus unique sur l'accueil (1re rangée non vide)"
```

---

## Task 8 : Grilles catalogue/bibliothèque/genres — ancrage haut + autofocus unique

**Files:**
- Modify: `lib/src/ui/tv/catalog_page_tv.dart`
- Modify: `lib/src/ui/tv/library_page_tv.dart`
- Modify: `lib/src/ui/tv/widgets/tv_genre_grid.dart`

**Objectif :** les grilles utilisent déjà `TvFocusable` (donc scroll auto désormais actif via Task 1). Rien à changer pour le scroll — `scrollAlignment` par défaut = 0.12 (ancrage haut). Il reste à conserver l'autofocus `i == 0` uniquement sur la 1re cellule (déjà le cas), et à s'assurer qu'aucune régression n'existe. Cette task est une vérification + nettoyage mineur.

- [ ] **Step 1 : Vérifier `_CatalogTileTv` (catalog_page_tv.dart)**

Confirmer que `_CatalogTileTv` passe `autofocus: i == 0` depuis `_ResultsGrid.itemBuilder` (ligne 258 : `autofocus: i == 0`). Aucune modification nécessaire : le `TvFocusable` interne hérite du `scrollAlignment: 0.12` par défaut → ancrage haut automatique. Idem `TvGenreGrid` (ligne 70 : `autofocus: i == 0`) et `_LibraryGrid`/`_LibraryTileTv` (ligne 211 : `autofocus: i == 0`).

Aucun code à modifier dans cette étape — c'est un point de contrôle.

- [ ] **Step 2 : Lancer toute la suite de tests**

Run: `./scripts/flutter-ci.sh test`
Expected: PASS (aucune régression ; les tests catalogue/bibliothèque desktop existants ciblent `catalog_page.dart`/`library_page.dart`, non impactés).

- [ ] **Step 3 : Analyse statique globale**

Run: `./scripts/flutter-ci.sh analyze`
Expected: aucune erreur ni warning nouveau.

- [ ] **Step 4 : Commit (no-op si rien modifié — sinon nettoyage)**

Si aucune modification n'a été nécessaire, ne rien committer. Sinon :

```bash
git add lib/src/ui/tv/catalog_page_tv.dart lib/src/ui/tv/library_page_tv.dart lib/src/ui/tv/widgets/tv_genre_grid.dart
git commit -m "chore(tv): grilles — ancrage haut hérité de TvFocusable"
```

---

## Task 9 : Page détail — focus initial « Lire » sans scroll parasite

**Files:**
- Modify: `lib/src/ui/tv/media_detail_page_tv.dart`

**Objectif :** les boutons de la page détail ne sont pas dans un `Scrollable` → le garde-fou `Scrollable.maybeOf == null` de `TvFocusable` (Task 1) évite déjà tout `ensureVisible` parasite. Le bouton « Lire » a déjà `autofocus: true` (ligne 396). Cette task vérifie le comportement et le panneau latéral.

- [ ] **Step 1 : Vérifier le focus initial et le panneau**

Point de contrôle (pas de modification si tout est conforme) :
- `_ButtonColumn` : le bouton « Lire » a `autofocus: true` → focus initial correct.
- `_TvActionButton` utilise `TvFocusable` sans scroll parent → pas d'`ensureVisible` (garde-fou actif).
- `TvSidePanel` (panneau saisons/statut) : sa `ListView` interne fournit un `Scrollable` → les items du panneau bénéficient désormais du scroll-vers-focus (ancrage haut), ce qui améliore la navigation dans les longues listes de saisons.

- [ ] **Step 2 : Lancer les tests + analyse**

Run: `./scripts/flutter-ci.sh test && ./scripts/flutter-ci.sh analyze`
Expected: PASS + aucune erreur.

- [ ] **Step 3 : Commit (seulement si modification)**

Si aucune modification nécessaire, passer. Sinon committer avec un message descriptif.

---

## Task 10 : Validation finale + recette

**Files:** aucun (validation).

- [ ] **Step 1 : Suite complète + analyse**

Run: `./scripts/flutter-ci.sh test && ./scripts/flutter-ci.sh analyze`
Expected: tous les tests PASS, analyse propre.

- [ ] **Step 2 : Vérifier qu'aucune référence morte ne subsiste**

Run: `git grep -n "TvNavFocusRequest\|requestNavFocus\|_navFocusScope"`
Expected: aucun résultat (tout a été remplacé par `TvFocusScopeProvider`/`TvFocusController`).

- [ ] **Step 3 : Recette manuelle sur device TV**

Scénarios (issus de la spec) — à exécuter sur un appareil/émulateur Android TV avec `flutter run` sur le device :

1. Depuis le carrousel, descendre dans les rangées : chaque rangée focalisée s'ancre en haut, on voit toujours où on est.
2. Remonter depuis le bas : la page défile en sens inverse, l'élément focalisé reste visible à chaque étape.
3. Atteindre la navbar en remontant, puis `arrowDown` : le focus revient au contenu (dernière position), aucun blocage.
4. Naviguer horizontalement dans une rangée puis `arrowDown` : la rangée suivante s'ancre en haut, le focus reste visible.
5. Ouvrir une fiche détail : « Lire » focalisé, pas de saut de page ; ouvrir le panneau Saisons et naviguer : items visibles.

- [ ] **Step 4 : Finaliser la branche**

Utiliser la compétence `superpowers:finishing-a-development-branch` pour décider merge/PR/cleanup.

---

## Self-review (couverture spec)

- **Bug 1 (on ne voit pas où on est en remontant)** → Task 1 (`ensureVisible` au focus, montée comme descente) + Task 2 (verrou de non-régression). ✅
- **Bug 2 (blocage navbar)** → Task 3 (`focusContent` restaure le dernier focalisé) + Task 4 (`arrowDown` navbar câblé). ✅
- **Ancrage haut Netflix (vertical + grilles)** → `scrollAlignment` défaut 0.12, Tasks 1/6/8. ✅
- **Highlight zoom + bordure blanche** → Task 1. ✅
- **Flutter natif** → `Scrollable.ensureVisible` + `FocusScopeNode`, aucun package tiers. ✅
- **Mémorisation de colonne** → NOTE : la mémorisation de colonne fine (retomber sur la même colonne d'une rangée à l'autre) n'est PAS implémentée dans ce plan. Le `FocusScopeNode` restaure le dernier focalisé au niveau navbar↔contenu (Task 3), mais la traversée rangée↔rangée reste celle par défaut de Flutter (`DirectionalFocusTraversalPolicy`), qui préserve déjà raisonnablement la position horizontale. Décision : ne pas ajouter de politique custom tant que la traversée native ne pose pas problème en recette (scénario 4). Si le scénario 4 échoue, ajouter une task dédiée avec une `FocusTraversalPolicy` custom.
- **Application aux 5 zones** → navbar (T4), accueil (T5-T7), catalogue/genres (T8), bibliothèque (T8), détail (T9). ✅
- **Tests via Docker** → toutes les commandes utilisent `./scripts/flutter-ci.sh`. ✅
