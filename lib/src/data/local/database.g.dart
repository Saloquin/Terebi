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
  static const VerificationMeta _malIdMeta = const VerificationMeta('malId');
  @override
  late final GeneratedColumn<int> malId = GeneratedColumn<int>(
      'mal_id', aliasedName, true,
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
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
      'format', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('unknown'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('unknown'));
  static const VerificationMeta _episodesMeta =
      const VerificationMeta('episodes');
  @override
  late final GeneratedColumn<int> episodes = GeneratedColumn<int>(
      'episodes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _durationMinutesMeta =
      const VerificationMeta('durationMinutes');
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
      'duration_minutes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<String> season = GeneratedColumn<String>(
      'season', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _seasonYearMeta =
      const VerificationMeta('seasonYear');
  @override
  late final GeneratedColumn<int> seasonYear = GeneratedColumn<int>(
      'season_year', aliasedName, true,
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
  static const VerificationMeta _averageScoreMeta =
      const VerificationMeta('averageScore');
  @override
  late final GeneratedColumn<int> averageScore = GeneratedColumn<int>(
      'average_score', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
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
  @override
  List<GeneratedColumn> get $columns => [
        anilistId,
        malId,
        titleRomaji,
        titleEnglish,
        titleNative,
        format,
        status,
        episodes,
        durationMinutes,
        season,
        seasonYear,
        coverUrl,
        bannerUrl,
        description,
        genresJson,
        averageScore,
        updatedAt,
        animeSamaTitle
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
    if (data.containsKey('mal_id')) {
      context.handle(
          _malIdMeta, malId.isAcceptableOrUnknown(data['mal_id']!, _malIdMeta));
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
    if (data.containsKey('format')) {
      context.handle(_formatMeta,
          format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('episodes')) {
      context.handle(_episodesMeta,
          episodes.isAcceptableOrUnknown(data['episodes']!, _episodesMeta));
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
          _durationMinutesMeta,
          durationMinutes.isAcceptableOrUnknown(
              data['duration_minutes']!, _durationMinutesMeta));
    }
    if (data.containsKey('season')) {
      context.handle(_seasonMeta,
          season.isAcceptableOrUnknown(data['season']!, _seasonMeta));
    }
    if (data.containsKey('season_year')) {
      context.handle(
          _seasonYearMeta,
          seasonYear.isAcceptableOrUnknown(
              data['season_year']!, _seasonYearMeta));
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
    if (data.containsKey('average_score')) {
      context.handle(
          _averageScoreMeta,
          averageScore.isAcceptableOrUnknown(
              data['average_score']!, _averageScoreMeta));
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
      malId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}mal_id']),
      titleRomaji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title_romaji']),
      titleEnglish: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title_english']),
      titleNative: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title_native']),
      format: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      episodes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episodes']),
      durationMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_minutes']),
      season: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}season']),
      seasonYear: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}season_year']),
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      bannerUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}banner_url']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      genresJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genres_json'])!,
      averageScore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}average_score']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      animeSamaTitle: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}anime_sama_title']),
    );
  }

  @override
  $MediaTableTable createAlias(String alias) {
    return $MediaTableTable(attachedDatabase, alias);
  }
}

class MediaTableData extends DataClass implements Insertable<MediaTableData> {
  /// ID AniList — clé primaire.
  final int anilistId;

  /// ID MyAnimeList (optionnel).
  final int? malId;
  final String? titleRomaji;
  final String? titleEnglish;
  final String? titleNative;

  /// Format stocké en TEXT (.name).
  final String format;

  /// Statut de diffusion stocké en TEXT (.name).
  final String status;
  final int? episodes;
  final int? durationMinutes;

  /// Saison stockée en TEXT (.name), ou NULL.
  final String? season;
  final int? seasonYear;
  final String? coverUrl;
  final String? bannerUrl;
  final String? description;

  /// Genres sérialisés en JSON string (`List&lt;String&gt;`).
  final String genresJson;
  final int? averageScore;
  final DateTime updatedAt;

  /// Titre anime-sama de référence (source de vérité pour saisons/épisodes).
  /// NULL pour les médias importés uniquement depuis AniList. Ajouté en v2.
  final String? animeSamaTitle;
  const MediaTableData(
      {required this.anilistId,
      this.malId,
      this.titleRomaji,
      this.titleEnglish,
      this.titleNative,
      required this.format,
      required this.status,
      this.episodes,
      this.durationMinutes,
      this.season,
      this.seasonYear,
      this.coverUrl,
      this.bannerUrl,
      this.description,
      required this.genresJson,
      this.averageScore,
      required this.updatedAt,
      this.animeSamaTitle});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    if (!nullToAbsent || malId != null) {
      map['mal_id'] = Variable<int>(malId);
    }
    if (!nullToAbsent || titleRomaji != null) {
      map['title_romaji'] = Variable<String>(titleRomaji);
    }
    if (!nullToAbsent || titleEnglish != null) {
      map['title_english'] = Variable<String>(titleEnglish);
    }
    if (!nullToAbsent || titleNative != null) {
      map['title_native'] = Variable<String>(titleNative);
    }
    map['format'] = Variable<String>(format);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || episodes != null) {
      map['episodes'] = Variable<int>(episodes);
    }
    if (!nullToAbsent || durationMinutes != null) {
      map['duration_minutes'] = Variable<int>(durationMinutes);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<String>(season);
    }
    if (!nullToAbsent || seasonYear != null) {
      map['season_year'] = Variable<int>(seasonYear);
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
    if (!nullToAbsent || averageScore != null) {
      map['average_score'] = Variable<int>(averageScore);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || animeSamaTitle != null) {
      map['anime_sama_title'] = Variable<String>(animeSamaTitle);
    }
    return map;
  }

  MediaTableCompanion toCompanion(bool nullToAbsent) {
    return MediaTableCompanion(
      anilistId: Value(anilistId),
      malId:
          malId == null && nullToAbsent ? const Value.absent() : Value(malId),
      titleRomaji: titleRomaji == null && nullToAbsent
          ? const Value.absent()
          : Value(titleRomaji),
      titleEnglish: titleEnglish == null && nullToAbsent
          ? const Value.absent()
          : Value(titleEnglish),
      titleNative: titleNative == null && nullToAbsent
          ? const Value.absent()
          : Value(titleNative),
      format: Value(format),
      status: Value(status),
      episodes: episodes == null && nullToAbsent
          ? const Value.absent()
          : Value(episodes),
      durationMinutes: durationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMinutes),
      season:
          season == null && nullToAbsent ? const Value.absent() : Value(season),
      seasonYear: seasonYear == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonYear),
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
      averageScore: averageScore == null && nullToAbsent
          ? const Value.absent()
          : Value(averageScore),
      updatedAt: Value(updatedAt),
      animeSamaTitle: animeSamaTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(animeSamaTitle),
    );
  }

  factory MediaTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      malId: serializer.fromJson<int?>(json['malId']),
      titleRomaji: serializer.fromJson<String?>(json['titleRomaji']),
      titleEnglish: serializer.fromJson<String?>(json['titleEnglish']),
      titleNative: serializer.fromJson<String?>(json['titleNative']),
      format: serializer.fromJson<String>(json['format']),
      status: serializer.fromJson<String>(json['status']),
      episodes: serializer.fromJson<int?>(json['episodes']),
      durationMinutes: serializer.fromJson<int?>(json['durationMinutes']),
      season: serializer.fromJson<String?>(json['season']),
      seasonYear: serializer.fromJson<int?>(json['seasonYear']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      bannerUrl: serializer.fromJson<String?>(json['bannerUrl']),
      description: serializer.fromJson<String?>(json['description']),
      genresJson: serializer.fromJson<String>(json['genresJson']),
      averageScore: serializer.fromJson<int?>(json['averageScore']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      animeSamaTitle: serializer.fromJson<String?>(json['animeSamaTitle']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'malId': serializer.toJson<int?>(malId),
      'titleRomaji': serializer.toJson<String?>(titleRomaji),
      'titleEnglish': serializer.toJson<String?>(titleEnglish),
      'titleNative': serializer.toJson<String?>(titleNative),
      'format': serializer.toJson<String>(format),
      'status': serializer.toJson<String>(status),
      'episodes': serializer.toJson<int?>(episodes),
      'durationMinutes': serializer.toJson<int?>(durationMinutes),
      'season': serializer.toJson<String?>(season),
      'seasonYear': serializer.toJson<int?>(seasonYear),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'bannerUrl': serializer.toJson<String?>(bannerUrl),
      'description': serializer.toJson<String?>(description),
      'genresJson': serializer.toJson<String>(genresJson),
      'averageScore': serializer.toJson<int?>(averageScore),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'animeSamaTitle': serializer.toJson<String?>(animeSamaTitle),
    };
  }

  MediaTableData copyWith(
          {int? anilistId,
          Value<int?> malId = const Value.absent(),
          Value<String?> titleRomaji = const Value.absent(),
          Value<String?> titleEnglish = const Value.absent(),
          Value<String?> titleNative = const Value.absent(),
          String? format,
          String? status,
          Value<int?> episodes = const Value.absent(),
          Value<int?> durationMinutes = const Value.absent(),
          Value<String?> season = const Value.absent(),
          Value<int?> seasonYear = const Value.absent(),
          Value<String?> coverUrl = const Value.absent(),
          Value<String?> bannerUrl = const Value.absent(),
          Value<String?> description = const Value.absent(),
          String? genresJson,
          Value<int?> averageScore = const Value.absent(),
          DateTime? updatedAt,
          Value<String?> animeSamaTitle = const Value.absent()}) =>
      MediaTableData(
        anilistId: anilistId ?? this.anilistId,
        malId: malId.present ? malId.value : this.malId,
        titleRomaji: titleRomaji.present ? titleRomaji.value : this.titleRomaji,
        titleEnglish:
            titleEnglish.present ? titleEnglish.value : this.titleEnglish,
        titleNative: titleNative.present ? titleNative.value : this.titleNative,
        format: format ?? this.format,
        status: status ?? this.status,
        episodes: episodes.present ? episodes.value : this.episodes,
        durationMinutes: durationMinutes.present
            ? durationMinutes.value
            : this.durationMinutes,
        season: season.present ? season.value : this.season,
        seasonYear: seasonYear.present ? seasonYear.value : this.seasonYear,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        bannerUrl: bannerUrl.present ? bannerUrl.value : this.bannerUrl,
        description: description.present ? description.value : this.description,
        genresJson: genresJson ?? this.genresJson,
        averageScore:
            averageScore.present ? averageScore.value : this.averageScore,
        updatedAt: updatedAt ?? this.updatedAt,
        animeSamaTitle:
            animeSamaTitle.present ? animeSamaTitle.value : this.animeSamaTitle,
      );
  MediaTableData copyWithCompanion(MediaTableCompanion data) {
    return MediaTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      malId: data.malId.present ? data.malId.value : this.malId,
      titleRomaji:
          data.titleRomaji.present ? data.titleRomaji.value : this.titleRomaji,
      titleEnglish: data.titleEnglish.present
          ? data.titleEnglish.value
          : this.titleEnglish,
      titleNative:
          data.titleNative.present ? data.titleNative.value : this.titleNative,
      format: data.format.present ? data.format.value : this.format,
      status: data.status.present ? data.status.value : this.status,
      episodes: data.episodes.present ? data.episodes.value : this.episodes,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      season: data.season.present ? data.season.value : this.season,
      seasonYear:
          data.seasonYear.present ? data.seasonYear.value : this.seasonYear,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      bannerUrl: data.bannerUrl.present ? data.bannerUrl.value : this.bannerUrl,
      description:
          data.description.present ? data.description.value : this.description,
      genresJson:
          data.genresJson.present ? data.genresJson.value : this.genresJson,
      averageScore: data.averageScore.present
          ? data.averageScore.value
          : this.averageScore,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      animeSamaTitle: data.animeSamaTitle.present
          ? data.animeSamaTitle.value
          : this.animeSamaTitle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('malId: $malId, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleEnglish: $titleEnglish, ')
          ..write('titleNative: $titleNative, ')
          ..write('format: $format, ')
          ..write('status: $status, ')
          ..write('episodes: $episodes, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('season: $season, ')
          ..write('seasonYear: $seasonYear, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('bannerUrl: $bannerUrl, ')
          ..write('description: $description, ')
          ..write('genresJson: $genresJson, ')
          ..write('averageScore: $averageScore, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('animeSamaTitle: $animeSamaTitle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      anilistId,
      malId,
      titleRomaji,
      titleEnglish,
      titleNative,
      format,
      status,
      episodes,
      durationMinutes,
      season,
      seasonYear,
      coverUrl,
      bannerUrl,
      description,
      genresJson,
      averageScore,
      updatedAt,
      animeSamaTitle);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaTableData &&
          other.anilistId == this.anilistId &&
          other.malId == this.malId &&
          other.titleRomaji == this.titleRomaji &&
          other.titleEnglish == this.titleEnglish &&
          other.titleNative == this.titleNative &&
          other.format == this.format &&
          other.status == this.status &&
          other.episodes == this.episodes &&
          other.durationMinutes == this.durationMinutes &&
          other.season == this.season &&
          other.seasonYear == this.seasonYear &&
          other.coverUrl == this.coverUrl &&
          other.bannerUrl == this.bannerUrl &&
          other.description == this.description &&
          other.genresJson == this.genresJson &&
          other.averageScore == this.averageScore &&
          other.updatedAt == this.updatedAt &&
          other.animeSamaTitle == this.animeSamaTitle);
}

class MediaTableCompanion extends UpdateCompanion<MediaTableData> {
  final Value<int> anilistId;
  final Value<int?> malId;
  final Value<String?> titleRomaji;
  final Value<String?> titleEnglish;
  final Value<String?> titleNative;
  final Value<String> format;
  final Value<String> status;
  final Value<int?> episodes;
  final Value<int?> durationMinutes;
  final Value<String?> season;
  final Value<int?> seasonYear;
  final Value<String?> coverUrl;
  final Value<String?> bannerUrl;
  final Value<String?> description;
  final Value<String> genresJson;
  final Value<int?> averageScore;
  final Value<DateTime> updatedAt;
  final Value<String?> animeSamaTitle;
  const MediaTableCompanion({
    this.anilistId = const Value.absent(),
    this.malId = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.format = const Value.absent(),
    this.status = const Value.absent(),
    this.episodes = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.season = const Value.absent(),
    this.seasonYear = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.bannerUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.animeSamaTitle = const Value.absent(),
  });
  MediaTableCompanion.insert({
    this.anilistId = const Value.absent(),
    this.malId = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.format = const Value.absent(),
    this.status = const Value.absent(),
    this.episodes = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.season = const Value.absent(),
    this.seasonYear = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.bannerUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.animeSamaTitle = const Value.absent(),
  });
  static Insertable<MediaTableData> custom({
    Expression<int>? anilistId,
    Expression<int>? malId,
    Expression<String>? titleRomaji,
    Expression<String>? titleEnglish,
    Expression<String>? titleNative,
    Expression<String>? format,
    Expression<String>? status,
    Expression<int>? episodes,
    Expression<int>? durationMinutes,
    Expression<String>? season,
    Expression<int>? seasonYear,
    Expression<String>? coverUrl,
    Expression<String>? bannerUrl,
    Expression<String>? description,
    Expression<String>? genresJson,
    Expression<int>? averageScore,
    Expression<DateTime>? updatedAt,
    Expression<String>? animeSamaTitle,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (malId != null) 'mal_id': malId,
      if (titleRomaji != null) 'title_romaji': titleRomaji,
      if (titleEnglish != null) 'title_english': titleEnglish,
      if (titleNative != null) 'title_native': titleNative,
      if (format != null) 'format': format,
      if (status != null) 'status': status,
      if (episodes != null) 'episodes': episodes,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (season != null) 'season': season,
      if (seasonYear != null) 'season_year': seasonYear,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (description != null) 'description': description,
      if (genresJson != null) 'genres_json': genresJson,
      if (averageScore != null) 'average_score': averageScore,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (animeSamaTitle != null) 'anime_sama_title': animeSamaTitle,
    });
  }

  MediaTableCompanion copyWith(
      {Value<int>? anilistId,
      Value<int?>? malId,
      Value<String?>? titleRomaji,
      Value<String?>? titleEnglish,
      Value<String?>? titleNative,
      Value<String>? format,
      Value<String>? status,
      Value<int?>? episodes,
      Value<int?>? durationMinutes,
      Value<String?>? season,
      Value<int?>? seasonYear,
      Value<String?>? coverUrl,
      Value<String?>? bannerUrl,
      Value<String?>? description,
      Value<String>? genresJson,
      Value<int?>? averageScore,
      Value<DateTime>? updatedAt,
      Value<String?>? animeSamaTitle}) {
    return MediaTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      malId: malId ?? this.malId,
      titleRomaji: titleRomaji ?? this.titleRomaji,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      titleNative: titleNative ?? this.titleNative,
      format: format ?? this.format,
      status: status ?? this.status,
      episodes: episodes ?? this.episodes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      season: season ?? this.season,
      seasonYear: seasonYear ?? this.seasonYear,
      coverUrl: coverUrl ?? this.coverUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      genresJson: genresJson ?? this.genresJson,
      averageScore: averageScore ?? this.averageScore,
      updatedAt: updatedAt ?? this.updatedAt,
      animeSamaTitle: animeSamaTitle ?? this.animeSamaTitle,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (malId.present) {
      map['mal_id'] = Variable<int>(malId.value);
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
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (episodes.present) {
      map['episodes'] = Variable<int>(episodes.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (season.present) {
      map['season'] = Variable<String>(season.value);
    }
    if (seasonYear.present) {
      map['season_year'] = Variable<int>(seasonYear.value);
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
    if (averageScore.present) {
      map['average_score'] = Variable<int>(averageScore.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (animeSamaTitle.present) {
      map['anime_sama_title'] = Variable<String>(animeSamaTitle.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('malId: $malId, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleEnglish: $titleEnglish, ')
          ..write('titleNative: $titleNative, ')
          ..write('format: $format, ')
          ..write('status: $status, ')
          ..write('episodes: $episodes, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('season: $season, ')
          ..write('seasonYear: $seasonYear, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('bannerUrl: $bannerUrl, ')
          ..write('description: $description, ')
          ..write('genresJson: $genresJson, ')
          ..write('averageScore: $averageScore, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('animeSamaTitle: $animeSamaTitle')
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
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
      'score', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _favoriteMeta =
      const VerificationMeta('favorite');
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
      'favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
  static const VerificationMeta _anilistEntryIdMeta =
      const VerificationMeta('anilistEntryId');
  @override
  late final GeneratedColumn<int> anilistEntryId = GeneratedColumn<int>(
      'anilist_entry_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        mediaId,
        status,
        progress,
        score,
        favorite,
        notes,
        hiddenFromPlanning,
        anilistEntryId,
        updatedAt,
        syncedAt
      ];
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
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    }
    if (data.containsKey('favorite')) {
      context.handle(_favoriteMeta,
          favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('hidden_from_planning')) {
      context.handle(
          _hiddenFromPlanningMeta,
          hiddenFromPlanning.isAcceptableOrUnknown(
              data['hidden_from_planning']!, _hiddenFromPlanningMeta));
    }
    if (data.containsKey('anilist_entry_id')) {
      context.handle(
          _anilistEntryIdMeta,
          anilistEntryId.isAcceptableOrUnknown(
              data['anilist_entry_id']!, _anilistEntryIdMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
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
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score']),
      favorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}favorite'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      hiddenFromPlanning: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}hidden_from_planning'])!,
      anilistEntryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}anilist_entry_id']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
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
  final double? score;
  final bool favorite;
  final String? notes;
  final bool hiddenFromPlanning;

  /// ID entrée AniList (optionnel).
  final int? anilistEntryId;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  const ListEntryRow(
      {required this.mediaId,
      required this.status,
      required this.progress,
      this.score,
      required this.favorite,
      this.notes,
      required this.hiddenFromPlanning,
      this.anilistEntryId,
      required this.updatedAt,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<int>(mediaId);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<int>(progress);
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    map['favorite'] = Variable<bool>(favorite);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['hidden_from_planning'] = Variable<bool>(hiddenFromPlanning);
    if (!nullToAbsent || anilistEntryId != null) {
      map['anilist_entry_id'] = Variable<int>(anilistEntryId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  ListEntriesCompanion toCompanion(bool nullToAbsent) {
    return ListEntriesCompanion(
      mediaId: Value(mediaId),
      status: Value(status),
      progress: Value(progress),
      score:
          score == null && nullToAbsent ? const Value.absent() : Value(score),
      favorite: Value(favorite),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      hiddenFromPlanning: Value(hiddenFromPlanning),
      anilistEntryId: anilistEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(anilistEntryId),
      updatedAt: Value(updatedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory ListEntryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListEntryRow(
      mediaId: serializer.fromJson<int>(json['mediaId']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<int>(json['progress']),
      score: serializer.fromJson<double?>(json['score']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      notes: serializer.fromJson<String?>(json['notes']),
      hiddenFromPlanning: serializer.fromJson<bool>(json['hiddenFromPlanning']),
      anilistEntryId: serializer.fromJson<int?>(json['anilistEntryId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<int>(mediaId),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<int>(progress),
      'score': serializer.toJson<double?>(score),
      'favorite': serializer.toJson<bool>(favorite),
      'notes': serializer.toJson<String?>(notes),
      'hiddenFromPlanning': serializer.toJson<bool>(hiddenFromPlanning),
      'anilistEntryId': serializer.toJson<int?>(anilistEntryId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  ListEntryRow copyWith(
          {int? mediaId,
          String? status,
          int? progress,
          Value<double?> score = const Value.absent(),
          bool? favorite,
          Value<String?> notes = const Value.absent(),
          bool? hiddenFromPlanning,
          Value<int?> anilistEntryId = const Value.absent(),
          DateTime? updatedAt,
          Value<DateTime?> syncedAt = const Value.absent()}) =>
      ListEntryRow(
        mediaId: mediaId ?? this.mediaId,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        score: score.present ? score.value : this.score,
        favorite: favorite ?? this.favorite,
        notes: notes.present ? notes.value : this.notes,
        hiddenFromPlanning: hiddenFromPlanning ?? this.hiddenFromPlanning,
        anilistEntryId:
            anilistEntryId.present ? anilistEntryId.value : this.anilistEntryId,
        updatedAt: updatedAt ?? this.updatedAt,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  ListEntryRow copyWithCompanion(ListEntriesCompanion data) {
    return ListEntryRow(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      score: data.score.present ? data.score.value : this.score,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      notes: data.notes.present ? data.notes.value : this.notes,
      hiddenFromPlanning: data.hiddenFromPlanning.present
          ? data.hiddenFromPlanning.value
          : this.hiddenFromPlanning,
      anilistEntryId: data.anilistEntryId.present
          ? data.anilistEntryId.value
          : this.anilistEntryId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListEntryRow(')
          ..write('mediaId: $mediaId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('score: $score, ')
          ..write('favorite: $favorite, ')
          ..write('notes: $notes, ')
          ..write('hiddenFromPlanning: $hiddenFromPlanning, ')
          ..write('anilistEntryId: $anilistEntryId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaId, status, progress, score, favorite,
      notes, hiddenFromPlanning, anilistEntryId, updatedAt, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListEntryRow &&
          other.mediaId == this.mediaId &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.score == this.score &&
          other.favorite == this.favorite &&
          other.notes == this.notes &&
          other.hiddenFromPlanning == this.hiddenFromPlanning &&
          other.anilistEntryId == this.anilistEntryId &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt);
}

class ListEntriesCompanion extends UpdateCompanion<ListEntryRow> {
  final Value<int> mediaId;
  final Value<String> status;
  final Value<int> progress;
  final Value<double?> score;
  final Value<bool> favorite;
  final Value<String?> notes;
  final Value<bool> hiddenFromPlanning;
  final Value<int?> anilistEntryId;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> syncedAt;
  const ListEntriesCompanion({
    this.mediaId = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.score = const Value.absent(),
    this.favorite = const Value.absent(),
    this.notes = const Value.absent(),
    this.hiddenFromPlanning = const Value.absent(),
    this.anilistEntryId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  ListEntriesCompanion.insert({
    this.mediaId = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.score = const Value.absent(),
    this.favorite = const Value.absent(),
    this.notes = const Value.absent(),
    this.hiddenFromPlanning = const Value.absent(),
    this.anilistEntryId = const Value.absent(),
    required DateTime updatedAt,
    this.syncedAt = const Value.absent(),
  }) : updatedAt = Value(updatedAt);
  static Insertable<ListEntryRow> custom({
    Expression<int>? mediaId,
    Expression<String>? status,
    Expression<int>? progress,
    Expression<double>? score,
    Expression<bool>? favorite,
    Expression<String>? notes,
    Expression<bool>? hiddenFromPlanning,
    Expression<int>? anilistEntryId,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (score != null) 'score': score,
      if (favorite != null) 'favorite': favorite,
      if (notes != null) 'notes': notes,
      if (hiddenFromPlanning != null)
        'hidden_from_planning': hiddenFromPlanning,
      if (anilistEntryId != null) 'anilist_entry_id': anilistEntryId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  ListEntriesCompanion copyWith(
      {Value<int>? mediaId,
      Value<String>? status,
      Value<int>? progress,
      Value<double?>? score,
      Value<bool>? favorite,
      Value<String?>? notes,
      Value<bool>? hiddenFromPlanning,
      Value<int?>? anilistEntryId,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? syncedAt}) {
    return ListEntriesCompanion(
      mediaId: mediaId ?? this.mediaId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      score: score ?? this.score,
      favorite: favorite ?? this.favorite,
      notes: notes ?? this.notes,
      hiddenFromPlanning: hiddenFromPlanning ?? this.hiddenFromPlanning,
      anilistEntryId: anilistEntryId ?? this.anilistEntryId,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
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
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (hiddenFromPlanning.present) {
      map['hidden_from_planning'] = Variable<bool>(hiddenFromPlanning.value);
    }
    if (anilistEntryId.present) {
      map['anilist_entry_id'] = Variable<int>(anilistEntryId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListEntriesCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('score: $score, ')
          ..write('favorite: $favorite, ')
          ..write('notes: $notes, ')
          ..write('hiddenFromPlanning: $hiddenFromPlanning, ')
          ..write('anilistEntryId: $anilistEntryId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt')
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

class $MediaRelationsTable extends MediaRelations
    with TableInfo<$MediaRelationsTable, MediaRelationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaRelationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta =
      const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
      'media_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _relatedMediaIdMeta =
      const VerificationMeta('relatedMediaId');
  @override
  late final GeneratedColumn<int> relatedMediaId = GeneratedColumn<int>(
      'related_media_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _relationTypeMeta =
      const VerificationMeta('relationType');
  @override
  late final GeneratedColumn<String> relationType = GeneratedColumn<String>(
      'relation_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [mediaId, relatedMediaId, relationType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_relations';
  @override
  VerificationContext validateIntegrity(Insertable<MediaRelationRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta,
          mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('related_media_id')) {
      context.handle(
          _relatedMediaIdMeta,
          relatedMediaId.isAcceptableOrUnknown(
              data['related_media_id']!, _relatedMediaIdMeta));
    } else if (isInserting) {
      context.missing(_relatedMediaIdMeta);
    }
    if (data.containsKey('relation_type')) {
      context.handle(
          _relationTypeMeta,
          relationType.isAcceptableOrUnknown(
              data['relation_type']!, _relationTypeMeta));
    } else if (isInserting) {
      context.missing(_relationTypeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId, relatedMediaId};
  @override
  MediaRelationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaRelationRow(
      mediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_id'])!,
      relatedMediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}related_media_id'])!,
      relationType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}relation_type'])!,
    );
  }

  @override
  $MediaRelationsTable createAlias(String alias) {
    return $MediaRelationsTable(attachedDatabase, alias);
  }
}

class MediaRelationRow extends DataClass
    implements Insertable<MediaRelationRow> {
  final int mediaId;
  final int relatedMediaId;

  /// Type de relation stocké en TEXT (.name).
  final String relationType;
  const MediaRelationRow(
      {required this.mediaId,
      required this.relatedMediaId,
      required this.relationType});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<int>(mediaId);
    map['related_media_id'] = Variable<int>(relatedMediaId);
    map['relation_type'] = Variable<String>(relationType);
    return map;
  }

  MediaRelationsCompanion toCompanion(bool nullToAbsent) {
    return MediaRelationsCompanion(
      mediaId: Value(mediaId),
      relatedMediaId: Value(relatedMediaId),
      relationType: Value(relationType),
    );
  }

  factory MediaRelationRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaRelationRow(
      mediaId: serializer.fromJson<int>(json['mediaId']),
      relatedMediaId: serializer.fromJson<int>(json['relatedMediaId']),
      relationType: serializer.fromJson<String>(json['relationType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<int>(mediaId),
      'relatedMediaId': serializer.toJson<int>(relatedMediaId),
      'relationType': serializer.toJson<String>(relationType),
    };
  }

  MediaRelationRow copyWith(
          {int? mediaId, int? relatedMediaId, String? relationType}) =>
      MediaRelationRow(
        mediaId: mediaId ?? this.mediaId,
        relatedMediaId: relatedMediaId ?? this.relatedMediaId,
        relationType: relationType ?? this.relationType,
      );
  MediaRelationRow copyWithCompanion(MediaRelationsCompanion data) {
    return MediaRelationRow(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      relatedMediaId: data.relatedMediaId.present
          ? data.relatedMediaId.value
          : this.relatedMediaId,
      relationType: data.relationType.present
          ? data.relationType.value
          : this.relationType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaRelationRow(')
          ..write('mediaId: $mediaId, ')
          ..write('relatedMediaId: $relatedMediaId, ')
          ..write('relationType: $relationType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaId, relatedMediaId, relationType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaRelationRow &&
          other.mediaId == this.mediaId &&
          other.relatedMediaId == this.relatedMediaId &&
          other.relationType == this.relationType);
}

class MediaRelationsCompanion extends UpdateCompanion<MediaRelationRow> {
  final Value<int> mediaId;
  final Value<int> relatedMediaId;
  final Value<String> relationType;
  final Value<int> rowid;
  const MediaRelationsCompanion({
    this.mediaId = const Value.absent(),
    this.relatedMediaId = const Value.absent(),
    this.relationType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaRelationsCompanion.insert({
    required int mediaId,
    required int relatedMediaId,
    required String relationType,
    this.rowid = const Value.absent(),
  })  : mediaId = Value(mediaId),
        relatedMediaId = Value(relatedMediaId),
        relationType = Value(relationType);
  static Insertable<MediaRelationRow> custom({
    Expression<int>? mediaId,
    Expression<int>? relatedMediaId,
    Expression<String>? relationType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (relatedMediaId != null) 'related_media_id': relatedMediaId,
      if (relationType != null) 'relation_type': relationType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaRelationsCompanion copyWith(
      {Value<int>? mediaId,
      Value<int>? relatedMediaId,
      Value<String>? relationType,
      Value<int>? rowid}) {
    return MediaRelationsCompanion(
      mediaId: mediaId ?? this.mediaId,
      relatedMediaId: relatedMediaId ?? this.relatedMediaId,
      relationType: relationType ?? this.relationType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (relatedMediaId.present) {
      map['related_media_id'] = Variable<int>(relatedMediaId.value);
    }
    if (relationType.present) {
      map['relation_type'] = Variable<String>(relationType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaRelationsCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('relatedMediaId: $relatedMediaId, ')
          ..write('relationType: $relationType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiringSchedulesTable extends AiringSchedules
    with TableInfo<$AiringSchedulesTable, AiringScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiringSchedulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _episodeMeta =
      const VerificationMeta('episode');
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
      'episode', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _airsAtMeta = const VerificationMeta('airsAt');
  @override
  late final GeneratedColumn<DateTime> airsAt = GeneratedColumn<DateTime>(
      'airs_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _notifiedMeta =
      const VerificationMeta('notified');
  @override
  late final GeneratedColumn<bool> notified = GeneratedColumn<bool>(
      'notified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("notified" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, mediaId, episode, airsAt, notified];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'airing_schedules';
  @override
  VerificationContext validateIntegrity(Insertable<AiringScheduleRow> instance,
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
    if (data.containsKey('episode')) {
      context.handle(_episodeMeta,
          episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta));
    } else if (isInserting) {
      context.missing(_episodeMeta);
    }
    if (data.containsKey('airs_at')) {
      context.handle(_airsAtMeta,
          airsAt.isAcceptableOrUnknown(data['airs_at']!, _airsAtMeta));
    } else if (isInserting) {
      context.missing(_airsAtMeta);
    }
    if (data.containsKey('notified')) {
      context.handle(_notifiedMeta,
          notified.isAcceptableOrUnknown(data['notified']!, _notifiedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiringScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiringScheduleRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_id'])!,
      episode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episode'])!,
      airsAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}airs_at'])!,
      notified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}notified'])!,
    );
  }

  @override
  $AiringSchedulesTable createAlias(String alias) {
    return $AiringSchedulesTable(attachedDatabase, alias);
  }
}

class AiringScheduleRow extends DataClass
    implements Insertable<AiringScheduleRow> {
  final int id;
  final int mediaId;
  final int episode;
  final DateTime airsAt;
  final bool notified;
  const AiringScheduleRow(
      {required this.id,
      required this.mediaId,
      required this.episode,
      required this.airsAt,
      required this.notified});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['media_id'] = Variable<int>(mediaId);
    map['episode'] = Variable<int>(episode);
    map['airs_at'] = Variable<DateTime>(airsAt);
    map['notified'] = Variable<bool>(notified);
    return map;
  }

  AiringSchedulesCompanion toCompanion(bool nullToAbsent) {
    return AiringSchedulesCompanion(
      id: Value(id),
      mediaId: Value(mediaId),
      episode: Value(episode),
      airsAt: Value(airsAt),
      notified: Value(notified),
    );
  }

  factory AiringScheduleRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiringScheduleRow(
      id: serializer.fromJson<int>(json['id']),
      mediaId: serializer.fromJson<int>(json['mediaId']),
      episode: serializer.fromJson<int>(json['episode']),
      airsAt: serializer.fromJson<DateTime>(json['airsAt']),
      notified: serializer.fromJson<bool>(json['notified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mediaId': serializer.toJson<int>(mediaId),
      'episode': serializer.toJson<int>(episode),
      'airsAt': serializer.toJson<DateTime>(airsAt),
      'notified': serializer.toJson<bool>(notified),
    };
  }

  AiringScheduleRow copyWith(
          {int? id,
          int? mediaId,
          int? episode,
          DateTime? airsAt,
          bool? notified}) =>
      AiringScheduleRow(
        id: id ?? this.id,
        mediaId: mediaId ?? this.mediaId,
        episode: episode ?? this.episode,
        airsAt: airsAt ?? this.airsAt,
        notified: notified ?? this.notified,
      );
  AiringScheduleRow copyWithCompanion(AiringSchedulesCompanion data) {
    return AiringScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      episode: data.episode.present ? data.episode.value : this.episode,
      airsAt: data.airsAt.present ? data.airsAt.value : this.airsAt,
      notified: data.notified.present ? data.notified.value : this.notified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiringScheduleRow(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('episode: $episode, ')
          ..write('airsAt: $airsAt, ')
          ..write('notified: $notified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mediaId, episode, airsAt, notified);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiringScheduleRow &&
          other.id == this.id &&
          other.mediaId == this.mediaId &&
          other.episode == this.episode &&
          other.airsAt == this.airsAt &&
          other.notified == this.notified);
}

class AiringSchedulesCompanion extends UpdateCompanion<AiringScheduleRow> {
  final Value<int> id;
  final Value<int> mediaId;
  final Value<int> episode;
  final Value<DateTime> airsAt;
  final Value<bool> notified;
  const AiringSchedulesCompanion({
    this.id = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.episode = const Value.absent(),
    this.airsAt = const Value.absent(),
    this.notified = const Value.absent(),
  });
  AiringSchedulesCompanion.insert({
    this.id = const Value.absent(),
    required int mediaId,
    required int episode,
    required DateTime airsAt,
    this.notified = const Value.absent(),
  })  : mediaId = Value(mediaId),
        episode = Value(episode),
        airsAt = Value(airsAt);
  static Insertable<AiringScheduleRow> custom({
    Expression<int>? id,
    Expression<int>? mediaId,
    Expression<int>? episode,
    Expression<DateTime>? airsAt,
    Expression<bool>? notified,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaId != null) 'media_id': mediaId,
      if (episode != null) 'episode': episode,
      if (airsAt != null) 'airs_at': airsAt,
      if (notified != null) 'notified': notified,
    });
  }

  AiringSchedulesCompanion copyWith(
      {Value<int>? id,
      Value<int>? mediaId,
      Value<int>? episode,
      Value<DateTime>? airsAt,
      Value<bool>? notified}) {
    return AiringSchedulesCompanion(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      episode: episode ?? this.episode,
      airsAt: airsAt ?? this.airsAt,
      notified: notified ?? this.notified,
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
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (airsAt.present) {
      map['airs_at'] = Variable<DateTime>(airsAt.value);
    }
    if (notified.present) {
      map['notified'] = Variable<bool>(notified.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiringSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('episode: $episode, ')
          ..write('airsAt: $airsAt, ')
          ..write('notified: $notified')
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
  late final $MediaRelationsTable mediaRelations = $MediaRelationsTable(this);
  late final $AiringSchedulesTable airingSchedules =
      $AiringSchedulesTable(this);
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
        mediaRelations,
        airingSchedules,
        appSettings,
        metaCache
      ];
}

typedef $$MediaTableTableCreateCompanionBuilder = MediaTableCompanion Function({
  Value<int> anilistId,
  Value<int?> malId,
  Value<String?> titleRomaji,
  Value<String?> titleEnglish,
  Value<String?> titleNative,
  Value<String> format,
  Value<String> status,
  Value<int?> episodes,
  Value<int?> durationMinutes,
  Value<String?> season,
  Value<int?> seasonYear,
  Value<String?> coverUrl,
  Value<String?> bannerUrl,
  Value<String?> description,
  Value<String> genresJson,
  Value<int?> averageScore,
  Value<DateTime> updatedAt,
  Value<String?> animeSamaTitle,
});
typedef $$MediaTableTableUpdateCompanionBuilder = MediaTableCompanion Function({
  Value<int> anilistId,
  Value<int?> malId,
  Value<String?> titleRomaji,
  Value<String?> titleEnglish,
  Value<String?> titleNative,
  Value<String> format,
  Value<String> status,
  Value<int?> episodes,
  Value<int?> durationMinutes,
  Value<String?> season,
  Value<int?> seasonYear,
  Value<String?> coverUrl,
  Value<String?> bannerUrl,
  Value<String?> description,
  Value<String> genresJson,
  Value<int?> averageScore,
  Value<DateTime> updatedAt,
  Value<String?> animeSamaTitle,
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

  ColumnFilters<int> get malId => $composableBuilder(
      column: $table.malId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleRomaji => $composableBuilder(
      column: $table.titleRomaji, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleEnglish => $composableBuilder(
      column: $table.titleEnglish, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleNative => $composableBuilder(
      column: $table.titleNative, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get episodes => $composableBuilder(
      column: $table.episodes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get season => $composableBuilder(
      column: $table.season, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seasonYear => $composableBuilder(
      column: $table.seasonYear, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bannerUrl => $composableBuilder(
      column: $table.bannerUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get averageScore => $composableBuilder(
      column: $table.averageScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get animeSamaTitle => $composableBuilder(
      column: $table.animeSamaTitle,
      builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<int> get malId => $composableBuilder(
      column: $table.malId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleRomaji => $composableBuilder(
      column: $table.titleRomaji, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleEnglish => $composableBuilder(
      column: $table.titleEnglish,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleNative => $composableBuilder(
      column: $table.titleNative, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get episodes => $composableBuilder(
      column: $table.episodes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get season => $composableBuilder(
      column: $table.season, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seasonYear => $composableBuilder(
      column: $table.seasonYear, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bannerUrl => $composableBuilder(
      column: $table.bannerUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get averageScore => $composableBuilder(
      column: $table.averageScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get animeSamaTitle => $composableBuilder(
      column: $table.animeSamaTitle,
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

  GeneratedColumn<int> get malId =>
      $composableBuilder(column: $table.malId, builder: (column) => column);

  GeneratedColumn<String> get titleRomaji => $composableBuilder(
      column: $table.titleRomaji, builder: (column) => column);

  GeneratedColumn<String> get titleEnglish => $composableBuilder(
      column: $table.titleEnglish, builder: (column) => column);

  GeneratedColumn<String> get titleNative => $composableBuilder(
      column: $table.titleNative, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get episodes =>
      $composableBuilder(column: $table.episodes, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes, builder: (column) => column);

  GeneratedColumn<String> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get seasonYear => $composableBuilder(
      column: $table.seasonYear, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get bannerUrl =>
      $composableBuilder(column: $table.bannerUrl, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get genresJson => $composableBuilder(
      column: $table.genresJson, builder: (column) => column);

  GeneratedColumn<int> get averageScore => $composableBuilder(
      column: $table.averageScore, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get animeSamaTitle => $composableBuilder(
      column: $table.animeSamaTitle, builder: (column) => column);
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
            Value<int?> malId = const Value.absent(),
            Value<String?> titleRomaji = const Value.absent(),
            Value<String?> titleEnglish = const Value.absent(),
            Value<String?> titleNative = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> episodes = const Value.absent(),
            Value<int?> durationMinutes = const Value.absent(),
            Value<String?> season = const Value.absent(),
            Value<int?> seasonYear = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> bannerUrl = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> genresJson = const Value.absent(),
            Value<int?> averageScore = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> animeSamaTitle = const Value.absent(),
          }) =>
              MediaTableCompanion(
            anilistId: anilistId,
            malId: malId,
            titleRomaji: titleRomaji,
            titleEnglish: titleEnglish,
            titleNative: titleNative,
            format: format,
            status: status,
            episodes: episodes,
            durationMinutes: durationMinutes,
            season: season,
            seasonYear: seasonYear,
            coverUrl: coverUrl,
            bannerUrl: bannerUrl,
            description: description,
            genresJson: genresJson,
            averageScore: averageScore,
            updatedAt: updatedAt,
            animeSamaTitle: animeSamaTitle,
          ),
          createCompanionCallback: ({
            Value<int> anilistId = const Value.absent(),
            Value<int?> malId = const Value.absent(),
            Value<String?> titleRomaji = const Value.absent(),
            Value<String?> titleEnglish = const Value.absent(),
            Value<String?> titleNative = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> episodes = const Value.absent(),
            Value<int?> durationMinutes = const Value.absent(),
            Value<String?> season = const Value.absent(),
            Value<int?> seasonYear = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> bannerUrl = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> genresJson = const Value.absent(),
            Value<int?> averageScore = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> animeSamaTitle = const Value.absent(),
          }) =>
              MediaTableCompanion.insert(
            anilistId: anilistId,
            malId: malId,
            titleRomaji: titleRomaji,
            titleEnglish: titleEnglish,
            titleNative: titleNative,
            format: format,
            status: status,
            episodes: episodes,
            durationMinutes: durationMinutes,
            season: season,
            seasonYear: seasonYear,
            coverUrl: coverUrl,
            bannerUrl: bannerUrl,
            description: description,
            genresJson: genresJson,
            averageScore: averageScore,
            updatedAt: updatedAt,
            animeSamaTitle: animeSamaTitle,
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
  Value<double?> score,
  Value<bool> favorite,
  Value<String?> notes,
  Value<bool> hiddenFromPlanning,
  Value<int?> anilistEntryId,
  required DateTime updatedAt,
  Value<DateTime?> syncedAt,
});
typedef $$ListEntriesTableUpdateCompanionBuilder = ListEntriesCompanion
    Function({
  Value<int> mediaId,
  Value<String> status,
  Value<int> progress,
  Value<double?> score,
  Value<bool> favorite,
  Value<String?> notes,
  Value<bool> hiddenFromPlanning,
  Value<int?> anilistEntryId,
  Value<DateTime> updatedAt,
  Value<DateTime?> syncedAt,
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

  ColumnFilters<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get favorite => $composableBuilder(
      column: $table.favorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hiddenFromPlanning => $composableBuilder(
      column: $table.hiddenFromPlanning,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get anilistEntryId => $composableBuilder(
      column: $table.anilistEntryId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get favorite => $composableBuilder(
      column: $table.favorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hiddenFromPlanning => $composableBuilder(
      column: $table.hiddenFromPlanning,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get anilistEntryId => $composableBuilder(
      column: $table.anilistEntryId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get hiddenFromPlanning => $composableBuilder(
      column: $table.hiddenFromPlanning, builder: (column) => column);

  GeneratedColumn<int> get anilistEntryId => $composableBuilder(
      column: $table.anilistEntryId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
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
            Value<double?> score = const Value.absent(),
            Value<bool> favorite = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<bool> hiddenFromPlanning = const Value.absent(),
            Value<int?> anilistEntryId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
          }) =>
              ListEntriesCompanion(
            mediaId: mediaId,
            status: status,
            progress: progress,
            score: score,
            favorite: favorite,
            notes: notes,
            hiddenFromPlanning: hiddenFromPlanning,
            anilistEntryId: anilistEntryId,
            updatedAt: updatedAt,
            syncedAt: syncedAt,
          ),
          createCompanionCallback: ({
            Value<int> mediaId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> progress = const Value.absent(),
            Value<double?> score = const Value.absent(),
            Value<bool> favorite = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<bool> hiddenFromPlanning = const Value.absent(),
            Value<int?> anilistEntryId = const Value.absent(),
            required DateTime updatedAt,
            Value<DateTime?> syncedAt = const Value.absent(),
          }) =>
              ListEntriesCompanion.insert(
            mediaId: mediaId,
            status: status,
            progress: progress,
            score: score,
            favorite: favorite,
            notes: notes,
            hiddenFromPlanning: hiddenFromPlanning,
            anilistEntryId: anilistEntryId,
            updatedAt: updatedAt,
            syncedAt: syncedAt,
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
typedef $$MediaRelationsTableCreateCompanionBuilder = MediaRelationsCompanion
    Function({
  required int mediaId,
  required int relatedMediaId,
  required String relationType,
  Value<int> rowid,
});
typedef $$MediaRelationsTableUpdateCompanionBuilder = MediaRelationsCompanion
    Function({
  Value<int> mediaId,
  Value<int> relatedMediaId,
  Value<String> relationType,
  Value<int> rowid,
});

class $$MediaRelationsTableFilterComposer
    extends Composer<_$TerebiDatabase, $MediaRelationsTable> {
  $$MediaRelationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get relatedMediaId => $composableBuilder(
      column: $table.relatedMediaId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relationType => $composableBuilder(
      column: $table.relationType, builder: (column) => ColumnFilters(column));
}

class $$MediaRelationsTableOrderingComposer
    extends Composer<_$TerebiDatabase, $MediaRelationsTable> {
  $$MediaRelationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get relatedMediaId => $composableBuilder(
      column: $table.relatedMediaId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relationType => $composableBuilder(
      column: $table.relationType,
      builder: (column) => ColumnOrderings(column));
}

class $$MediaRelationsTableAnnotationComposer
    extends Composer<_$TerebiDatabase, $MediaRelationsTable> {
  $$MediaRelationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<int> get relatedMediaId => $composableBuilder(
      column: $table.relatedMediaId, builder: (column) => column);

  GeneratedColumn<String> get relationType => $composableBuilder(
      column: $table.relationType, builder: (column) => column);
}

class $$MediaRelationsTableTableManager extends RootTableManager<
    _$TerebiDatabase,
    $MediaRelationsTable,
    MediaRelationRow,
    $$MediaRelationsTableFilterComposer,
    $$MediaRelationsTableOrderingComposer,
    $$MediaRelationsTableAnnotationComposer,
    $$MediaRelationsTableCreateCompanionBuilder,
    $$MediaRelationsTableUpdateCompanionBuilder,
    (
      MediaRelationRow,
      BaseReferences<_$TerebiDatabase, $MediaRelationsTable, MediaRelationRow>
    ),
    MediaRelationRow,
    PrefetchHooks Function()> {
  $$MediaRelationsTableTableManager(
      _$TerebiDatabase db, $MediaRelationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaRelationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaRelationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaRelationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> mediaId = const Value.absent(),
            Value<int> relatedMediaId = const Value.absent(),
            Value<String> relationType = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaRelationsCompanion(
            mediaId: mediaId,
            relatedMediaId: relatedMediaId,
            relationType: relationType,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int mediaId,
            required int relatedMediaId,
            required String relationType,
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaRelationsCompanion.insert(
            mediaId: mediaId,
            relatedMediaId: relatedMediaId,
            relationType: relationType,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MediaRelationsTableProcessedTableManager = ProcessedTableManager<
    _$TerebiDatabase,
    $MediaRelationsTable,
    MediaRelationRow,
    $$MediaRelationsTableFilterComposer,
    $$MediaRelationsTableOrderingComposer,
    $$MediaRelationsTableAnnotationComposer,
    $$MediaRelationsTableCreateCompanionBuilder,
    $$MediaRelationsTableUpdateCompanionBuilder,
    (
      MediaRelationRow,
      BaseReferences<_$TerebiDatabase, $MediaRelationsTable, MediaRelationRow>
    ),
    MediaRelationRow,
    PrefetchHooks Function()>;
typedef $$AiringSchedulesTableCreateCompanionBuilder = AiringSchedulesCompanion
    Function({
  Value<int> id,
  required int mediaId,
  required int episode,
  required DateTime airsAt,
  Value<bool> notified,
});
typedef $$AiringSchedulesTableUpdateCompanionBuilder = AiringSchedulesCompanion
    Function({
  Value<int> id,
  Value<int> mediaId,
  Value<int> episode,
  Value<DateTime> airsAt,
  Value<bool> notified,
});

class $$AiringSchedulesTableFilterComposer
    extends Composer<_$TerebiDatabase, $AiringSchedulesTable> {
  $$AiringSchedulesTableFilterComposer({
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

  ColumnFilters<int> get episode => $composableBuilder(
      column: $table.episode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get airsAt => $composableBuilder(
      column: $table.airsAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get notified => $composableBuilder(
      column: $table.notified, builder: (column) => ColumnFilters(column));
}

class $$AiringSchedulesTableOrderingComposer
    extends Composer<_$TerebiDatabase, $AiringSchedulesTable> {
  $$AiringSchedulesTableOrderingComposer({
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

  ColumnOrderings<int> get episode => $composableBuilder(
      column: $table.episode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get airsAt => $composableBuilder(
      column: $table.airsAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get notified => $composableBuilder(
      column: $table.notified, builder: (column) => ColumnOrderings(column));
}

class $$AiringSchedulesTableAnnotationComposer
    extends Composer<_$TerebiDatabase, $AiringSchedulesTable> {
  $$AiringSchedulesTableAnnotationComposer({
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

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<DateTime> get airsAt =>
      $composableBuilder(column: $table.airsAt, builder: (column) => column);

  GeneratedColumn<bool> get notified =>
      $composableBuilder(column: $table.notified, builder: (column) => column);
}

class $$AiringSchedulesTableTableManager extends RootTableManager<
    _$TerebiDatabase,
    $AiringSchedulesTable,
    AiringScheduleRow,
    $$AiringSchedulesTableFilterComposer,
    $$AiringSchedulesTableOrderingComposer,
    $$AiringSchedulesTableAnnotationComposer,
    $$AiringSchedulesTableCreateCompanionBuilder,
    $$AiringSchedulesTableUpdateCompanionBuilder,
    (
      AiringScheduleRow,
      BaseReferences<_$TerebiDatabase, $AiringSchedulesTable, AiringScheduleRow>
    ),
    AiringScheduleRow,
    PrefetchHooks Function()> {
  $$AiringSchedulesTableTableManager(
      _$TerebiDatabase db, $AiringSchedulesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiringSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiringSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiringSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> mediaId = const Value.absent(),
            Value<int> episode = const Value.absent(),
            Value<DateTime> airsAt = const Value.absent(),
            Value<bool> notified = const Value.absent(),
          }) =>
              AiringSchedulesCompanion(
            id: id,
            mediaId: mediaId,
            episode: episode,
            airsAt: airsAt,
            notified: notified,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int mediaId,
            required int episode,
            required DateTime airsAt,
            Value<bool> notified = const Value.absent(),
          }) =>
              AiringSchedulesCompanion.insert(
            id: id,
            mediaId: mediaId,
            episode: episode,
            airsAt: airsAt,
            notified: notified,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AiringSchedulesTableProcessedTableManager = ProcessedTableManager<
    _$TerebiDatabase,
    $AiringSchedulesTable,
    AiringScheduleRow,
    $$AiringSchedulesTableFilterComposer,
    $$AiringSchedulesTableOrderingComposer,
    $$AiringSchedulesTableAnnotationComposer,
    $$AiringSchedulesTableCreateCompanionBuilder,
    $$AiringSchedulesTableUpdateCompanionBuilder,
    (
      AiringScheduleRow,
      BaseReferences<_$TerebiDatabase, $AiringSchedulesTable, AiringScheduleRow>
    ),
    AiringScheduleRow,
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
  $$MediaRelationsTableTableManager get mediaRelations =>
      $$MediaRelationsTableTableManager(_db, _db.mediaRelations);
  $$AiringSchedulesTableTableManager get airingSchedules =>
      $$AiringSchedulesTableTableManager(_db, _db.airingSchedules);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$MetaCacheTableTableManager get metaCache =>
      $$MetaCacheTableTableManager(_db, _db.metaCache);
}
