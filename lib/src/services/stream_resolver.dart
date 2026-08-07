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
