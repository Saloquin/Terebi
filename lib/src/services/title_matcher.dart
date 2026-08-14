/// Résout un titre anime-sama en [Media] exploitable.
///
/// **anime-sama est la source de vérité** : l'identité d'un anime dérive TOUJOURS
/// de son titre anime-sama ([animeSamaIdFor], id négatif stable), jamais de
/// l'`anilistId`. AniList n'est qu'un **enrichissement optionnel** (image +
/// description) appliqué UNIQUEMENT si le titre trouvé ressemble vraiment au
/// titre cherché ([titlesSimilar]). Un mauvais match AniList (ex.
/// « demon slayer » → « onigiri ») n'affecte donc jamais l'identité ni la
/// bibliothèque : au pire, il n'y a pas d'image/description.
library;

import '../data/remote/anilist_client.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/logic/anime_id.dart';
import '../domain/models/media.dart';

class TitleMatcher {
  final AniListApi anilist;
  final SettingsRepository settings;
  final MediaRepository mediaRepo;

  const TitleMatcher({
    required this.anilist,
    required this.settings,
    required this.mediaRepo,
  });

  /// Résout un titre anime-sama en [Media] — **jamais null**.
  ///
  /// - Identité = `Media.fromAnimeSama(title)` (id négatif stable).
  /// - Enrichissement AniList (cover/description) seulement si un résultat de
  ///   recherche a un titre **similaire** au titre cherché.
  Future<Media> resolve(String animeSamaTitle) async {
    // Réconciliation d'identité (NON destructive) : le planning et le catalogue
    // anime-sama affichent parfois des titres DIFFÉRENTS pour le même anime
    // (ex. « Trapped in a Dating Sim » vs « …: The World of Otome Games… »).
    // Comme l'id dérive du titre, ça créait 2 animes. On cherche donc d'abord un
    // média DÉJÀ connu (déjà résolu, donc animeSamaTitle renseigné) dont le
    // titre est similaire, et on réutilise SON id — aucune donnée déplacée,
    // aucune migration : on redirige simplement le nouveau titre vers l'anime
    // existant.
    final reconciled = await _reconcileExisting(animeSamaTitle);
    if (reconciled != null) return reconciled;

    // Base : le média anime-sama fait foi (identité stable).
    var media = Media.fromAnimeSama(
        slug: normalizeAnimeTitle(animeSamaTitle), title: animeSamaTitle);

    // Cache local : si ce média a déjà été résolu AVEC image, on le réutilise.
    // Sans image, on ne réessaie que si l'échec précédent était RÉSEAU (pour
    // récupérer l'image ratée à cause d'un 429), pas si « pas de match ».
    final cached = await mediaRepo.getMedia(media.anilistId);
    if (cached != null && cached.animeSamaTitle != null) {
      if (cached.coverUrl != null) return cached; // déjà enrichi
      final failedNoMatch = await _isMarkedNoMatch(animeSamaTitle);
      if (failedNoMatch) return cached; // rien à gagner à réessayer
      // sinon : échec réseau précédent → on retente l'enrichissement ci-dessous
    }

    // TODO(T13): enrichissement AniList et réconciliation malId supprimés ici.
    // _fetchEnrichment / enrichedWith / _reconcileByMalId retirés en Task 13.
    await _markNoMatch(animeSamaTitle, true);
    await mediaRepo.upsertMedia(media);
    return media;
  }

  /// Cherche un média DÉJÀ résolu (donc `animeSamaTitle` renseigné) dont le
  /// titre anime-sama est similaire à [title] par INCLUSION (l'un contient
  /// l'autre après normalisation) — le cas concret des titres court/long entre
  /// planning et catalogue. Si trouvé, retourne ce média EXISTANT (on réutilise
  /// son id + sa progression), sans rien déplacer. `null` si aucun.
  ///
  /// On restreint volontairement à l'inclusion (pas au matching flou par
  /// jetons) pour ne JAMAIS fusionner par erreur deux animes distincts.
  Future<Media?> _reconcileExisting(String title) async {
    final norm = normalizeAnimeTitle(title);
    if (norm.isEmpty) return null;
    final selfId = animeSamaIdFor(title);
    final all = await mediaRepo.getAllMedia();
    for (final m in all) {
      if (m.anilistId == selfId) return m; // déjà le bon id (rien à réconcilier)
      final other = m.animeSamaTitle;
      if (other == null) continue;
      final on = normalizeAnimeTitle(other);
      if (on.isEmpty) continue;
      // Inclusion stricte dans un sens ou l'autre (titre court ⊂ titre long).
      if (norm.contains(on) || on.contains(norm)) {
        return m;
      }
    }
    return null;
  }

  /// Cherche un média EXISTANT dont le [malId] est identique mais l'id (donc le
  /// titre anime-sama d'origine) diffère de [selfId]. Retourne ce média (on
  /// réutilise son identité + sa progression) ou `null`. Le malId identifiant un
  /// anime de façon unique sur MyAnimeList/AniList, une égalité de malId est un
  /// pont fiable entre deux libellés anime-sama du même anime.
  Future<Media?> _reconcileByMalId(int malId, int selfId) async {
    final all = await mediaRepo.getAllMedia();
    for (final m in all) {
      if (m.anilistId == selfId) continue; // c'est déjà nous
      if (m.malId == malId) return m; // même anime AniList → on adopte son id
    }
    return null;
  }

  static const _noMatchPrefix = 'anime_sama_nomatch:';

  Future<bool> _isMarkedNoMatch(String title) async {
    final v = await settings.get(_noMatchPrefix + normalizeAnimeTitle(title));
    return v == '1';
  }

  Future<void> _markNoMatch(String title, bool noMatch) async {
    final key = _noMatchPrefix + normalizeAnimeTitle(title);
    if (noMatch) {
      await settings.set(key, '1');
    } else {
      await settings.delete(key); // match trouvé ou échec réseau → réessai permis
    }
  }

  /// Cherche sur AniList un média dont un des titres (anglais/romaji/natif)
  /// **ressemble** à [query]. Retourne (media|null, networkFailed) :
  /// - (media, false) : match fiable trouvé ;
  /// - (null, false)  : recherche OK mais aucun résultat similaire (définitif) ;
  /// - (null, true)   : échec réseau / rate-limit (à retenter plus tard).
  Future<(Media?, bool)> _fetchEnrichment(String query) async {
    try {
      final results = await anilist.search(query);
      for (final m in results) {
        final candidates = [
          m.title.english,
          m.title.romaji,
          m.title.native,
        ];
        for (final c in candidates) {
          if (c != null && titlesSimilar(query, c)) {
            return (m, false);
          }
        }
      }
      return (null, false); // recherche aboutie, pas de match
    } catch (_) {
      return (null, true); // AniList indisponible / rate-limité
    }
  }
}
