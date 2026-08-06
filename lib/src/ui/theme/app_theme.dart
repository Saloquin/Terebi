/// Thème de Terebi : palette sombre par défaut (app de visionnage), accent violet.
library;

import 'package:flutter/material.dart';

/// Couleur d'accent de Terebi.
const _seed = Color(0xFF7C4DFF);

/// Thème sombre (défaut).
ThemeData terebiDarkTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
      visualDensity: VisualDensity.comfortable,
    );

/// Thème clair.
ThemeData terebiLightTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      visualDensity: VisualDensity.comfortable,
    );
