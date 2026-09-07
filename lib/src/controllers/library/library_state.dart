library;

import '../../domain/logic/filter_sort_service.dart';

class LibraryState {
  final EntrySortField sortField;
  final bool sortDescending;
  final MediaFilter filter;
  final String searchQuery;
  final bool recheckRunning;

  const LibraryState({
    this.sortField = EntrySortField.updated,
    this.sortDescending = true,
    this.filter = const MediaFilter(),
    this.searchQuery = '',
    this.recheckRunning = false,
  });

  LibraryState copyWith({
    EntrySortField? sortField,
    bool? sortDescending,
    MediaFilter? filter,
    String? searchQuery,
    bool? recheckRunning,
  }) {
    return LibraryState(
      sortField: sortField ?? this.sortField,
      sortDescending: sortDescending ?? this.sortDescending,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      recheckRunning: recheckRunning ?? this.recheckRunning,
    );
  }
}
