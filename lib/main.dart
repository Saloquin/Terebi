import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'src/app/providers.dart';
import 'src/data/local/connection.dart';
import 'src/ui/app_shell.dart';
import 'src/ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise media_kit (libmpv) pour le lecteur encastré.
  MediaKit.ensureInitialized();

  // Ouvre la base SQLite locale (source de vérité du suivi) avant de démarrer l'UI.
  final db = await openProductionDatabase();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const TerebiApp(),
    ),
  );
}

/// Racine de l'application Terebi.
class TerebiApp extends StatelessWidget {
  const TerebiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terebi',
      debugShowCheckedModeBanner: false,
      theme: terebiLightTheme(),
      darkTheme: terebiDarkTheme(),
      themeMode: ThemeMode.dark,
      home: const AppShell(),
    );
  }
}
