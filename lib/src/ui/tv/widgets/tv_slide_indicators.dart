/// Domaine UI TV — points indicateurs de slide du hero banner.
///
/// Plafonnés à [TvSlideIndicators.maxDots] pour ne jamais déborder la largeur
/// de l'écran quel que soit le nombre de sorties. Au-delà, une fenêtre
/// glissante centrée sur l'item courant est affichée (style Netflix).
library;

import 'package:flutter/material.dart';

class TvSlideIndicators extends StatelessWidget {
  final int count;
  final int current;

  static const int maxDots = 12;

  const TvSlideIndicators({
    super.key,
    required this.count,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    // Indices à afficher : soit tous, soit une fenêtre glissante centrée.
    final int shown = count <= maxDots ? count : maxDots;
    final int start = count <= maxDots
        ? 0
        : (current - maxDots ~/ 2).clamp(0, count - maxDots);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int j = 0; j < shown; j++)
          _Dot(active: start + j == current),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 24.0 : 8.0,
      height: 4,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
