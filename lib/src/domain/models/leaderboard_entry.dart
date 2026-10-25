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

  Map<String, dynamic> toMap() => {
    'rank': rank,
    'id': id,
    'username': username,
    'avatar_style': avatarStyle,
    'avatar_seed': avatarSeed,
    'avatar_url': avatarUrl,
    'bio': bio,
    'completed_count': completedCount,
    'total_animes': totalAnimes,
    'episodes_watched': episodesWatched,
    'watched_hours': watchedHours,
  };

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

  Map<String, dynamic> toMap() => {
    'anilist_id': mediaId,
    'anime_sama_title': title,
    'cover_url': coverUrl,
    'tracking_users': trackingUsers,
  };

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

  Map<String, dynamic> toMap() => {
    'total_users': totalUsers,
    'community_unique_animes': uniqueAnimes,
    'community_total_hours': totalHours,
    'users': users.map((u) => u.toMap()).toList(),
    'top_animes': topAnimes.map((a) => a.toMap()).toList(),
  };

  factory CommunityDashboardData.fromMap(Map<String, dynamic> map) {
    final rawUsers = (map['users'] as List?) ?? const [];
    final users = <LeaderboardUser>[];
    for (int i = 0; i < rawUsers.length; i++) {
      if (rawUsers[i] is Map<String, dynamic>) {
        final r = (rawUsers[i]['rank'] is int) ? rawUsers[i]['rank'] as int : i + 1;
        users.add(LeaderboardUser.fromMap(rawUsers[i] as Map<String, dynamic>, r));
      }
    }
    final rawTop = (map['top_animes'] as List?) ?? const [];
    final topAnimes = rawTop
        .whereType<Map<String, dynamic>>()
        .map(CommunityTopAnime.fromMap)
        .toList();

    return CommunityDashboardData(
      totalUsers: (map['total_users'] is int)
          ? map['total_users'] as int
          : int.tryParse(map['total_users']?.toString() ?? '') ?? users.length,
      uniqueAnimes: (map['community_unique_animes'] is int)
          ? map['community_unique_animes'] as int
          : int.tryParse(map['community_unique_animes']?.toString() ?? '') ?? 0,
      totalHours: (map['community_total_hours'] is num)
          ? (map['community_total_hours'] as num).toDouble()
          : double.tryParse(map['community_total_hours']?.toString() ?? '') ?? 0.0,
      users: users,
      topAnimes: topAnimes,
    );
  }
}
