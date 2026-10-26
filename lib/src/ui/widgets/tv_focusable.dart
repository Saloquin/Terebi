/// Domaine UI — wrapper de focus clavier/D-pad réutilisable pour Android TV.
///
/// Au gain du focus : (1) ancre l'élément dans ses Scrollable ancêtres via
/// [Scrollable.ensureVisible], (2) applique un highlight zoom + bordure lumineuse.
/// Supporte toutes les touches de validation télécommande (Select, Enter, Space, A).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;

  /// Callback déclenché par la touche OK/Centre (télécommande) ou Entrée.
  final VoidCallback? onPressed;

  /// Appelé quand le focus est acquis — effets métier optionnels (ex. hero banner).
  final VoidCallback? onFocused;

  final bool autofocus;
  final FocusNode? focusNode;

  /// Alignement cible dans le Scrollable au gain du focus.
  /// 0.12 = ancrage haut (rangées verticales, grilles). 0.5 = centré.
  final double scrollAlignment;

  /// Facteur de zoom au focus (défaut 1.06).
  final double scaleFactor;

  /// Rayon des coins de la bordure de focus.
  final BorderRadius? borderRadius;

  /// Callback de touche personnalisé optionnel (ex: interception flèches).
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  const TvFocusable({
    super.key,
    required this.child,
    this.onPressed,
    this.onFocused,
    this.autofocus = false,
    this.focusNode,
    this.scrollAlignment = 0.12,
    this.scaleFactor = 1.06,
    this.borderRadius,
    this.onKeyEvent,
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
    final radius = widget.borderRadius ?? BorderRadius.circular(10);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (widget.onKeyEvent != null) {
          final res = widget.onKeyEvent!(node, event);
          if (res != KeyEventResult.ignored) return res;
        }
        if (event is KeyDownEvent) {
          final k = event.logicalKey;
          if (k == LogicalKeyboardKey.select ||
              k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.gameButtonA ||
              k == LogicalKeyboardKey.space) {
            if (widget.onPressed != null) {
              SystemSound.play(SystemSoundType.click);
              widget.onPressed!();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _hasFocus ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.6),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 0,
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
