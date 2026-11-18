/// Connexion fichier pour la production.
///
/// Ce fichier PEUT importer path_provider (Flutter). Il est isolé des tests
/// qui utilisent NativeDatabase.memory() directement.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

/// Crée la [TerebiDatabase] connectée au fichier SQLite de l'application.
Future<TerebiDatabase> openProductionDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dir.path, 'terebi.sqlite'));
  final db = TerebiDatabase(NativeDatabase(dbFile));
  // Nettoyage au démarrage des positions de reprise parasites résiduelles
  // (épisodes non vus avec position en fin de vidéo suite à fuite de stream ou générique).
  try {
    await db.customStatement('''
      UPDATE episode_progresses
      SET position_seconds = 0
      WHERE watched = 0 AND (
        (duration_seconds > 60 AND (position_seconds >= duration_seconds * 0.85 OR duration_seconds - position_seconds < 90))
        OR (duration_seconds IS NULL AND position_seconds >= 1200)
      );
    ''');
  } catch (_) {}
  return db;
}

/// Chemin absolu du fichier SQLite de production (pour l'afficher dans les
/// Paramètres). Même emplacement que [openProductionDatabase].
Future<String> databaseFilePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'terebi.sqlite');
}
