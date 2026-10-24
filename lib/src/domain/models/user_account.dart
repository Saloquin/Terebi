/// Modèle représentant un compte utilisateur Terebi.
library;

class UserAccount {
  final String id;
  final String username;
  final String? email;
  final String avatarStyle;
  final String avatarSeed;
  final String? avatarUrl;
  final String bio;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserAccount({
    required this.id,
    required this.username,
    this.email,
    this.avatarStyle = 'lorelei',
    required this.avatarSeed,
    this.avatarUrl,
    this.bio = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Styles DiceBear recommandés dans Terebi.
  static const availableAvatarStyles = <String, String>{
    'lorelei': 'Manga / Anime (Lorelei)',
    'adventurer': 'Aventurier RPG (Adventurer)',
    'bottts': 'Robot Futuriste (Bottts)',
    'pixel-art': 'Rétro 8-Bit (Pixel Art)',
    'notionists': 'Minimaliste (Notionists)',
    'micah': 'Portrait Moderne (Micah)',
    'fun-emoji': 'Émoji Fun (Fun Emoji)',
  };

  /// URL de l'image PNG DiceBear générée en direct.
  String get avatarPngUrl {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return avatarUrl!;
    }
    final style = avatarStyle.isNotEmpty ? avatarStyle : 'lorelei';
    final seed = avatarSeed.isNotEmpty ? avatarSeed : username;
    return 'https://api.dicebear.com/9.x/$style/png?seed=${Uri.encodeComponent(seed)}';
  }

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString(),
      avatarStyle: map['avatar_style']?.toString() ?? 'lorelei',
      avatarSeed: map['avatar_seed']?.toString() ?? map['username']?.toString() ?? 'User',
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['created_at'] is int
                  ? map['created_at']
                  : int.tryParse(map['created_at'].toString()) ?? 0,
            )
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['updated_at'] is int
                  ? map['updated_at']
                  : int.tryParse(map['updated_at'].toString()) ?? 0,
            )
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_style': avatarStyle,
      'avatar_seed': avatarSeed,
      'avatar_url': avatarUrl,
      'bio': bio,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  UserAccount copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarStyle,
    String? avatarSeed,
    String? avatarUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
