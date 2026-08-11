import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'src/app/providers.dart';
import 'src/data/local/connection.dart';
import 'src/data/repositories/settings_repository.dart';
import 'src/ui/app_shell.dart';
import 'src/ui/splash_page.dart';
import 'src/ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise media_kit (libmpv) pour le lecteur encastré + le splash.
  MediaKit.ensureInitialized();

  // Ouvre la base SQLite locale (source de vérité du suivi) avant de démarrer l'UI.
  final db = await openProductionDatabase();

  // Lit les préférences d'apparence pour l'état initial (thème + splash).
  final settings = SettingsRepository(db);
  final themeMode =
      themeModeFromString(await settings.get(SettingsKeys.themeMode));
  final splashEnabled =
      (await settings.get(SettingsKeys.splashEnabled, defaultValue: '1')) == '1';

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        themeModeProvider.overrideWith((ref) => themeMode),
      ],
      child: TerebiApp(showSplash: splashEnabled),
    ),
  );
}

/// Racine de l'application Terebi.
class TerebiApp extends ConsumerStatefulWidget {
  /// Joue l'écran de démarrage animé avant l'app si `true`.
  final bool showSplash;

  const TerebiApp({super.key, required this.showSplash});

  @override
  ConsumerState<TerebiApp> createState() => _TerebiAppState();
}

class _TerebiAppState extends ConsumerState<TerebiApp> {
  late bool _splashDone = !widget.showSplash;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Terebi',
      debugShowCheckedModeBanner: false,
      theme: terebiLightTheme(),
      darkTheme: terebiDarkTheme(),
      themeMode: themeMode,
      home: _splashDone
          ? const AppShell()
          : SplashScreen(onDone: () => setState(() => _splashDone = true)),
    );
  }
}
