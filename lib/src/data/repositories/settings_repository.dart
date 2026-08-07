/// Repository paramètres applicatifs — AUCUN import de package:flutter.
///
/// Accès clé/valeur à la table [AppSettings] de la base Drift.
/// Utilisé pour stocker : chemins ani-cli/mpv, langue préférée, etc.
library;

import '../local/database.dart';

/// Clés standard utilisées par l'application.
abstract final class SettingsKeys {
  static const String aniCliPath = 'ani_cli_path';
  static const String mpvPath = 'mpv_path';
  static const String playbackLanguage = 'playback_language';

  /// Chemin d'un shell POSIX (`sh`) pour exécuter le script ani-cli sous Windows.
  static const String shellPath = 'shell_path';

  /// Source de lecture active : 'animesama' (défaut) | 'ani_cli'.
  static const String streamSource = 'stream_source';

  /// Exécutable Python utilisé par AnimeSamaResolver ('python' ou 'python3').
  static const String pythonPath = 'python_path';

  /// Chemin du script `anime_sama.py` du projet animesama-cli installé.
  static const String animeSamaScript = 'anime_sama_script';
}

/// Accès typé aux paramètres applicatifs persistés dans [AppSettings].
class SettingsRepository {
  final TerebiDatabase _db;

  const SettingsRepository(this._db);

  /// Retourne la valeur associée à [key], ou [defaultValue] si absente.
  Future<String?> get(String key, {String? defaultValue}) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value ?? defaultValue;
  }

  /// Insère ou remplace la valeur pour [key].
  Future<void> set(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  /// Supprime la clé [key] (retour aux valeurs par défaut).
  Future<void> delete(String key) async {
    await (_db.delete(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .go();
  }
}
