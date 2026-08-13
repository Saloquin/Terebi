/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Abstraction commune des résolveurs de flux (ani-cli anglais, animesama-cli
/// VOSTFR/VF…). Le lecteur (PlayerPage) dépend de cette interface, pas d'une
/// implémentation concrète.
library;

/// Langue de lecture demandée.
enum PlaybackLanguage {
  /// Version originale sous-titrée (français pour anime-sama, anglais pour ani-cli).
  vostfr,

  /// Version française doublée.
  vf,
}

/// Exception levée quand un résolveur échoue ou ne renvoie aucune URL exploitable.
class ResolveException implements Exception {
  final String message;
  const ResolveException(this.message);
  @override
  String toString() => 'ResolveException: $message';
}

/// Un lien de flux résolu, avec sa qualité (ex. `1080p`).
class StreamLink {
  final String quality;
  final String url;
  const StreamLink({required this.quality, required this.url});

  @override
  String toString() => '$quality → $url';
}

/// Intervalles de skip (intro/outro) d'un épisode, en secondes (AniSkip).
/// Un champ `null` signifie « intervalle inconnu / absent ».
class SkipTimes {
  /// Début/fin de l'opening (intro), en secondes.
  final double? opStart;
  final double? opEnd;

  /// Début/fin de l'ending (outro), en secondes.
  final double? edStart;
  final double? edEnd;

  const SkipTimes({this.opStart, this.opEnd, this.edStart, this.edEnd});

  /// `true` si aucun intervalle exploitable n'est connu.
  bool get isEmpty =>
      !hasOpening && !hasEnding;

  bool get hasOpening => opStart != null && opEnd != null && opEnd! > opStart!;
  bool get hasEnding => edStart != null && edEnd != null && edEnd! > edStart!;

  factory SkipTimes.fromJson(Map<String, dynamic> json) => SkipTimes(
        opStart: (json['op_start'] as num?)?.toDouble(),
        opEnd: (json['op_end'] as num?)?.toDouble(),
        edStart: (json['ed_start'] as num?)?.toDouble(),
        edEnd: (json['ed_end'] as num?)?.toDouble(),
      );
}

/// Une saison telle qu'anime-sama la liste (Saison 1, 2, OAV…).
/// [index] est la position 1-based dans la liste anime-sama (utilisée pour
/// résoudre les épisodes de cette saison).
class AnimeSamaSeason {
  final int index;
  final String name;
  const AnimeSamaSeason({required this.index, required this.name});

  @override
  bool operator ==(Object other) =>
      other is AnimeSamaSeason && other.index == index && other.name == name;

  @override
  int get hashCode => Object.hash(index, name);

  @override
  String toString() => '#$index $name';
}

/// Un anime du catalogue anime-sama (résultat de recherche).
/// [url] est le path catalogue (ex. `/catalogue/dr-stone/`).
class AnimeSamaCatalogueItem {
  final String title;
  final String url;
  const AnimeSamaCatalogueItem({required this.title, required this.url});

  @override
  bool operator ==(Object other) =>
      other is AnimeSamaCatalogueItem &&
      other.title == title &&
      other.url == url;

  @override
  int get hashCode => Object.hash(title, url);

  @override
  String toString() => '$title ($url)';
}

/// Une entrée du planning hebdomadaire anime-sama.
/// [day] = nom du jour (ex. « Lundi »), [time] = « HHhMM » ou vide si inconnue,
/// [url] = path catalogue de l'anime.
class AnimeSamaPlanningItem {
  final String day;
  final String time;
  final String title;
  final String url;

  const AnimeSamaPlanningItem({
    required this.day,
    required this.time,
    required this.title,
    required this.url,
  });

  @override
  bool operator ==(Object other) =>
      other is AnimeSamaPlanningItem &&
      other.day == day &&
      other.time == time &&
      other.title == title &&
      other.url == url;

  @override
  int get hashCode => Object.hash(day, time, title, url);

  @override
  String toString() => '$day $time — $title';
}

/// Résout l'URL d'un flux vidéo jouable pour un épisode donné.
abstract interface class StreamResolver {
  /// Résout l'URL du flux (m3u8/mp4) à jouer dans le lecteur encastré.
  ///
  /// [title]    : titre de l'anime (nettoyé par l'appelant si besoin).
  /// [episode]  : numéro d'épisode (1-based).
  /// [season]   : numéro de saison (défaut 1). Ignoré par les résolveurs à
  ///              numérotation absolue (ani-cli), utilisé par anime-sama.
  /// [language] : VOSTFR (défaut) ou VF.
  ///
  /// Lève [ResolveException] en cas d'échec.
  Future<String> resolveStreamUrl({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  });
}
