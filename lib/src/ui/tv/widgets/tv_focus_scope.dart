/// Domaine UI TV — pont de focus entre la navbar et le contenu.
///
/// Sépare le focus en deux [FocusScopeNode] (navbar + contenu) et expose un
/// [TvFocusController] pour passer de l'un à l'autre au D-pad :
/// - [TvFocusController.focusNavBar] : arrowUp depuis le sommet du contenu —
///   restaure le dernier onglet navbar focalisé, ou le premier focalisable.
/// - [TvFocusController.focusContent] : arrowDown depuis la navbar — restaure
///   le DERNIER élément focalisé du contenu (corrige le blocage navbar).
library;

import 'package:flutter/material.dart';

/// Contrôleur partagé entre le shell TV et ses pages pour piloter le pont.
class TvFocusController {
  final FocusScopeNode navScope = FocusScopeNode(debugLabel: 'tvNavScope');
  final FocusScopeNode contentScope =
      FocusScopeNode(debugLabel: 'tvContentScope');

  /// Donne le focus à la navbar : restaure le dernier onglet focalisé si connu,
  /// sinon focalise explicitement le PREMIER onglet focusable. On ne se contente
  /// pas de `navScope.requestFocus()` : sans autofocus déclaré sur un enfant, le
  /// focus resterait sur le scope lui-même (aucun highlight visible, flèches
  /// gauche/droite sans point de départ).
  void focusNavBar() {
    final last = navScope.focusedChild;
    if (last != null) {
      last.requestFocus();
      return;
    }
    final firstChild = navScope.traversalDescendants.firstOrNull;
    if (firstChild != null) {
      firstChild.requestFocus();
    } else {
      navScope.requestFocus();
    }
  }

  /// Rend le focus au contenu, sur son dernier enfant focalisé si connu, sinon
  /// sur le premier focusable du contenu (même logique que [focusNavBar]).
  void focusContent() {
    final last = contentScope.focusedChild;
    if (last != null) {
      last.requestFocus();
      return;
    }
    final firstChild = contentScope.traversalDescendants.firstOrNull;
    if (firstChild != null) {
      firstChild.requestFocus();
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
