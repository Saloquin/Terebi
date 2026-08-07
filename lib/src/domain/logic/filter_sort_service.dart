/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Filtrage et tri du catalogue (List<Media>) et des listes (List<ListEntry>).
/// Fonctions pures, sans I/O.
library;

import '../models/anime_format.dart';
import '../models/enums.dart';
import '../models/list_entry.dart';
import '../models/media.dart';

/// Critères de filtrage d'un catalogue de médias. Un critère `null`/vide est ignoré.
class MediaFilter {
  /// Genres requis (le média doit contenir TOUS ces genres).
  final Set<String> genres;

  /// Année de saison exacte, ou `null`.
  final int? year;

  /// Statut de diffusion requis, ou `null`.
  final ReleaseStatus? status;

  /// Format requis, ou `null`.
  final AnimeFormat? format;

  const MediaFilter({
    this.genres = const {},
    this.year,
    this.status,
    this.format,
  });

  bool get isEmpty =>
      genres.isEmpty && year == null && status == null && format == null;

  bool matches(Media m) {
    if (genres.isNotEmpty && !genres.every(m.genres.contains)) return false;
    if (year != null && m.seasonYear != year) return false;
    if (status != null && m.status != status) return false;
    if (format != null && m.format != format) return false;
    return true;
  }
}

/// Champ de tri pour les médias.
enum MediaSortField { title, year, score }

/// Champ de tri pour les entrées de liste.
enum EntrySortField { title, score, progress, updated }

/// Logique pure de filtrage/tri.
class FilterSortService {
  const FilterSortService();

  /// Filtre une liste de médias selon [filter].
  List<Media> filterMedia(List<Media> media, MediaFilter filter) {
    if (filter.isEmpty) return List.of(media);
    return media.where(filter.matches).toList();
  }

  /// Trie une liste de médias. [descending] inverse l'ordre.
  List<Media> sortMedia(
    List<Media> media,
    MediaSortField field, {
    bool descending = false,
  }) {
    final list = List.of(media);
    int cmp(Media a, Media b) {
      switch (field) {
        case MediaSortField.title:
          return a.title.preferred
              .toLowerCase()
              .compareTo(b.title.preferred.toLowerCase());
        case MediaSortField.year:
          return (a.seasonYear ?? 0).compareTo(b.seasonYear ?? 0);
        case MediaSortField.score:
          return (a.averageScore ?? 0).compareTo(b.averageScore ?? 0);
      }
    }

    list.sort((a, b) => descending ? cmp(b, a) : cmp(a, b));
    return list;
  }

  /// Trie des entrées de liste. [titleOf] fournit le titre d'un mediaId (pour le
  /// tri par titre, qui n'est pas porté par ListEntry).
  List<ListEntry> sortEntries(
    List<ListEntry> entries,
    EntrySortField field, {
    bool descending = false,
    String Function(int mediaId)? titleOf,
  }) {
    final list = List.of(entries);
    int cmp(ListEntry a, ListEntry b) {
      switch (field) {
        case EntrySortField.title:
          final ta = (titleOf?.call(a.mediaId) ?? '').toLowerCase();
          final tb = (titleOf?.call(b.mediaId) ?? '').toLowerCase();
          return ta.compareTo(tb);
        case EntrySortField.score:
          return (a.score ?? 0).compareTo(b.score ?? 0);
        case EntrySortField.progress:
          return a.progress.compareTo(b.progress);
        case EntrySortField.updated:
          return a.updatedAt.compareTo(b.updatedAt);
      }
    }

    list.sort((a, b) => descending ? cmp(b, a) : cmp(a, b));
    return list;
  }

  /// Ensemble des genres présents dans une liste de médias (triés).
  List<String> availableGenres(List<Media> media) {
    final set = <String>{};
    for (final m in media) {
      set.addAll(m.genres);
    }
    final list = set.toList()..sort();
    return list;
  }
}
