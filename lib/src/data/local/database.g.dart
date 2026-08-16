// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MediaTableTable extends MediaTable
    with TableInfo<$MediaTableTable, MediaTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anilistIdMeta =
      const VerificationMeta('anilistId');
  @override
  late final GeneratedColumn<int> anilistId = GeneratedColumn<int>(
      'anilist_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleRomajiMeta =
      const VerificationMeta('titleRomaji');
  @override
  late final GeneratedColumn<String> titleRomaji = GeneratedColumn<String>(
      'title_romaji', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleEnglishMeta =
      const VerificationMeta('titleEnglish');
  @override
  late final GeneratedColumn<String> titleEnglish = GeneratedColumn<String>(
      'title_english', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleNativeMeta =
      const VerificationMeta('titleNative');
  @override
  late final GeneratedColumn<String> titleNative = GeneratedColumn<String>(
      'title_native', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _episodesMeta =
      const VerificationMeta('episodes');
  @override
  late final GeneratedColumn<int> episodes = GeneratedColumn<int>(
      'episodes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bannerUrlMeta =
      const VerificationMeta('bannerUrl');
  @override
  late final GeneratedColumn<String> bannerUrl = GeneratedColumn<String>(
      'banner_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _genresJsonMeta =
      const VerificationMeta('genresJson');
  @override
  late final GeneratedColumn<String> genresJson = GeneratedColumn<String>(
      'genres_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _animeSamaTitleMeta =
      const VerificationMeta('animeSamaTitle');
  @override
  late final GeneratedColumn<String> animeSamaTitle = GeneratedColumn<String>(
      'anime_sama_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _animeSamaSlugMeta =
      const VerificationMeta('animeSamaSlug');
  @override
  late final GeneratedColumn<String> animeSamaSlug = GeneratedColumn<String>(
      'anime_sama_slug', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        anilistId,
        titleRomaji,
        titleEnglish,
        titleNative,
        episodes,
        coverUrl,
        bannerUrl,
        description,
        genresJson,
        updatedAt,
        animeSamaTitle,
        animeSamaSlug
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_table';
  @override
  VerificationContext validateIntegrity(Insertable<MediaTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anilist_id')) {
      context.handle(_anilistIdMeta,
          anilistId.isAcceptableOrUnknown(data['anilist_id']!, _anilistIdMeta));
    }
    if (data.containsKey('title_romaji')) {
      context.handle(
          _titleRomajiMeta,
          titleRomaji.isAcceptableOrUnknown(
              data['title_romaji']!, _titleRomajiMeta));
    }
    if (data.containsKey('title_english')) {
      context.handle(
          _titleEnglishMeta,
          titleEnglish.isAcceptableOrUnknown(
              data['title_english']!, _titleEnglishMeta));
    }
    if (data.containsKey('title_native')) {
      context.handle(
          _titleNativeMeta,
          titleNative.isAcceptableOrUnknown(
              data['title_native']!, _titleNativeMeta));
    }
    if (data.containsKey('episodes')) {
      context.handle(_episodesMeta,
          episodes.isAcceptableOrUnknown(data['episodes']!, _episodesMeta));
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('banner_url')) {
      context.handle(_bannerUrlMeta,
          bannerUrl.isAcceptableOrUnknown(data['banner_url']!, _bannerUrlMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('genres_json')) {
      context.handle(
          _genresJsonMeta,
          genresJson.isAcceptableOrUnknown(
              data['genres_json']!, _genresJsonMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('anime_sama_title')) {
      context.handle(
          _animeSamaTitleMeta,
          animeSamaTitle.isAcceptableOrUnknown(
              data['anime_sama_title']!, _animeSamaTitleMeta));
    }
    if (data.containsKey('anime_sama_slug')) {
      context.handle(
          _animeSamaSlugMeta,
          animeSamaSlug.isAcceptableOrUnknown(
              data['anime_sama_slug']!, _animeSamaSlugMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {anilistId};
  @override
  MediaTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaTableData(
      anilistId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}anilist_id'])!,
      titleRomaji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title_romaji']),
      titleEnglish: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title_english']),
      titleNative: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title_native']),
      episodes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episodes']),
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      bannerUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}banner_url']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      genresJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genres_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      animeSamaTitle: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}anime_sama_title']),
      animeSamaSlug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}anime_sama_slug']),
    );
  }

  @override
  $MediaTableTable createAlias(String alias) {
    return $MediaTableTable(attachedDatabase, alias);
  }
}

class MediaTableData extends DataClass implements Insertable<MediaTableData> {
  /// Identifiant technique principal — clé primaire. Dérivé du slug anime-sama
  /// via animeSamaIdForSlug. (Colonne nommée `anilistId` par héritage ; le
  /// modèle Dart l'expose sous `mediaId`.)
  final int anilistId;
  final String? titleRomaji;
  final String? titleEnglish;
  final String? titleNative;
  final int? episodes;
  final String? coverUrl;
  final String? bannerUrl;
  final String? description;

  /// Genres sérialisés en JSON string (`List&lt;String&gt;`).
  final String genresJson;
  final DateTime updatedAt;

  /// Titre anime-sama de référence (source de vérité pour saisons/épisodes).
  /// Ajouté en v2.
  final String? animeSamaTitle;

  /// Slug d'URL anime-sama (identite logique). NULL pour un media legacy non
  /// encore migre. Ajoute en v3.
  final String? animeSamaSlug;
  const MediaTableData(
      {required this.anilistId,
      this.titleRomaji,
      this.titleEnglish,
      this.titleNative,
      this.episodes,
      this.coverUrl,
      this.bannerUrl,
      this.description,
      required this.genresJson,
      required this.updatedAt,
      this.animeSamaTitle,
      this.animeSamaSlug});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    if (!nullToAbsent || titleRomaji != null) {
      map['title_romaji'] = Variable<String>(titleRomaji);
    }
    if (!nullToAbsent || titleEnglish != null) {
      map['title_english'] = Variable<String>(titleEnglish);
    }
    if (!nullToAbsent || titleNative != null) {
      map['title_native'] = Variable<String>(titleNative);
    }
    if (!nullToAbsent || episodes != null) {
      map['episodes'] = Variable<int>(episodes);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || bannerUrl != null) {
      map['banner_url'] = Variable<String>(bannerUrl);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['genres_json'] = Variable<String>(genresJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || animeSamaTitle != null) {
      map['anime_sama_title'] = Variable<String>(animeSamaTitle);
    }
    if (!nullToAbsent || animeSamaSlug != null) {
      map['anime_sama_slug'] = Variable<String>(animeSamaSlug);
    }
    return map;
  }

  MediaTableCompanion toCompanion(bool nullToAbsent) {
    return MediaTableCompanion(
      anilistId: Value(anilistId),
      titleRomaji: titleRomaji == null && nullToAbsent
          ? const Value.absent()
          : Value(titleRomaji),
      titleEnglish: titleEnglish == null && nullToAbsent
          ? const Value.absent()
          : Value(titleEnglish),
      titleNative: titleNative == null && nullToAbsent
          ? const Value.absent()
          : Value(titleNative),
      episodes: episodes == null && nullToAbsent
          ? const Value.absent()
          : Value(episodes),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      bannerUrl: bannerUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerUrl),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      genresJson: Value(genresJson),
      updatedAt: Value(updatedAt),
      animeSamaTitle: animeSamaTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(animeSamaTitle),
      animeSamaSlug: animeSamaSlug == null && nullToAbsent
          ? const Value.absent()
          : Value(animeSamaSlug),
    );
  }

  factory MediaTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      titleRomaji: serializer.fromJson<String?>(json['titleRomaji']),
      titleEnglish: serializer.fromJson<String?>(json['titleEnglish']),
      titleNative: serializer.fromJson<String?>(json['titleNative']),
      episodes: serializer.fromJson<int?>(json['episodes']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      bannerUrl: serializer.fromJson<String?>(json['bannerUrl']),
      description: serializer.fromJson<String?>(json['description']),
      genresJson: serializer.fromJson<String>(json['genresJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      animeSamaTitle: serializer.fromJson<String?>(json['animeSamaTitle']),
      animeSamaSlug: serializer.fromJson<String?>(json['animeSamaSlug']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'titleRomaji': serializer.toJson<String?>(titleRomaji),
      'titleEnglish': serializer.toJson<String?>(titleEnglish),
      'titleNative': serializer.toJson<String?>(titleNative),
      'episodes': serializer.toJson<int?>(episodes),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'bannerUrl': serializer.toJson<String?>(bannerUrl),
      'description': serializer.toJson<String?>(description),
      'genresJson': serializer.toJson<String>(genresJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'animeSamaTitle': serializer.toJson<String?>(animeSamaTitle),
      'animeSamaSlug': serializer.toJson<String?>(animeSamaSlug),
    };
  }

  MediaTableData copyWith(
          {int? anilistId,
          Value<String?> titleRomaji = const Value.absent(),
          Value<String?> titleEnglish = const Value.absent(),
          Value<String?> titleNative = const Value.absent(),
          Value<int?> episodes = const Value.absent(),
          Value<String?> coverUrl = const Value.absent(),
          Value<String?> bannerUrl = const Value.absent(),
          Value<String?> description = const Value.absent(),
          String? genresJson,
          DateTime? updatedAt,
          Value<String?> animeSamaTitle = const Value.absent(),
          Value<String?> animeSamaSlug = const Value.absent()}) =>
      MediaTableData(
        anilistId: anilistId ?? this.anilistId,
        titleRomaji: titleRomaji.present ? titleRomaji.value : this.titleRomaji,
        titleEnglish:
            titleEnglish.present ? titleEnglish.value : this.titleEnglish,
        titleNative: titleNative.present ? titleNative.value : this.titleNative,
        episodes: episodes.present ? episodes.value : this.episodes,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        bannerUrl: bannerUrl.present ? bannerUrl.value : this.bannerUrl,
        description: description.present ? description.value : this.description,
        genresJson: genresJson ?? this.genresJson,
        updatedAt: updatedAt ?? this.updatedAt,
        animeSamaTitle:
            animeSamaTitle.present ? animeSamaTitle.value : this.animeSamaTitle,
        animeSamaSlug:
            animeSamaSlug.present ? animeSamaSlug.value : this.animeSamaSlug,
      );
  MediaTableData copyWithCompanion(MediaTableCompanion data) {
    return MediaTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      titleRomaji:
          data.titleRomaji.present ? data.titleRomaji.value : this.titleRomaji,
      titleEnglish: data.titleEnglish.present
          ? data.titleEnglish.value
          : this.titleEnglish,
      titleNative:
          data.titleNative.present ? data.titleNative.value : this.titleNative,
      episodes: data.episodes.present ? data.episodes.value : this.episodes,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      bannerUrl: data.bannerUrl.present ? data.bannerUrl.value : this.bannerUrl,
      description:
          data.description.present ? data.description.value : this.description,
      genresJson:
          data.genresJson.present ? data.genresJson.value : this.genresJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      animeSamaTitle: data.animeSamaTitle.present
          ? data.animeSamaTitle.value
          : this.animeSamaTitle,
      animeSamaSlug: data.animeSamaSlug.present
          ? data.animeSamaSlug.value
          : this.animeSamaSlug,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleEnglish: $titleEnglish, ')
          ..write('titleNative: $titleNative, ')
          ..write('episodes: $episodes, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('bannerUrl: $bannerUrl, ')
          ..write('description: $description, ')
          ..write('genresJson: $genresJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('animeSamaTitle: $animeSamaTitle, ')
          ..write('animeSamaSlug: $animeSamaSlug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      anilistId,
      titleRomaji,
      titleEnglish,
      titleNative,
      episodes,
      coverUrl,
      bannerUrl,
      description,
      genresJson,
      updatedAt,
      animeSamaTitle,
      animeSamaSlug);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaTableData &&
          other.anilistId == this.anilistId &&
          other.titleRomaji == this.titleRomaji &&
          other.titleEnglish == this.titleEnglish &&
          other.titleNative == this.titleNative &&
          other.episodes == this.episodes &&
          other.coverUrl == this.coverUrl &&
          other.bannerUrl == this.bannerUrl &&
          other.description == this.description &&
          other.genresJson == this.genresJson &&
          other.updatedAt == this.updatedAt &&
          other.animeSamaTitle == this.animeSamaTitle &&
          other.animeSamaSlug == this.animeSamaSlug);
}

class MediaTableCompanion extends UpdateCompanion<MediaTableData> {
  final Value<int> anilistId;
  final Value<String?> titleRomaji;
  final Value<String?> titleEnglish;
  final Value<String?> titleNative;
  final Value<int?> episodes;
  final Value<String?> coverUrl;
  final Value<String?> bannerUrl;
  final Value<String?> description;
  final Value<String> genresJson;
  final Value<DateTime> updatedAt;
  final Value<String?> animeSamaTitle;
  final Value<String?> animeSamaSlug;
  const MediaTableCompanion({
    this.anilistId = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.episodes = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.bannerUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.animeSamaTitle = const Value.absent(),
    this.animeSamaSlug = const Value.absent(),
  });
  MediaTableCompanion.insert({
    this.anilistId = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.episodes = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.bannerUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.animeSamaTitle = const Value.absent(),
    this.animeSamaSlug = const Value.absent(),
  });
  static Insertable<MediaTableData> custom({
    Expression<int>? anilistId,
    Expression<String>? titleRomaji,
    Expression<String>? titleEnglish,
    Expression<String>? titleNative,
    Expression<int>? episodes,
    Expression<String>? coverUrl,
    Expression<String>? bannerUrl,
    Expression<String>? description,
    Expression<String>? genresJson,
    Expression<DateTime>? updatedAt,
    Expression<String>? animeSamaTitle,
    Expression<String>? animeSamaSlug,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (titleRomaji != null) 'title_romaji': titleRomaji,
      if (titleEnglish != null) 'title_english': titleEnglish,
      if (titleNative != null) 'title_native': titleNative,
      if (episodes != null) 'episodes': episodes,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (description != null) 'description': description,
      if (genresJson != null) 'genres_json': genresJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (animeSamaTitle != null) 'anime_sama_title': animeSamaTitle,
      if (animeSamaSlug != null) 'anime_sama_slug': animeSamaSlug,
    });
  }

  MediaTableCompanion copyWith(
      {Value<int>? anilistId,
      Value<String?>? titleRomaji,
      Value<String?>? titleEnglish,
      Value<String?>? titleNative,
      Value<int?>? episodes,
      Value<String?>? coverUrl,
      Value<String?>? bannerUrl,
      Value<String?>? description,
      Value<String>? genresJson,
      Value<DateTime>? updatedAt,
      Value<String?>? animeSamaTitle,
      Value<String?>? animeSamaSlug}) {
    return MediaTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      titleRomaji: titleRomaji ?? this.titleRomaji,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      titleNative: titleNative ?? this.titleNative,
      episodes: episodes ?? this.episodes,
      coverUrl: coverUrl ?? this.coverUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      genresJson: genresJson ?? this.genresJson,
      updatedAt: updatedAt ?? this.updatedAt,
      animeSamaTitle: animeSamaTitle ?? this.animeSamaTitle,
      animeSamaSlug: animeSamaSlug ?? this.animeSamaSlug,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (titleRomaji.present) {
      map['title_romaji'] = Variable<String>(titleRomaji.value);
    }
    if (titleEnglish.present) {
      map['title_english'] = Variable<String>(titleEnglish.value);
    }
    if (titleNative.present) {
      map['title_native'] = Variable<String>(titleNative.value);
    }
    if (episodes.present) {
      map['episodes'] = Variable<int>(episodes.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (bannerUrl.present) {
      map['banner_url'] = Variable<String>(bannerUrl.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (genresJson.present) {
      map['genres_json'] = Variable<String>(genresJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (animeSamaTitle.present) {
      map['anime_sama_title'] = Variable<String>(animeSamaTitle.value);
    }
    if (animeSamaSlug.present) {
      map['anime_sama_slug'] = Variable<String>(animeSamaSlug.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleEnglish: $titleEnglish, ')
          ..write('titleNative: $titleNative, ')
          ..write('episodes: $episodes, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('bannerUrl: $bannerUrl, ')
          ..write('description: $description, ')
          ..write('genresJson: $genresJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('animeSamaTitle: $animeSamaTitle, ')
          ..write('animeSamaSlug: $animeSamaSlug')
          ..write(')'))
        .toString();
  }
}

class $ListEntriesTable extends ListEntries
    with TableInfo<$ListEntriesTable, ListEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta =
      const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
      'media_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('planning'));
  static const VerificationMeta _progressMeta =
      const VerificationMeta('progress');
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
      'progress', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _hiddenFromPlanningMeta =
      const VerificationMeta('hiddenFromPlanning');
  @override
  late final GeneratedColumn<bool> hiddenFromPlanning = GeneratedColumn<bool>(
      'hidden_from_planning', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("hidden_from_planning" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [mediaId, status, progress, hiddenFromPlanning, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'list_entries';
  @override
  VerificationContext validateIntegrity(Insertable<ListEntryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta,
          mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta,
          progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    }
    if (data.containsKey('hidden_from_planning')) {
      context.handle(
          _hiddenFromPlanningMeta,
          hiddenFromPlanning.isAcceptableOrUnknown(
              data['hidden_from_planning']!, _hiddenFromPlanningMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId};
  @override
  ListEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListEntryRow(
      mediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      progress: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}progress'])!,
      hiddenFromPlanning: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}hidden_from_planning'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ListEntriesTable createAlias(String alias) {
    return $ListEntriesTable(attachedDatabase, alias);
  }
}

class ListEntryRow extends DataClass implements Insertable<ListEntryRow> {
  /// FK → MediaTable.anilistId (aussi PK).
  final int mediaId;

  /// Statut de suivi stocké en TEXT (.name).
  final String status;
  final int progress;
  final bool hiddenFromPlanning;
  final DateTime updatedAt;
  const ListEntryRow(
      {required this.mediaId,
      required this.status,
      required this.progress,
      required this.hiddenFromPlanning,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<int>(mediaId);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<int>(progress);
    map['hidden_from_planning'] = Variable<bool>(hiddenFromPlanning);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ListEntriesCompanion toCompanion(bool nullToAbsent) {
    return ListEntriesCompanion(
      mediaId: Value(mediaId),
      status: Value(status),
      progress: Value(progress),
      hiddenFromPlanning: Value(hiddenFromPlanning),
      updatedAt: Value(updatedAt),
    );
  }

  factory ListEntryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListEntryRow(
      mediaId: serializer.fromJson<int>(json['mediaId']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<int>(json['progress']),
      hiddenFromPlanning: serializer.fromJson<bool>(json['hiddenFromPlanning']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<int>(mediaId),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<int>(progress),
      'hiddenFromPlanning': serializer.toJson<bool>(hiddenFromPlanning),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ListEntryRow copyWith(
          {int? mediaId,
          String? status,
          int? progress,
          bool? hiddenFromPlanning,
          DateTime? updatedAt}) =>
      ListEntryRow(
        mediaId: mediaId ?? this.mediaId,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        hiddenFromPlanning: hiddenFromPlanning ?? this.hiddenFromPlanning,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ListEntryRow copyWithCompanion(ListEntriesCompanion data) {
    return ListEntryRow(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      hiddenFromPlanning: data.hiddenFromPlanning.present
          ? data.hiddenFromPlanning.value
          : this.hiddenFromPlanning,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListEntryRow(')
          ..write('mediaId: $mediaId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('hiddenFromPlanning: $hiddenFromPlanning, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mediaId, status, progress, hiddenFromPlanning, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListEntryRow &&
          other.mediaId == this.mediaId &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.hiddenFromPlanning == this.hiddenFromPlanning &&
          other.updatedAt == this.updatedAt);
}

class ListEntriesCompanion extends UpdateCompanion<ListEntryRow> {
  final Value<int> mediaId;
  final Value<String> status;
  final Value<int> progress;
  final Value<bool> hiddenFromPlanning;
  final Value<DateTime> updatedAt;
  const ListEntriesCompanion({
    this.mediaId = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.hiddenFromPlanning = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ListEntriesCompanion.insert({
    this.mediaId = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.hiddenFromPlanning = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<ListEntryRow> custom({
    Expression<int>? mediaId,
    Expression<String>? status,
    Expression<int>? progress,
    Expression<bool>? hiddenFromPlanning,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (hiddenFromPlanning != null)
        'hidden_from_planning': hiddenFromPlanning,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ListEntriesCompanion copyWith(
      {Value<int>? mediaId,
      Value<String>? status,
      Value<int>? progress,
      Value<bool>? hiddenFromPlanning,
      Value<DateTime>? updatedAt}) {
    return ListEntriesCompanion(
      mediaId: mediaId ?? this.mediaId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      hiddenFromPlanning: hiddenFromPlanning ?? this.hiddenFromPlanning,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (hiddenFromPlanning.present) {
      map['hidden_from_planning'] = Variable<bool>(hiddenFromPlanning.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListEntriesCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('hiddenFromPlanning: $hiddenFromPlanning, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EpisodeProgressesTable extends EpisodeProgresses
    with TableInfo<$EpisodeProgressesTable, EpisodeProgressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _mediaIdMeta =
      const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
      'media_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _episodeNumberMeta =
      const VerificationMeta('episodeNumber');
  @override
  late final GeneratedColumn<double> episodeNumber = GeneratedColumn<double>(
      'episode_number', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _watchedMeta =
      const VerificationMeta('watched');
  @override
  late final GeneratedColumn<bool> watched = GeneratedColumn<bool>(
      'watched', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("watched" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _positionSecondsMeta =
      const VerificationMeta('positionSeconds');
  @override
  late final GeneratedColumn<double> positionSeconds = GeneratedColumn<double>(
      'position_seconds', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
      'duration_seconds', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        mediaId,
        episodeNumber,
        watched,
        positionSeconds,
        durationSeconds,
        completedAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_progresses';
  @override
  VerificationContext validateIntegrity(
      Insertable<EpisodeProgressesData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta,
          mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('episode_number')) {
      context.handle(
          _episodeNumberMeta,
          episodeNumber.isAcceptableOrUnknown(
              data['episode_number']!, _episodeNumberMeta));
    } else if (isInserting) {
      context.missing(_episodeNumberMeta);
    }
    if (data.containsKey('watched')) {
      context.handle(_watchedMeta,
          watched.isAcceptableOrUnknown(data['watched']!, _watchedMeta));
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
          _positionSecondsMeta,
          positionSeconds.isAcceptableOrUnknown(
              data['position_seconds']!, _positionSecondsMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {mediaId, episodeNumber},
      ];
  @override
  EpisodeProgressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeProgressesData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_id'])!,
      episodeNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}episode_number'])!,
      watched: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}watched'])!,
      positionSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}position_seconds'])!,
      durationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}duration_seconds']),
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $EpisodeProgressesTable createAlias(String alias) {
    return $EpisodeProgressesTable(attachedDatabase, alias);
  }
}

class EpisodeProgressesData extends DataClass
    implements Insertable<EpisodeProgressesData> {
  final int id;
  final int mediaId;

  /// Numéro d'épisode (double pour les demi-épisodes).
  final double episodeNumber;
  final bool watched;
  final double positionSeconds;
  final double? durationSeconds;
  final DateTime? completedAt;
  final DateTime updatedAt;
  const EpisodeProgressesData(
      {required this.id,
      required this.mediaId,
      required this.episodeNumber,
      required this.watched,
      required this.positionSeconds,
      this.durationSeconds,
      this.completedAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['media_id'] = Variable<int>(mediaId);
    map['episode_number'] = Variable<double>(episodeNumber);
    map['watched'] = Variable<bool>(watched);
    map['position_seconds'] = Variable<double>(positionSeconds);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<double>(durationSeconds);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EpisodeProgressesCompanion toCompanion(bool nullToAbsent) {
    return EpisodeProgressesCompanion(
      id: Value(id),
      mediaId: Value(mediaId),
      episodeNumber: Value(episodeNumber),
      watched: Value(watched),
      positionSeconds: Value(positionSeconds),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory EpisodeProgressesData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeProgressesData(
      id: serializer.fromJson<int>(json['id']),
      mediaId: serializer.fromJson<int>(json['mediaId']),
      episodeNumber: serializer.fromJson<double>(json['episodeNumber']),
      watched: serializer.fromJson<bool>(json['watched']),
      positionSeconds: serializer.fromJson<double>(json['positionSeconds']),
      durationSeconds: serializer.fromJson<double?>(json['durationSeconds']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mediaId': serializer.toJson<int>(mediaId),
      'episodeNumber': serializer.toJson<double>(episodeNumber),
      'watched': serializer.toJson<bool>(watched),
      'positionSeconds': serializer.toJson<double>(positionSeconds),
      'durationSeconds': serializer.toJson<double?>(durationSeconds),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EpisodeProgressesData copyWith(
          {int? id,
          int? mediaId,
          double? episodeNumber,
          bool? watched,
          double? positionSeconds,
          Value<double?> durationSeconds = const Value.absent(),
          Value<DateTime?> completedAt = const Value.absent(),
          DateTime? updatedAt}) =>
      EpisodeProgressesData(
        id: id ?? this.id,
        mediaId: mediaId ?? this.mediaId,
        episodeNumber: episodeNumber ?? this.episodeNumber,
        watched: watched ?? this.watched,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        durationSeconds: durationSeconds.present
            ? durationSeconds.value
            : this.durationSeconds,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  EpisodeProgressesData copyWithCompanion(EpisodeProgressesCompanion data) {
    return EpisodeProgressesData(
      id: data.id.present ? data.id.value : this.id,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      watched: data.watched.present ? data.watched.value : this.watched,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeProgressesData(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('watched: $watched, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mediaId, episodeNumber, watched,
      positionSeconds, durationSeconds, completedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeProgressesData &&
          other.id == this.id &&
          other.mediaId == this.mediaId &&
          other.episodeNumber == this.episodeNumber &&
          other.watched == this.watched &&
          other.positionSeconds == this.positionSeconds &&
          other.durationSeconds == this.durationSeconds &&
          other.completedAt == this.completedAt &&
          other.updatedAt == this.updatedAt);
}

class EpisodeProgressesCompanion
    extends UpdateCompanion<EpisodeProgressesData> {
  final Value<int> id;
  final Value<int> mediaId;
  final Value<double> episodeNumber;
  final Value<bool> watched;
  final Value<double> positionSeconds;
  final Value<double?> durationSeconds;
  final Value<DateTime?> completedAt;
  final Value<DateTime> updatedAt;
  const EpisodeProgressesCompanion({
    this.id = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.watched = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EpisodeProgressesCompanion.insert({
    this.id = const Value.absent(),
    required int mediaId,
    required double episodeNumber,
    this.watched = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.completedAt = const Value.absent(),
    required DateTime updatedAt,
  })  : mediaId = Value(mediaId),
        episodeNumber = Value(episodeNumber),
        updatedAt = Value(updatedAt);
  static Insertable<EpisodeProgressesData> custom({
    Expression<int>? id,
    Expression<int>? mediaId,
    Expression<double>? episodeNumber,
    Expression<bool>? watched,
    Expression<double>? positionSeconds,
    Expression<double>? durationSeconds,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaId != null) 'media_id': mediaId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (watched != null) 'watched': watched,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (completedAt != null) 'completed_at': completedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EpisodeProgressesCompanion copyWith(
      {Value<int>? id,
      Value<int>? mediaId,
      Value<double>? episodeNumber,
      Value<bool>? watched,
      Value<double>? positionSeconds,
      Value<double?>? durationSeconds,
      Value<DateTime?>? completedAt,
      Value<DateTime>? updatedAt}) {
    return EpisodeProgressesCompanion(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      watched: watched ?? this.watched,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<double>(episodeNumber.value);
    }
    if (watched.present) {
      map['watched'] = Variable<bool>(watched.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<double>(positionSeconds.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeProgressesCompanion(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('watched: $watched, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WatchHistoriesTable extends WatchHistories
    with TableInfo<$WatchHistoriesTable, WatchHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _mediaIdMeta =
      const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
      'media_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _episodeNumberMeta =
      const VerificationMeta('episodeNumber');
  @override
  late final GeneratedColumn<double> episodeNumber = GeneratedColumn<double>(
      'episode_number', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _watchedSecondsMeta =
      const VerificationMeta('watchedSeconds');
  @override
  late final GeneratedColumn<double> watchedSeconds = GeneratedColumn<double>(
      'watched_seconds', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, mediaId, episodeNumber, startedAt, endedAt, watchedSeconds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_histories';
  @override
  VerificationContext validateIntegrity(Insertable<WatchHistoryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta,
          mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('episode_number')) {
      context.handle(
          _episodeNumberMeta,
          episodeNumber.isAcceptableOrUnknown(
              data['episode_number']!, _episodeNumberMeta));
    } else if (isInserting) {
      context.missing(_episodeNumberMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('watched_seconds')) {
      context.handle(
          _watchedSecondsMeta,
          watchedSeconds.isAcceptableOrUnknown(
              data['watched_seconds']!, _watchedSecondsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchHistoryRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_id'])!,
      episodeNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}episode_number'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      watchedSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}watched_seconds'])!,
    );
  }

  @override
  $WatchHistoriesTable createAlias(String alias) {
    return $WatchHistoriesTable(attachedDatabase, alias);
  }
}

class WatchHistoryRow extends DataClass implements Insertable<WatchHistoryRow> {
  final int id;
  final int mediaId;
  final double episodeNumber;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double watchedSeconds;
  const WatchHistoryRow(
      {required this.id,
      required this.mediaId,
      required this.episodeNumber,
      required this.startedAt,
      this.endedAt,
      required this.watchedSeconds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['media_id'] = Variable<int>(mediaId);
    map['episode_number'] = Variable<double>(episodeNumber);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['watched_seconds'] = Variable<double>(watchedSeconds);
    return map;
  }

  WatchHistoriesCompanion toCompanion(bool nullToAbsent) {
    return WatchHistoriesCompanion(
      id: Value(id),
      mediaId: Value(mediaId),
      episodeNumber: Value(episodeNumber),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      watchedSeconds: Value(watchedSeconds),
    );
  }

  factory WatchHistoryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchHistoryRow(
      id: serializer.fromJson<int>(json['id']),
      mediaId: serializer.fromJson<int>(json['mediaId']),
      episodeNumber: serializer.fromJson<double>(json['episodeNumber']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      watchedSeconds: serializer.fromJson<double>(json['watchedSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mediaId': serializer.toJson<int>(mediaId),
      'episodeNumber': serializer.toJson<double>(episodeNumber),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'watchedSeconds': serializer.toJson<double>(watchedSeconds),
    };
  }

  WatchHistoryRow copyWith(
          {int? id,
          int? mediaId,
          double? episodeNumber,
          DateTime? startedAt,
          Value<DateTime?> endedAt = const Value.absent(),
          double? watchedSeconds}) =>
      WatchHistoryRow(
        id: id ?? this.id,
        mediaId: mediaId ?? this.mediaId,
        episodeNumber: episodeNumber ?? this.episodeNumber,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        watchedSeconds: watchedSeconds ?? this.watchedSeconds,
      );
  WatchHistoryRow copyWithCompanion(WatchHistoriesCompanion data) {
    return WatchHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      watchedSeconds: data.watchedSeconds.present
          ? data.watchedSeconds.value
          : this.watchedSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryRow(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('watchedSeconds: $watchedSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, mediaId, episodeNumber, startedAt, endedAt, watchedSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryRow &&
          other.id == this.id &&
          other.mediaId == this.mediaId &&
          other.episodeNumber == this.episodeNumber &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.watchedSeconds == this.watchedSeconds);
}

class WatchHistoriesCompanion extends UpdateCompanion<WatchHistoryRow> {
  final Value<int> id;
  final Value<int> mediaId;
  final Value<double> episodeNumber;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<double> watchedSeconds;
  const WatchHistoriesCompanion({
    this.id = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.watchedSeconds = const Value.absent(),
  });
  WatchHistoriesCompanion.insert({
    this.id = const Value.absent(),
    required int mediaId,
    required double episodeNumber,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.watchedSeconds = const Value.absent(),
  })  : mediaId = Value(mediaId),
        episodeNumber = Value(episodeNumber),
        startedAt = Value(startedAt);
  static Insertable<WatchHistoryRow> custom({
    Expression<int>? id,
    Expression<int>? mediaId,
    Expression<double>? episodeNumber,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<double>? watchedSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaId != null) 'media_id': mediaId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (watchedSeconds != null) 'watched_seconds': watchedSeconds,
    });
  }

  WatchHistoriesCompanion copyWith(
      {Value<int>? id,
      Value<int>? mediaId,
      Value<double>? episodeNumber,
      Value<DateTime>? startedAt,
      Value<DateTime?>? endedAt,
      Value<double>? watchedSeconds}) {
    return WatchHistoriesCompanion(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      watchedSeconds: watchedSeconds ?? this.watchedSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<double>(episodeNumber.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (watchedSeconds.present) {
      map['watched_seconds'] = Variable<double>(watchedSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('watchedSeconds: $watchedSeconds')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) => AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaCacheTable extends MetaCache
    with TableInfo<$MetaCacheTable, MetaCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cache_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [cacheKey, payload, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_cache';
  @override
  VerificationContext validateIntegrity(Insertable<MetaCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(_cacheKeyMeta,
          cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  MetaCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaCacheData(
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
    );
  }

  @override
  $MetaCacheTable createAlias(String alias) {
    return $MetaCacheTable(attachedDatabase, alias);
  }
}

class MetaCacheData extends DataClass implements Insertable<MetaCacheData> {
  final String cacheKey;
  final String payload;
  final DateTime expiresAt;
  const MetaCacheData(
      {required this.cacheKey, required this.payload, required this.expiresAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload'] = Variable<String>(payload);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  MetaCacheCompanion toCompanion(bool nullToAbsent) {
    return MetaCacheCompanion(
      cacheKey: Value(cacheKey),
      payload: Value(payload),
      expiresAt: Value(expiresAt),
    );
  }

  factory MetaCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaCacheData(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payload: serializer.fromJson<String>(json['payload']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payload': serializer.toJson<String>(payload),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  MetaCacheData copyWith(
          {String? cacheKey, String? payload, DateTime? expiresAt}) =>
      MetaCacheData(
        cacheKey: cacheKey ?? this.cacheKey,
        payload: payload ?? this.payload,
        expiresAt: expiresAt ?? this.expiresAt,
      );
  MetaCacheData copyWithCompanion(MetaCacheCompanion data) {
    return MetaCacheData(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaCacheData(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, payload, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaCacheData &&
          other.cacheKey == this.cacheKey &&
          other.payload == this.payload &&
          other.expiresAt == this.expiresAt);
}

class MetaCacheCompanion extends UpdateCompanion<MetaCacheData> {
  final Value<String> cacheKey;
  final Value<String> payload;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const MetaCacheCompanion({
    this.cacheKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCacheCompanion.insert({
    required String cacheKey,
    required String payload,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  })  : cacheKey = Value(cacheKey),
        payload = Value(payload),
        expiresAt = Value(expiresAt);
  static Insertable<MetaCacheData> custom({
    Expression<String>? cacheKey,
    Expression<String>? payload,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payload != null) 'payload': payload,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCacheCompanion copyWith(
      {Value<String>? cacheKey,
      Value<String>? payload,
      Value<DateTime>? expiresAt,
      Value<int>? rowid}) {
    return MetaCacheCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      payload: payload ?? this.payload,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCacheCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TerebiDatabase extends GeneratedDatabase {
  _$TerebiDatabase(QueryExecutor e) : super(e);
  $TerebiDatabaseManager get managers => $TerebiDatabaseManager(this);
  late final $MediaTableTable mediaTable = $MediaTableTable(this);
  late final $ListEntriesTable listEntries = $ListEntriesTable(this);
  late final $EpisodeProgressesTable episodeProgresses =
      $EpisodeProgressesTable(this);
  late final $WatchHistoriesTable watchHistories = $WatchHistoriesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $MetaCacheTable metaCache = $MetaCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        mediaTable,
        listEntries,
        episodeProgresses,
        watchHistories,
        appSettings,
        metaCache
      ];
}

typedef $$MediaTableTableCreateCompanionBuilder = MediaTableCompanion Function({
  Value<int> anilistId,
  Value<String?> titleRomaji,
  Value<String?> titleEnglish,
  Value<String?> titleNative,
  Value<int?> episodes,
  Value<String?> coverUrl,
  Value<String?> bannerUrl,
  Value<String?> description,
  Value<String> genresJson,
  Value<DateTime> updatedAt,
  Value<String?> animeSamaTitle,
  Value<String?> animeSamaSlug,
});
typedef $$MediaTableTableUpdateCompanionBuilder = MediaTableCompanion Function({
  Value<int> anilistId,
  Value<String?> titleRomaji,
  Value<String?> titleEnglish,
  Value<String?> titleNative,
  Value<int?> episodes,
  Value<String?> coverUrl,
  Value<String?> bannerUrl,
  Value<String?> description,
  Value<String> genresJson,
  Value<DateTime> updatedAt,
  Value<String?> animeSamaTitle,
  Value<String?> animeSamaSlug,
});

class $$MediaTableTableFilterComposer
    extends Composer<_$TerebiDatabase, $MediaTableTable> {
  $$MediaTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anilistId => $composableBuilder(
      column: $table.anilistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleRomaji => $composableBuilder(
      column: $table.titleRomaji, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleEnglish => $composableBuilder(
      column: $table.titleEnglish, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleNative => $composableBuilder(
      column: $table.titleNative, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get episodes => $composableBuilder(
      column: $table.episodes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bannerUrl => $composableBuilder(
      column: $table.bannerUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get animeSamaTitle => $composableBuilder(
      column: $table.animeSamaTitle,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get animeSamaSlug => $composableBuilder(
      column: $table.animeSamaSlug, builder: (column) => ColumnFilters(column));
}

class $$MediaTableTableOrderingComposer
    extends Composer<_$TerebiDatabase, $MediaTableTable> {
  $$MediaTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anilistId => $composableBuilder(
      column: $table.anilistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleRomaji => $composableBuilder(
      column: $table.titleRomaji, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleEnglish => $composableBuilder(
      column: $table.titleEnglish,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleNative => $composableBuilder(
      column: $table.titleNative, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get episodes => $composableBuilder(
      column: $table.episodes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bannerUrl => $composableBuilder(
      column: $table.bannerUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get animeSamaTitle => $composableBuilder(
      column: $table.animeSamaTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get animeSamaSlug => $composableBuilder(
      column: $table.animeSamaSlug,
      builder: (column) => ColumnOrderings(column));
}

class $$MediaTableTableAnnotationComposer
    extends Composer<_$TerebiDatabase, $MediaTableTable> {
  $$MediaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<String> get titleRomaji => $composableBuilder(
      column: $table.titleRomaji, builder: (column) => column);

  GeneratedColumn<String> get titleEnglish => $composableBuilder(
      column: $table.titleEnglish, builder: (column) => column);

  GeneratedColumn<String> get titleNative => $composableBuilder(
      column: $table.titleNative, builder: (column) => column);

  GeneratedColumn<int> get episodes =>
      $composableBuilder(column: $table.episodes, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get bannerUrl =>
      $composableBuilder(column: $table.bannerUrl, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get animeSamaTitle => $composableBuilder(
      column: $table.animeSamaTitle, builder: (column) => column);

  GeneratedColumn<String> get animeSamaSlug => $composableBuilder(
      column: $table.animeSamaSlug, builder: (column) => column);
}

class $$MediaTableTableTableManager extends RootTableManager<
    _$TerebiDatabase,
    $MediaTableTable,
    MediaTableData,
    $$MediaTableTableFilterComposer,
    $$MediaTableTableOrderingComposer,
    $$MediaTableTableAnnotationComposer,
    $$MediaTableTableCreateCompanionBuilder,
    $$MediaTableTableUpdateCompanionBuilder,
    (
      MediaTableData,
      BaseReferences<_$TerebiDatabase, $MediaTableTable, MediaTableData>
    ),
    MediaTableData,
    PrefetchHooks Function()> {
  $$MediaTableTableTableManager(_$TerebiDatabase db, $MediaTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> anilistId = const Value.absent(),
            Value<String?> titleRomaji = const Value.absent(),
            Value<String?> titleEnglish = const Value.absent(),
            Value<String?> titleNative = const Value.absent(),
            Value<int?> episodes = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> bannerUrl = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> genresJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> animeSamaTitle = const Value.absent(),
            Value<String?> animeSamaSlug = const Value.absent(),
          }) =>
              MediaTableCompanion(
            anilistId: anilistId,
            titleRomaji: titleRomaji,
            titleEnglish: titleEnglish,
            titleNative: titleNative,
            episodes: episodes,
            coverUrl: coverUrl,
            bannerUrl: bannerUrl,
            description: description,
            genresJson: genresJson,
            updatedAt: updatedAt,
            animeSamaTitle: animeSamaTitle,
            animeSamaSlug: animeSamaSlug,
          ),
          createCompanionCallback: ({
            Value<int> anilistId = const Value.absent(),
            Value<String?> titleRomaji = const Value.absent(),
            Value<String?> titleEnglish = const Value.absent(),
            Value<String?> titleNative = const Value.absent(),
            Value<int?> episodes = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> bannerUrl = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> genresJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> animeSamaTitle = const Value.absent(),
            Value<String?> animeSamaSlug = const Value.absent(),
          }) =>
              MediaTableCompanion.insert(
            anilistId: anilistId,
            titleRomaji: titleRomaji,
            titleEnglish: titleEnglish,
            titleNative: titleNative,
            episodes: episodes,
            coverUrl: coverUrl,
            bannerUrl: bannerUrl,
            description: description,
            genresJson: genresJson,
            updatedAt: updatedAt,
            animeSamaTitle: animeSamaTitle,
            animeSamaSlug: animeSamaSlug,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MediaTableTableProcessedTableManager = ProcessedTableManager<
    _$TerebiDatabase,
    $MediaTableTable,
    MediaTableData,
    $$MediaTableTableFilterComposer,
    $$MediaTableTableOrderingComposer,
    $$MediaTableTableAnnotationComposer,
    $$MediaTableTableCreateCompanionBuilder,
    $$MediaTableTableUpdateCompanionBuilder,
    (
      MediaTableData,
      BaseReferences<_$TerebiDatabase, $MediaTableTable, MediaTableData>
    ),
    MediaTableData,
    PrefetchHooks Function()>;
typedef $$ListEntriesTableCreateCompanionBuilder = ListEntriesCompanion
    Function({
  Value<int> mediaId,
  Value<String> status,
  Value<int> progress,
  Value<bool> hiddenFromPlanning,
  required DateTime updatedAt,
});
typedef $$ListEntriesTableUpdateCompanionBuilder = ListEntriesCompanion
    Function({
  Value<int> mediaId,
  Value<String> status,
  Value<int> progress,
  Value<bool> hiddenFromPlanning,
  Value<DateTime> updatedAt,
});

class $$ListEntriesTableFilterComposer
    extends Composer<_$TerebiDatabase, $ListEntriesTable> {
  $$ListEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hiddenFromPlanning => $composableBuilder(
      column: $table.hiddenFromPlanning,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ListEntriesTableOrderingComposer
    extends Composer<_$TerebiDatabase, $ListEntriesTable> {
  $$ListEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hiddenFromPlanning => $composableBuilder(
      column: $table.hiddenFromPlanning,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ListEntriesTableAnnotationComposer
    extends Composer<_$TerebiDatabase, $ListEntriesTable> {
  $$ListEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<bool> get hiddenFromPlanning => $composableBuilder(
      column: $table.hiddenFromPlanning, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ListEntriesTableTableManager extends RootTableManager<
    _$TerebiDatabase,
    $ListEntriesTable,
    ListEntryRow,
    $$ListEntriesTableFilterComposer,
    $$ListEntriesTableOrderingComposer,
    $$ListEntriesTableAnnotationComposer,
    $$ListEntriesTableCreateCompanionBuilder,
    $$ListEntriesTableUpdateCompanionBuilder,
    (
      ListEntryRow,
      BaseReferences<_$TerebiDatabase, $ListEntriesTable, ListEntryRow>
    ),
    ListEntryRow,
    PrefetchHooks Function()> {
  $$ListEntriesTableTableManager(_$TerebiDatabase db, $ListEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> mediaId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> progress = const Value.absent(),
            Value<bool> hiddenFromPlanning = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              ListEntriesCompanion(
            mediaId: mediaId,
            status: status,
            progress: progress,
            hiddenFromPlanning: hiddenFromPlanning,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> mediaId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> progress = const Value.absent(),
            Value<bool> hiddenFromPlanning = const Value.absent(),
            required DateTime updatedAt,
          }) =>
              ListEntriesCompanion.insert(
            mediaId: mediaId,
            status: status,
            progress: progress,
            hiddenFromPlanning: hiddenFromPlanning,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ListEntriesTableProcessedTableManager = ProcessedTableManager<
    _$TerebiDatabase,
    $ListEntriesTable,
    ListEntryRow,
    $$ListEntriesTableFilterComposer,
    $$ListEntriesTableOrderingComposer,
    $$ListEntriesTableAnnotationComposer,
    $$ListEntriesTableCreateCompanionBuilder,
    $$ListEntriesTableUpdateCompanionBuilder,
    (
      ListEntryRow,
      BaseReferences<_$TerebiDatabase, $ListEntriesTable, ListEntryRow>
    ),
    ListEntryRow,
    PrefetchHooks Function()>;
typedef $$EpisodeProgressesTableCreateCompanionBuilder
    = EpisodeProgressesCompanion Function({
  Value<int> id,
  required int mediaId,
  required double episodeNumber,
  Value<bool> watched,
  Value<double> positionSeconds,
  Value<double?> durationSeconds,
  Value<DateTime?> completedAt,
  required DateTime updatedAt,
});
typedef $$EpisodeProgressesTableUpdateCompanionBuilder
    = EpisodeProgressesCompanion Function({
  Value<int> id,
  Value<int> mediaId,
  Value<double> episodeNumber,
  Value<bool> watched,
  Value<double> positionSeconds,
  Value<double?> durationSeconds,
  Value<DateTime?> completedAt,
  Value<DateTime> updatedAt,
});

class $$EpisodeProgressesTableFilterComposer
    extends Composer<_$TerebiDatabase, $EpisodeProgressesTable> {
  $$EpisodeProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get watched => $composableBuilder(
      column: $table.watched, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$EpisodeProgressesTableOrderingComposer
    extends Composer<_$TerebiDatabase, $EpisodeProgressesTable> {
  $$EpisodeProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get watched => $composableBuilder(
      column: $table.watched, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$EpisodeProgressesTableAnnotationComposer
    extends Composer<_$TerebiDatabase, $EpisodeProgressesTable> {
  $$EpisodeProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<double> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => column);

  GeneratedColumn<bool> get watched =>
      $composableBuilder(column: $table.watched, builder: (column) => column);

  GeneratedColumn<double> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds, builder: (column) => column);

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EpisodeProgressesTableTableManager extends RootTableManager<
    _$TerebiDatabase,
    $EpisodeProgressesTable,
    EpisodeProgressesData,
    $$EpisodeProgressesTableFilterComposer,
    $$EpisodeProgressesTableOrderingComposer,
    $$EpisodeProgressesTableAnnotationComposer,
    $$EpisodeProgressesTableCreateCompanionBuilder,
    $$EpisodeProgressesTableUpdateCompanionBuilder,
    (
      EpisodeProgressesData,
      BaseReferences<_$TerebiDatabase, $EpisodeProgressesTable,
          EpisodeProgressesData>
    ),
    EpisodeProgressesData,
    PrefetchHooks Function()> {
  $$EpisodeProgressesTableTableManager(
      _$TerebiDatabase db, $EpisodeProgressesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodeProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodeProgressesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> mediaId = const Value.absent(),
            Value<double> episodeNumber = const Value.absent(),
            Value<bool> watched = const Value.absent(),
            Value<double> positionSeconds = const Value.absent(),
            Value<double?> durationSeconds = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              EpisodeProgressesCompanion(
            id: id,
            mediaId: mediaId,
            episodeNumber: episodeNumber,
            watched: watched,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            completedAt: completedAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int mediaId,
            required double episodeNumber,
            Value<bool> watched = const Value.absent(),
            Value<double> positionSeconds = const Value.absent(),
            Value<double?> durationSeconds = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            required DateTime updatedAt,
          }) =>
              EpisodeProgressesCompanion.insert(
            id: id,
            mediaId: mediaId,
            episodeNumber: episodeNumber,
            watched: watched,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            completedAt: completedAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EpisodeProgressesTableProcessedTableManager = ProcessedTableManager<
    _$TerebiDatabase,
    $EpisodeProgressesTable,
    EpisodeProgressesData,
    $$EpisodeProgressesTableFilterComposer,
    $$EpisodeProgressesTableOrderingComposer,
    $$EpisodeProgressesTableAnnotationComposer,
    $$EpisodeProgressesTableCreateCompanionBuilder,
    $$EpisodeProgressesTableUpdateCompanionBuilder,
    (
      EpisodeProgressesData,
      BaseReferences<_$TerebiDatabase, $EpisodeProgressesTable,
          EpisodeProgressesData>
    ),
    EpisodeProgressesData,
    PrefetchHooks Function()>;
typedef $$WatchHistoriesTableCreateCompanionBuilder = WatchHistoriesCompanion
    Function({
  Value<int> id,
  required int mediaId,
  required double episodeNumber,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  Value<double> watchedSeconds,
});
typedef $$WatchHistoriesTableUpdateCompanionBuilder = WatchHistoriesCompanion
    Function({
  Value<int> id,
  Value<int> mediaId,
  Value<double> episodeNumber,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<double> watchedSeconds,
});

class $$WatchHistoriesTableFilterComposer
    extends Composer<_$TerebiDatabase, $WatchHistoriesTable> {
  $$WatchHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get watchedSeconds => $composableBuilder(
      column: $table.watchedSeconds,
      builder: (column) => ColumnFilters(column));
}

class $$WatchHistoriesTableOrderingComposer
    extends Composer<_$TerebiDatabase, $WatchHistoriesTable> {
  $$WatchHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get watchedSeconds => $composableBuilder(
      column: $table.watchedSeconds,
      builder: (column) => ColumnOrderings(column));
}

class $$WatchHistoriesTableAnnotationComposer
    extends Composer<_$TerebiDatabase, $WatchHistoriesTable> {
  $$WatchHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<double> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<double> get watchedSeconds => $composableBuilder(
      column: $table.watchedSeconds, builder: (column) => column);
}

class $$WatchHistoriesTableTableManager extends RootTableManager<
    _$TerebiDatabase,
    $WatchHistoriesTable,
    WatchHistoryRow,
    $$WatchHistoriesTableFilterComposer,
    $$WatchHistoriesTableOrderingComposer,
    $$WatchHistoriesTableAnnotationComposer,
    $$WatchHistoriesTableCreateCompanionBuilder,
    $$WatchHistoriesTableUpdateCompanionBuilder,
    (
      WatchHistoryRow,
      BaseReferences<_$TerebiDatabase, $WatchHistoriesTable, WatchHistoryRow>
    ),
    WatchHistoryRow,
    PrefetchHooks Function()> {
  $$WatchHistoriesTableTableManager(
      _$TerebiDatabase db, $WatchHistoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> mediaId = const Value.absent(),
            Value<double> episodeNumber = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            Value<double> watchedSeconds = const Value.absent(),
          }) =>
              WatchHistoriesCompanion(
            id: id,
            mediaId: mediaId,
            episodeNumber: episodeNumber,
            startedAt: startedAt,
            endedAt: endedAt,
            watchedSeconds: watchedSeconds,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int mediaId,
            required double episodeNumber,
            required DateTime startedAt,
            Value<DateTime?> endedAt = const Value.absent(),
            Value<double> watchedSeconds = const Value.absent(),
          }) =>
              WatchHistoriesCompanion.insert(
            id: id,
            mediaId: mediaId,
            episodeNumber: episodeNumber,
            startedAt: startedAt,
            endedAt: endedAt,
            watchedSeconds: watchedSeconds,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WatchHistoriesTableProcessedTableManager = ProcessedTableManager<
    _$TerebiDatabase,
    $WatchHistoriesTable,
    WatchHistoryRow,
    $$WatchHistoriesTableFilterComposer,
    $$WatchHistoriesTableOrderingComposer,
    $$WatchHistoriesTableAnnotationComposer,
    $$WatchHistoriesTableCreateCompanionBuilder,
    $$WatchHistoriesTableUpdateCompanionBuilder,
    (
      WatchHistoryRow,
      BaseReferences<_$TerebiDatabase, $WatchHistoriesTable, WatchHistoryRow>
    ),
    WatchHistoryRow,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$TerebiDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$TerebiDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$TerebiDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$TerebiDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (
      AppSetting,
      BaseReferences<_$TerebiDatabase, $AppSettingsTable, AppSetting>
    ),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$TerebiDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$TerebiDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (
      AppSetting,
      BaseReferences<_$TerebiDatabase, $AppSettingsTable, AppSetting>
    ),
    AppSetting,
    PrefetchHooks Function()>;
typedef $$MetaCacheTableCreateCompanionBuilder = MetaCacheCompanion Function({
  required String cacheKey,
  required String payload,
  required DateTime expiresAt,
  Value<int> rowid,
});
typedef $$MetaCacheTableUpdateCompanionBuilder = MetaCacheCompanion Function({
  Value<String> cacheKey,
  Value<String> payload,
  Value<DateTime> expiresAt,
  Value<int> rowid,
});

class $$MetaCacheTableFilterComposer
    extends Composer<_$TerebiDatabase, $MetaCacheTable> {
  $$MetaCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));
}

class $$MetaCacheTableOrderingComposer
    extends Composer<_$TerebiDatabase, $MetaCacheTable> {
  $$MetaCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));
}

class $$MetaCacheTableAnnotationComposer
    extends Composer<_$TerebiDatabase, $MetaCacheTable> {
  $$MetaCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$MetaCacheTableTableManager extends RootTableManager<
    _$TerebiDatabase,
    $MetaCacheTable,
    MetaCacheData,
    $$MetaCacheTableFilterComposer,
    $$MetaCacheTableOrderingComposer,
    $$MetaCacheTableAnnotationComposer,
    $$MetaCacheTableCreateCompanionBuilder,
    $$MetaCacheTableUpdateCompanionBuilder,
    (
      MetaCacheData,
      BaseReferences<_$TerebiDatabase, $MetaCacheTable, MetaCacheData>
    ),
    MetaCacheData,
    PrefetchHooks Function()> {
  $$MetaCacheTableTableManager(_$TerebiDatabase db, $MetaCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cacheKey = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaCacheCompanion(
            cacheKey: cacheKey,
            payload: payload,
            expiresAt: expiresAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cacheKey,
            required String payload,
            required DateTime expiresAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaCacheCompanion.insert(
            cacheKey: cacheKey,
            payload: payload,
            expiresAt: expiresAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MetaCacheTableProcessedTableManager = ProcessedTableManager<
    _$TerebiDatabase,
    $MetaCacheTable,
    MetaCacheData,
    $$MetaCacheTableFilterComposer,
    $$MetaCacheTableOrderingComposer,
    $$MetaCacheTableAnnotationComposer,
    $$MetaCacheTableCreateCompanionBuilder,
    $$MetaCacheTableUpdateCompanionBuilder,
    (
      MetaCacheData,
      BaseReferences<_$TerebiDatabase, $MetaCacheTable, MetaCacheData>
    ),
    MetaCacheData,
    PrefetchHooks Function()>;

class $TerebiDatabaseManager {
  final _$TerebiDatabase _db;
  $TerebiDatabaseManager(this._db);
  $$MediaTableTableTableManager get mediaTable =>
      $$MediaTableTableTableManager(_db, _db.mediaTable);
  $$ListEntriesTableTableManager get listEntries =>
      $$ListEntriesTableTableManager(_db, _db.listEntries);
  $$EpisodeProgressesTableTableManager get episodeProgresses =>
      $$EpisodeProgressesTableTableManager(_db, _db.episodeProgresses);
  $$WatchHistoriesTableTableManager get watchHistories =>
      $$WatchHistoriesTableTableManager(_db, _db.watchHistories);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$MetaCacheTableTableManager get metaCache =>
      $$MetaCacheTableTableManager(_db, _db.metaCache);
}
