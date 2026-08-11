/// Repository paramètres applicatifs — AUCUN import de package:flutter.
///
/// Accès clé/valeur à la table [AppSettings] de la base Drift.
/// Utilisé pour stocker : chemins ani-cli/mpv, langue préférée, etc.
library;

import '../local/database.dart';

/// Clés standard utilisées par l'application.
abstract final class SettingsKeys {
  static const String playbackLanguage = 'playback_language';

  /// Thème de l'app : 'dark' (défaut) | 'light' | 'system'.
  static const String themeMode = 'theme_mode';

  /// Écran de démarrage animé (loading.mp4) : '1' (défaut) = activé.
  static const String splashEnabled = 'splash_enabled';

  /// Enchaînement automatique de l'épisode suivant en fin de lecture
  /// ('1' = activé, autre/absent = désactivé). Désactivé par défaut.
  static const String autoPlayNext = 'auto_play_next';

  /// Durée (secondes) du saut avant (flèche droite) dans le lecteur. Défaut 10.
  static const String seekForwardSeconds = 'seek_forward_seconds';

  /// Durée (secondes) du saut arrière (flèche gauche) dans le lecteur. Défaut 10.
  static const String seekBackwardSeconds = 'seek_backward_seconds';

  /// Langue de lecture choisie POUR UN anime donné ('vf' | 'vostfr').
  /// Prime sur [playbackLanguage] (global) quand elle existe. Réglée depuis le
  /// sélecteur du lecteur. Ex. `anime_sama_lang:105333`.
  static String animeSamaLangFor(int anilistId) => 'anime_sama_lang:$anilistId';

  /// Mode « langue unique » ('1' = activé) : masque le sélecteur VF/VOSTFR du
  /// lecteur et n'effectue AUCUN test de langue (pour qui regarde toujours dans
  /// la même langue). Désactivé par défaut.
  static const String singleLanguage = 'single_language';

  /// Exécutable Python utilisé par AnimeSamaResolver ('python' ou 'python3').
  static const String pythonPath = 'python_path';

  /// Clé de la saison anime-sama choisie pour un média AniList donné
  /// (index 1-based). Ex. `anime_sama_season:105333`.
  static String animeSamaSeasonFor(int anilistId) =>
      'anime_sama_season:$anilistId';

  /// Clé du dernier épisode VU d'une saison anime-sama (int, 0 = rien vu).
  /// Progression PAR saison. Ex. `anime_sama_watched:105333:2`.
  static String animeSamaWatchedFor(int anilistId, int seasonIndex) =>
      'anime_sama_watched:$anilistId:$seasonIndex';

  /// Date (ISO 8601) du dernier recheck des « Terminé » de la bibliothèque.
  /// Sert à ne relancer ce recheck (coûteux en requêtes anime-sama) qu'1×/jour.
  static const String lastCompletedRecheck = 'last_completed_recheck';
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
