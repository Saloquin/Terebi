/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Logique de franchise (multi-saisons) et auto-replanification :
/// - agréger le statut d'une franchise à partir de ses médias liés ;
/// - détecter quand une nouvelle saison sortie doit être reproposée « à voir ».
library;

import '../models/enums.dart';
import '../models/list_entry.dart';
import '../models/list_status.dart';
import '../models/media.dart';
import '../models/media_relation.dart';

/// Un média d'une franchise avec le statut de suivi associé (ou `null` si non suivi).
class FranchiseItem {
  final Media media;
  final ListEntry? entry;

  const FranchiseItem({required this.media, this.entry});

  ListStatus? get status => entry?.status;
  bool get isCompleted => entry?.status == ListStatus.completed;
  bool get isTracked => entry != null;
}

/// Logique pure de franchise.
class FranchiseService {
  const FranchiseService();

  /// Ordonne les médias d'une franchise par (année de saison, puis id) croissants,
  /// pour un affichage « S1 → S2 → film… » stable.
  List<FranchiseItem> ordered(List<FranchiseItem> items) {
    final copy = [...items];
    copy.sort((a, b) {
      final ya = a.media.seasonYear ?? 1 << 30;
      final yb = b.media.seasonYear ?? 1 << 30;
      if (ya != yb) return ya.compareTo(yb);
      return a.media.anilistId.compareTo(b.media.anilistId);
    });
    return copy;
  }

  /// `true` si toute la franchise a été vue (tous les items suivis sont COMPLETED
  /// et il y a au moins un item). Un item non suivi compte comme « pas vu ».
  bool isFranchiseCompleted(List<FranchiseItem> items) =>
      items.isNotEmpty && items.every((i) => i.isCompleted);

  /// Détecte les suites à reproposer « à voir » (US-46).
  ///
  /// Règle : si un média est COMPLETED et qu'une de ses **suites directes**
  /// (relation SEQUEL) est en cours de diffusion (RELEASING) ou vient de sortir
  /// (FINISHED) **sans être encore suivie**, alors on propose de l'ajouter en PLANNING.
  ///
  /// Retourne les `anilistId` des médias à reproposer. Fonction pure : ne modifie rien.
  Set<int> sequelsToReplan({
    required List<FranchiseItem> items,
    required List<MediaRelation> relations,
  }) {
    final byId = {for (final i in items) i.media.anilistId: i};
    final toReplan = <int>{};

    for (final rel in relations) {
      if (rel.type != RelationType.sequel) continue;
      final source = byId[rel.mediaId];
      final sequel = byId[rel.relatedMediaId];
      if (source == null || sequel == null) continue;

      final sourceCompleted = source.isCompleted;
      final sequelReleased = sequel.media.status == ReleaseStatus.releasing ||
          sequel.media.status == ReleaseStatus.finished;
      final sequelNotTracked = !sequel.isTracked ||
          sequel.status == ListStatus.dropped;

      if (sourceCompleted && sequelReleased && sequelNotTracked) {
        toReplan.add(sequel.media.anilistId);
      }
    }
    return toReplan;
  }
}
