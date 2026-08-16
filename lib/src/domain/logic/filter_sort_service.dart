/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Filtrage et tri du catalogue (listes de `Media`) et des entrées de liste.
/// Fonctions pures, sans I/O.
library;

import '../models/list_entry.dart';
import '../models/media.dart';

/// Critères de filtrage d'un catalogue de médias. Un critère vide est ignoré.
/// (Source anime-sama : seul le genre est disponible pour filtrer.)
class MediaFilter {
  /// Genres requis (le média doit contenir AU MOINS UN de ces genres — OU).
  final Set<String> genres;

  const MediaFilter({this.genres = const {}});

  bool get isEmpty => genres.isEmpty;

  bool matches(Media m) {
    // Genre en OU : le media match s'il possede AU MOINS UN des genres requis
    // (plus intuitif pour explorer qu'un ET, qui donnait souvent 0 resultat).
    if (genres.isNotEmpty && !genres.any(m.genres.contains)) return false;
    return true;
  }
}

/// Champ de tri pour les entrées de liste.
enum EntrySortField { title, progress, updated }

/// Logique pure de filtrage/tri.
class FilterSortService {
  const FilterSortService();

  /// Filtre une liste de médias selon [filter].
  List<Media> filterMedia(List<Media> media, MediaFilter filter) {
    if (filter.isEmpty) return List.of(media);
    return media.where(filter.matches).toList();
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
