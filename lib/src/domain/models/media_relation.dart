/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Relation entre deux médias (suite, préquelle, spin-off…).
library;

/// Type de relation entre deux médias (AniList `MediaRelation`).
enum RelationType {
  /// Suite directe (AniList `SEQUEL`).
  sequel,

  /// Préquelle directe (AniList `PREQUEL`).
  prequel,

  /// Histoire parallèle ou connexe (AniList `SIDE_STORY`).
  sideStory,

  /// Œuvre parente (AniList `PARENT`).
  parent,

  /// Version alternative (AniList `ALTERNATIVE`).
  alternative,

  /// Spin-off (AniList `SPIN_OFF`).
  spinOff,

  /// Autre type de relation non catégorisé.
  other;

  /// Valeur AniList correspondante (ex. `SEQUEL`).
  String get anilist => switch (this) {
        RelationType.sequel => 'SEQUEL',
        RelationType.prequel => 'PREQUEL',
        RelationType.sideStory => 'SIDE_STORY',
        RelationType.parent => 'PARENT',
        RelationType.alternative => 'ALTERNATIVE',
        RelationType.spinOff => 'SPIN_OFF',
        RelationType.other => 'OTHER',
      };

  /// Construit un [RelationType] depuis une valeur AniList. Défaut : [other].
  static RelationType fromAniList(String? value) => switch (value) {
        'SEQUEL' => RelationType.sequel,
        'PREQUEL' => RelationType.prequel,
        'SIDE_STORY' => RelationType.sideStory,
        'PARENT' => RelationType.parent,
        'ALTERNATIVE' => RelationType.alternative,
        'SPIN_OFF' => RelationType.spinOff,
        _ => RelationType.other,
      };
}

/// Relation entre un média et un autre média lié.
class MediaRelation {
  /// ID du média source.
  final int mediaId;

  /// ID du média lié.
  final int relatedMediaId;

  /// Nature de la relation entre les deux médias.
  final RelationType type;

  const MediaRelation({
    required this.mediaId,
    required this.relatedMediaId,
    required this.type,
  });

  /// Sérialisation JSON pour le cache local (round-trip avec [MediaRelation.fromJson]).
  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'relatedMediaId': relatedMediaId,
        'type': type.name,
      };

  factory MediaRelation.fromJson(Map<String, dynamic> json) => MediaRelation(
        mediaId: json['mediaId'] as int,
        relatedMediaId: json['relatedMediaId'] as int,
        type: RelationType.values.byName(json['type'] as String? ?? 'other'),
      );
}
