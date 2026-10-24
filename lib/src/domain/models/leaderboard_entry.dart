/// Modèles pour le classement et les dashboards communautaires Terebi.
library;

class LeaderboardUser {
  final int rank;
  final String id;
  final String username;
  final String avatarStyle;
  final String avatarSeed;
  final String? avatarUrl;
  final String bio;
  final int completedCount;
  final int totalAnimes;
  final int episodesWatched;
  final double watchedHours;

  const LeaderboardUser({
    required this.rank,
    required this.id,
    required this.username,
    this.avatarStyle = 'lorelei',
    required this.avatarSeed,
    this.avatarUrl,
    this.bio = '',
    this.completedCount = 0,
    this.totalAnimes = 0,
    this.episodesWatched = 0,
    this.watchedHours = 0.0,
  });

  String get avatarPngUrl {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) return avatarUrl!;
    final style = avatarStyle.isNotEmpty ? avatarStyle : 'lorelei';
    final seed = avatarSeed.isNotEmpty ? avatarSeed : username;
    return 'https://api.dicebear.com/9.x/$style/png?seed=${Uri.encodeComponent(seed)}';
  }

  factory LeaderboardUser.fromMap(Map<String, dynamic> map, int rank) {
    final rawHours = map['watched_hours'];
    final hours = (rawHours is num)
        ? rawHours.toDouble()
        : double.tryParse(rawHours?.toString() ?? '') ?? 0.0;

    final rawEps = map['episodes_watched'];
    final eps = (rawEps is int)
        ? rawEps
        : int.tryParse(rawEps?.toString() ?? '') ?? 0;

    final rawComp = map['completed_count'];
    final comp = (rawComp is int)
        ? rawComp
        : int.tryParse(rawComp?.toString() ?? '') ?? 0;

    final rawTotal = map['total_animes'];
    final total = (rawTotal is int)
        ? rawTotal
        : int.tryParse(rawTotal?.toString() ?? '') ?? 0;

    return LeaderboardUser(
      rank: rank,
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? 'Utilisateur',
      avatarStyle: map['avatar_style']?.toString() ?? 'lorelei',
      avatarSeed: map['avatar_seed']?.toString() ?? map['username']?.toString() ?? 'User',
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString() ?? '',
      completedCount: comp,
      totalAnimes: total,
      episodesWatched: eps,
      watchedHours: hours,
    );
  }
}

class CommunityTopAnime {
  final int mediaId;
  final String title;
  final String? coverUrl;
  final int trackingUsers;

  const CommunityTopAnime({
    required this.mediaId,
    required this.title,
    this.coverUrl,
    required this.trackingUsers,
  });

  factory CommunityTopAnime.fromMap(Map<String, dynamic> map) {
    return CommunityTopAnime(
      mediaId: (map['anilist_id'] is int)
          ? map['anilist_id'] as int
          : int.tryParse(map['anilist_id']?.toString() ?? '') ?? 0,
      title: map['anime_sama_title']?.toString() ??
          map['title_romaji']?.toString() ??
          'Anime',
      coverUrl: map['cover_url']?.toString(),
      trackingUsers: (map['tracking_users'] is int)
          ? map['tracking_users'] as int
          : int.tryParse(map['tracking_users']?.toString() ?? '') ?? 0,
    );
  }
}

class CommunityDashboardData {
  final int totalUsers;
  final int uniqueAnimes;
  final double totalHours;
  final List<LeaderboardUser> users;
  final List<CommunityTopAnime> topAnimes;

  const CommunityDashboardData({
    this.totalUsers = 0,
    this.uniqueAnimes = 0,
    this.totalHours = 0.0,
    this.users = const [],
    this.topAnimes = const [],
  });
}
