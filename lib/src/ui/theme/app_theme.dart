/// Thème de Terebi — palette dérivée du logo (poste TV en bois + renard roux) :
/// brun bois en couleur de base, orange renard en accent.
library;

import 'package:flutter/material.dart';

/// Brun bois (couleur du poste TV et du texte « テレビ ») — couleur de base.
const _seedBrown = Color(0xFF9C5A34);

/// Orange renard — couleur d'accent (actions, sélection, progression).
const _foxOrange = Color(0xFFE8743B);

ColorScheme _scheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: _seedBrown,
    brightness: brightness,
  );
  // Accent orange renard sur les éléments d'action.
  return base.copyWith(
    secondary: _foxOrange,
    tertiary: _foxOrange,
  );
}

/// Thème sombre (défaut) — utilisé avec les logos sombres.
ThemeData terebiDarkTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _scheme(Brightness.dark),
      visualDensity: VisualDensity.comfortable,
      // Focus visible sur les composants natifs (NavigationRail, boutons…).
      focusColor: _foxOrange.withValues(alpha: 0.28),
    );

/// Thème clair — utilisé avec les logos clairs.
ThemeData terebiLightTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _scheme(Brightness.light),
      visualDensity: VisualDensity.comfortable,
      focusColor: _foxOrange.withValues(alpha: 0.28),
    );
