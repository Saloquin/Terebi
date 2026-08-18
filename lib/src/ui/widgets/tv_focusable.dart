/// Domaine UI — wrapper de focus clavier/D-pad réutilisable.
///
/// Ajoute une bordure colorée + scale animé quand l'élément a le focus
/// clavier ou D-pad. Universel (desktop, mobile, TV) — Flutter masque lui-
/// même le highlight en mode souris/tactile via [FocusManager.highlightMode].
///
/// Utilisation : envelopper une carte ou un widget cliquable avec [TvFocusable]
/// en conservant l'[InkWell]/[onTap] interne pour le tap souris/tactile.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;

  /// Callback déclenché par la touche OK/Centre (télécommande) ou Entrée.
  final VoidCallback? onPressed;

  /// Appelé quand le focus est acquis — utile pour `Scrollable.ensureVisible`.
  final VoidCallback? onFocused;

  final bool autofocus;
  final FocusNode? focusNode;

  const TvFocusable({
    super.key,
    required this.child,
    this.onPressed,
    this.onFocused,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() => _hasFocus = focused);
        if (focused) widget.onFocused?.call();
      },
      onKeyEvent: (node, event) {
        // Touche OK/Centre (télécommande) ou Entrée -> déclenche onPressed.
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
        scale: _hasFocus ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasFocus ? color : Colors.transparent,
              width: 3,
            ),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 2,
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
