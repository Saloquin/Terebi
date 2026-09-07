library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/filter_sort_service.dart';
import '../../domain/models/list_entry.dart';
import 'library_state.dart';

class LibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() => const LibraryState();

  void setSortField(EntrySortField field) {
    if (state.sortField == field) {
      state = state.copyWith(sortDescending: !state.sortDescending);
    } else {
      state = state.copyWith(sortField: field, sortDescending: true);
    }
  }

  void setFilter(MediaFilter filter) => state = state.copyWith(filter: filter);

  void setSearch(String query) => state = state.copyWith(searchQuery: query);

  void clearSearch() => state = state.copyWith(searchQuery: '');

  /// Filtre de genres courant — à appliquer côté page sur la liste de Media
  /// (ListEntry ne porte pas les genres, seule la page a accès aux Media).
  MediaFilter get currentFilter => state.filter;

  /// Trie et filtre [entries] selon l'état courant.
  List<ListEntry> applyFilterSort(
    List<ListEntry> entries, {
    String Function(int mediaId)? titleOf,
  }) {
    final service = ref.read(filterSortServiceProvider);
    var result = entries;

    if (state.searchQuery.isNotEmpty) {
      final q = state.searchQuery.toLowerCase();
      result = result.where((e) {
        final title = titleOf?.call(e.mediaId) ?? e.mediaId.toString();
        return title.toLowerCase().contains(q);
      }).toList();
    }

    return service.sortEntries(
      result,
      state.sortField,
      descending: state.sortDescending,
      titleOf: titleOf,
    );
  }

  /// Supprime le flag « nouvel épisode » pour un anime donné.
  Future<void> clearNewEpisodeFlag(int mediaId) async {
    await ref
        .read(settingsRepositoryProvider)
        .delete(SettingsKeys.newEpisodeFor(mediaId));
  }
}
