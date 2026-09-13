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
