/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Modèle central : un média anime (série, film, OVA…) et ses métadonnées
/// (source unique : anime-sama).
library;

import '../logic/anime_id.dart';

/// Titres d'un média dans ses différentes langues.
class MediaTitle {
  final String? romaji;
  final String? english;
  final String? native;

  const MediaTitle({this.romaji, this.english, this.native});

  /// Meilleur titre affichable : anglais > romaji > natif > "Sans titre".
  String get preferred => english ?? romaji ?? native ?? 'Sans titre';

  factory MediaTitle.fromJson(Map<String, dynamic>? json) => MediaTitle(
        romaji: json?['romaji'] as String?,
        english: json?['english'] as String?,
        native: json?['native'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'romaji': romaji,
        'english': english,
        'native': native,
      };
}

/// Un média anime avec ses métadonnées (source anime-sama).
class Media {
  /// Identifiant technique principal, dérivé du slug anime-sama via
  /// [animeSamaIdForSlug]. (La colonne DB historique s'appelle `anilist_id`.)
  final int mediaId;

  final MediaTitle title;

  /// Nombre d'épisodes connu, ou `null` si inconnu.
  final int? episodes;

  final String? coverUrl;
  final String? bannerUrl;
  final String? description;
  final List<String> genres;

  /// Titre anime-sama de référence (source de vérité pour la résolution des
  /// saisons/épisodes).
  final String? animeSamaTitle;

  /// Slug d'URL anime-sama (identité logique). `null` pour un média legacy non
  /// encore migré.
  final String? animeSamaSlug;

  const Media({
    required this.mediaId,
    required this.title,
    this.episodes,
    this.coverUrl,
    this.bannerUrl,
    this.description,
    this.genres = const [],
    this.animeSamaTitle,
    this.animeSamaSlug,
  });

  /// Construit un [Media] enrichi depuis une page catalogue **anime-sama**.
  /// L'identité ([mediaId]) est un entier positif stable dérivé du [slug].
  factory Media.fromAnimeSama({
    required String slug,
    required String title,
    String? synopsis,
    List<String> genres = const [],
    String? coverUrl,
    String? bannerUrl,
  }) =>
      Media(
        mediaId: animeSamaIdForSlug(slug),
        title: MediaTitle(romaji: title, english: title),
        description: synopsis,
        genres: genres,
        coverUrl: coverUrl,
        bannerUrl: bannerUrl,
        animeSamaTitle: title,
        animeSamaSlug: slug,
      );

  /// Retourne une copie du média avec le [animeSamaTitle] renseigné.
  Media withAnimeSamaTitle(String samaTitle) =>
      _copy(animeSamaTitle: samaTitle);

  /// Copie avec le slug anime-sama renseigné (migration).
  Media withSlug(String slug) => _copy(animeSamaSlug: slug);

  /// Copie avec un autre [mediaId] (ré-indexation migration slug).
  Media withId(int newId) => _copy(mediaId: newId);

  Media _copy({
    int? mediaId,
    String? animeSamaSlug,
    String? animeSamaTitle,
  }) =>
      Media(
        mediaId: mediaId ?? this.mediaId,
        title: title,
        episodes: episodes,
        coverUrl: coverUrl,
        bannerUrl: bannerUrl,
        description: description,
        genres: genres,
        animeSamaTitle: animeSamaTitle ?? this.animeSamaTitle,
        animeSamaSlug: animeSamaSlug ?? this.animeSamaSlug,
      );

  /// Sérialisation JSON pour le cache local (round-trip avec [Media.fromJson]).
  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'title': title.toJson(),
        'episodes': episodes,
        'coverUrl': coverUrl,
        'bannerUrl': bannerUrl,
        'description': description,
        'genres': genres,
        'animeSamaTitle': animeSamaTitle,
        'animeSamaSlug': animeSamaSlug,
      };

  factory Media.fromJson(Map<String, dynamic> json) => Media(
        // Rétro-compat : ancien cache JSON pouvait utiliser 'anilistId'.
        mediaId: (json['mediaId'] ?? json['anilistId']) as int,
        title: MediaTitle.fromJson(json['title'] as Map<String, dynamic>?),
        episodes: json['episodes'] as int?,
        coverUrl: json['coverUrl'] as String?,
        bannerUrl: json['bannerUrl'] as String?,
        description: json['description'] as String?,
        genres: (json['genres'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        animeSamaTitle: json['animeSamaTitle'] as String?,
        animeSamaSlug: json['animeSamaSlug'] as String?,
      );
}
