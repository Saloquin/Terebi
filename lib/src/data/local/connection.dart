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
  return TerebiDatabase(NativeDatabase(dbFile));
}

/// Chemin absolu du fichier SQLite de production (pour l'afficher dans les
/// Paramètres). Même emplacement que [openProductionDatabase].
Future<String> databaseFilePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'terebi.sqlite');
}
