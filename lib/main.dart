import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'src/app/providers.dart';
import 'src/data/local/connection.dart';
import 'src/data/repositories/settings_repository.dart';
import 'src/services/tv_detection_service.dart';
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

  // Détecte Android TV une seule fois au boot (false sur desktop/iOS/téléphone).
  final isTv = await detectIsTelevision();

  final autoUpdate =
      (await settings.get(SettingsKeys.autoUpdate, defaultValue: '0')) == '1';

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        themeModeProvider.overrideWith((ref) => themeMode),
        isTvProvider.overrideWith((ref) => isTv),
        appPlatformProvider.overrideWith((ref) {
          if (isTv) return AppPlatform.tv;
          switch (defaultTargetPlatform) {
            case TargetPlatform.android:
              return AppPlatform.mobile;
            default:
              return AppPlatform.desktop;
          }
        }),
      ],
      child: TerebiApp(showSplash: splashEnabled, autoUpdate: autoUpdate),
    ),
  );
}

/// Racine de l'application Terebi.
class TerebiApp extends ConsumerStatefulWidget {
  /// Joue l'écran de démarrage animé avant l'app si `true`.
  final bool showSplash;

  /// Lance la vérification de MAJ en arrière-plan au premier frame si `true`.
  final bool autoUpdate;

  const TerebiApp({super.key, required this.showSplash, required this.autoUpdate});

  @override
  ConsumerState<TerebiApp> createState() => _TerebiAppState();
}

class _TerebiAppState extends ConsumerState<TerebiApp> {
  late bool _splashDone = !widget.showSplash;

  @override
  void initState() {
    super.initState();
    if (widget.autoUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(updateCheckProvider);
      });
    }
  }

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
