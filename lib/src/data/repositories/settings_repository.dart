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

  /// Durée (secondes) entre deux slides du hero « Nouvelles sorties » de
  /// l'accueil. Défaut 10.
  static const String heroRotationSeconds = 'hero_rotation_seconds';

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

  /// Utiliser le resolveur 100% Dart (scraping natif) au lieu du wrapper Python.
  /// '1' = Dart, autre/absent = Python. Permet l'A/B pendant la transition ;
  /// indispensable sur Android (pas de Process.run).
  static const String useDartResolver = 'use_dart_resolver';

  /// Masquer les animes déjà en bibliothèque dans le catalogue ('1' = masquer,
  /// autre/absent = afficher). Désactivé par défaut.
  static const String catalogHideLibrary = 'catalog_hide_library';

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

  /// Drapeau « nouvel épisode disponible » pour un anime donné ('1' = oui).
  /// Posé par le recheck quand un anime « Terminé » a de nouveaux épisodes ;
  /// retiré quand l'utilisateur ouvre/regarde l'anime. Ex. `new_episode:105333`.
  static String newEpisodeFor(int anilistId) => 'new_episode:$anilistId';
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

  /// Toutes les paires (clé, valeur) dont la clé commence par [prefix].
  /// Sert à scanner la progression par saison d'un média sans connaître ses
  /// saisons (clés `anime_sama_watched:<mediaId>:<seasonIndex>`).
  Future<Map<String, String>> entriesWithPrefix(String prefix) async {
    final rows = await _db.select(_db.appSettings).get();
    return {
      for (final r in rows)
        if (r.key.startsWith(prefix)) r.key: r.value,
    };
  }

  /// Stream des paires (cle, valeur) dont la cle commence par [prefix]. Emet a
  /// chaque ecriture dans AppSettings (filtrage cote Dart). Sert a la reactivite
  /// temps reel de la progression par saison (`anime_sama_watched:<id>:*`).
  Stream<Map<String, String>> watchWithPrefix(String prefix) {
    return _db.select(_db.appSettings).watch().map((rows) => {
          for (final r in rows)
            if (r.key.startsWith(prefix)) r.key: r.value,
        });
  }

  /// Renomme toutes les cles commencant par [oldPrefix] en remplacant ce prefixe
  /// par [newPrefix], en conservant la valeur. Sert a la migration slug
  /// (`anime_sama_watched:<old>:*` -> `:<new>:*`). Idempotent.
  Future<void> renameKeyPrefix(String oldPrefix, String newPrefix) async {
    final rows = await _db.select(_db.appSettings).get();
    for (final r in rows) {
      if (r.key.startsWith(oldPrefix)) {
        final newKey = newPrefix + r.key.substring(oldPrefix.length);
        await set(newKey, r.value);
        await delete(r.key);
      }
    }
  }

  /// Supprime toutes les clés commençant par [prefix]. Sert au nettoyage manuel
  /// de la progression par saison d'un média (`anime_sama_watched:<id>:*`).
  Future<void> deleteWithPrefix(String prefix) async {
    final rows = await _db.select(_db.appSettings).get();
    for (final r in rows) {
      if (r.key.startsWith(prefix)) {
        await delete(r.key);
      }
    }
  }
}
