import 'package:flutter/material.dart';

/// Clé globale du Navigator racine de l'application.
/// Permet la navigation depuis n'importe où (notamment le mini-lecteur in-app
/// qui est placé au niveau du builder de MaterialApp).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
