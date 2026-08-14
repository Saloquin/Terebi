/// Page d'accueil façon Netflix : plusieurs rangées horizontales thématiques.
///
/// Ordre des rangées (retour utilisateur) :
///  1. Continuer à regarder (local — en cours)
///  2. Sortis récemment (planning anime-sama de la semaine)
///  3. Tendances du moment (AniList Trending — communauté)
///  4. Recommandé pour toi (AniList par tes genres favoris, 2-3 rangées)
///  5. Populaires (AniList Popular — masqué si redondant avec Tendances)
///  6. Tu regardes beaucoup (ton historique de lancements agrégé)
///
/// Fallback : si peu/pas d'animes terminés, « Continuer à regarder » (en cours)
/// reste la vitrine principale — c'est déjà la 1re rangée.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../widgets/media_card.dart';
import 'library_page.dart' show entriesByStatusProvider;
import 'media_detail_page.dart';
import 'resume_helper.dart';

// ---------------------------------------------------------------------------
// Helper saison courante (DateTime.now() toléré en UI)
// ---------------------------------------------------------------------------

AnimeSeason _currentSeason(DateTime now) {
  final m = now.month;
  if (m <= 3) return AnimeSeason.winter;
  if (m <= 6) return AnimeSeason.spring;
  if (m <= 9) return AnimeSeason.summer;
  return AnimeSeason.fall;
}

// ---------------------------------------------------------------------------
// Providers de rangées
// ---------------------------------------------------------------------------

/// « Continuer à regarder » : médias en cours, triés du plus récemment mis à
/// jour au plus ancien, résolus en [Media] (cache local). Ignore les entrées
/// sans média résoluble.
final _continueWatchingProvider = FutureProvider<List<Media>>((ref) async {
  final entries =
      await ref.watch(entriesByStatusProvider(ListStatus.current).future);
  final sorted = [...entries]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final result = <Media>[];
  for (final e in sorted.take(20)) {
    final m = await mediaRepo.getMedia(e.mediaId);
    if (m != null) result.add(m);
  }
  return result;
});

/// « Sortis récemment » : le planning anime-sama de la semaine, résolu en
/// [Media] (via le rematch titre → AniList pour l'image). Best-effort, borné.
/// NB : anime-sama ne donne pas le numéro d'épisode, c'est « ce qui sort cette
/// semaine » (approximation de « derniers épisodes sortis »).
final _recentlyReleasedProvider = FutureProvider<List<Media>>((ref) async {
  try {
    final items = await ref.watch(animeSamaPlanningProvider.future);
    final matcher = ref.watch(titleMatcherProvider);
    final result = <Media>[];
    final seen = <int>{};
    for (final it in items.take(15)) {
      try {
        final media = await matcher.resolve(it.title);
        if (seen.add(media.anilistId)) result.add(media);
      } catch (_) {/* titre non résolu : on saute */}
      if (result.length >= 12) break;
    }
    return result;
  } catch (_) {
    return const [];
  }
});

/// Tendances du moment (communauté AniList).
final _trendingProvider = FutureProvider<List<Media>>((ref) async {
  try {
    return await ref.watch(aniListClientProvider).trending(perPage: 20);
  } catch (_) {
    return const [];
  }
});

/// Animes les plus populaires (communauté AniList).
final _popularProvider = FutureProvider<List<Media>>((ref) async {
  try {
    return await ref.watch(aniListClientProvider).popular(perPage: 20);
  } catch (_) {
    return const [];
  }
});

/// Genres favoris de l'utilisateur (les plus présents dans sa bibliothèque),
/// classés par occurrence décroissante. Sert aux rangées de recommandation.
/// Local et rapide (getAllMedia). Retourne au plus [max] genres.
final _favoriteGenresProvider =
    FutureProvider.family<List<String>, int>((ref, max) async {
  final all = await ref.watch(mediaRepositoryProvider).getAllMedia();
  final entries =
      await ref.watch(listRepositoryProvider).getAllEntries();
  final followed = entries.map((e) => e.mediaId).toSet();
  final counts = <String, int>{};
  for (final m in all) {
    if (!followed.contains(m.anilistId)) continue; // que les animes suivis
    for (final g in m.genres) {
      counts[g] = (counts[g] ?? 0) + 1;
    }
  }
  final sorted = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return sorted.take(max).toList();
});

/// Recommandations AniList pour un genre donné (découverte).
final _byGenreProvider =
    FutureProvider.family<List<Media>, String>((ref, genre) async {
  try {
    return await ref.watch(aniListClientProvider).byGenre(genre, perPage: 20);
  } catch (_) {
    return const [];
  }
});

/// Ensemble des ids déjà présents dans la bibliothèque (toute entrée de liste).
/// Sert à EXCLURE ces animes des rangées de découverte (Tendances, Populaires,
/// genre…) pour ne montrer que du nouveau. Les ids anime-sama étant négatifs et
/// les ids AniList positifs, une exclusion par id ne couvre pas un anime suivi
/// via anime-sama mais affiché ici via AniList — on complète donc par le titre
/// normalisé (best-effort).
final _libraryFilterProvider =
    FutureProvider<({Set<int> ids, Set<String> titles})>((ref) async {
  final entries = await ref.watch(listRepositoryProvider).getAllEntries();
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final ids = <int>{};
  final titles = <String>{};
  for (final e in entries) {
    ids.add(e.mediaId);
    final m = await mediaRepo.getMedia(e.mediaId);
    if (m != null) {
      titles.add(_normTitle(m.title.preferred));
      if (m.animeSamaTitle != null) titles.add(_normTitle(m.animeSamaTitle!));
    }
  }
  return (ids: ids, titles: titles);
});

/// Normalise un titre pour comparaison (minuscule, alphanumérique).
String _normTitle(String t) =>
    t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// « En ce moment » : ce que l'utilisateur regarde activement, dérivé de son
/// historique de lancements agrégé (le plus lancé d'abord), résolu en [Media].
final _mostWatchedProvider = FutureProvider<List<Media>>((ref) async {
  final history = await ref.watch(watchHistoryRepositoryProvider).all();
  if (history.isEmpty) return const [];
  final counts = <int, int>{};
  for (final h in history) {
    counts[h.mediaId] = (counts[h.mediaId] ?? 0) + 1;
  }
  final ids = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final result = <Media>[];
  for (final id in ids.take(20)) {
    final m = await mediaRepo.getMedia(id);
    if (m != null) result.add(m);
  }
  return result;
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final season = _currentSeason(now);
    final genresAsync = ref.watch(_favoriteGenresProvider(3));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. En ce moment (historique récent agrégé) — bouton reprise.
        _MediaRow(
          title: 'En ce moment',
          provider: _mostWatchedProvider,
          withResume: true,
        ),
        // 2. Continuer à regarder (statut en cours) — bouton reprise.
        _MediaRow(
          title: 'Continuer à regarder',
          provider: _continueWatchingProvider,
          withResume: true,
        ),
        // --- Rangées de DÉCOUVERTE (excluent les animes déjà en biblio) ---
        // 3. Sortis du moment (planning de la semaine).
        _MediaRow(
          title: 'Sortis du moment',
          provider: _recentlyReleasedProvider,
          excludeLibrary: true,
        ),
        // 4. Saison courante.
        _MediaRow(
          title: 'Saison courante',
          provider: _seasonPreviewProvider((season: season, year: now.year)),
          excludeLibrary: true,
        ),
        // 5. Tendances du moment (AniList).
        _MediaRow(
          title: 'Tendances du moment',
          provider: _trendingProvider,
          excludeLibrary: true,
        ),
        // 6. Populaires (all-time). Masqué s'il fait doublon avec Tendances.
        _MediaRow(
          title: 'Populaires',
          provider: _popularProvider,
          excludeLibrary: true,
          hideIfSameAs: _trendingProvider,
        ),
        // 7. Par genre favori : une rangée par genre.
        ...genresAsync.maybeWhen(
          data: (genres) => genres.map((g) => _GenreRow(genre: g)).toList(),
          orElse: () => const <Widget>[],
        ),
      ],
    );
  }
}

/// Provider saison courante (mis en cache, keyé sur (saison, année)).
final _seasonPreviewProvider =
    FutureProvider.family<List<Media>, ({AnimeSeason season, int year})>(
        (ref, arg) async {
  try {
    return await ref
        .watch(aniListClientProvider)
        .season(arg.season, arg.year, perPage: 12);
  } catch (_) {
    return const [];
  }
});

// ---------------------------------------------------------------------------
// Rangée horizontale réutilisable
// ---------------------------------------------------------------------------

/// Rangée horizontale de [MediaCard], grande taille façon Netflix, à
/// défilement EN BOUCLE (on revient au début après le dernier). Masquée si
/// vide/chargement/erreur.
/// - [withResume] : bouton reprise sur les cartes.
/// - [excludeLibrary] : retire les animes déjà dans la bibliothèque (rangées
///   de découverte : on ne montre que du nouveau).
/// - [hideIfSameAs] : masque la rangée si son début recoupe un autre provider
///   (évite Populaires ≈ Tendances).
class _MediaRow extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<Media>>> provider;
  final bool withResume;
  final bool excludeLibrary;
  final ProviderListenable<AsyncValue<List<Media>>>? hideIfSameAs;

  /// Nombre max de cartes par rangée (borne le carrousel).
  static const int _maxCards = 20;

  /// Nombre MIN de cartes pour activer la boucle infinie. En dessous, il n'y a
  /// pas assez d'items pour remplir une page large sans qu'un même item
  /// réapparaisse en double à l'écran → on désactive la boucle (liste finie).
  static const int _minCardsForLoop = 13;

  /// Largeur/hauteur des grandes cartes.
  static const double _cardWidth = 200;
  static const double _rowHeight = 320;

  const _MediaRow({
    required this.title,
    required this.provider,
    this.withResume = false,
    this.excludeLibrary = false,
    this.hideIfSameAs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.maybeWhen(
      data: (raw) {
        var items = raw;

        // Exclusion des animes déjà en bibliothèque (par id ET par titre
        // normalisé, pour couvrir un anime suivi via anime-sama mais affiché
        // ici via AniList).
        if (excludeLibrary) {
          final lib = ref.watch(_libraryFilterProvider).maybeWhen(
                data: (f) => f,
                orElse: () => (ids: <int>{}, titles: <String>{}),
              );
          if (lib.ids.isNotEmpty || lib.titles.isNotEmpty) {
            items = items.where((m) {
              if (lib.ids.contains(m.anilistId)) return false;
              if (lib.titles.contains(_normTitle(m.title.preferred))) {
                return false;
              }
              return true;
            }).toList();
          }
        }

        // Borne le nombre de cartes.
        if (items.length > _maxCards) items = items.sublist(0, _maxCards);

        if (items.isEmpty) return const SizedBox.shrink();

        // Anti-doublon : si le début recoupe l'autre rangée, on masque.
        if (hideIfSameAs != null) {
          final other = ref.watch(hideIfSameAs!).maybeWhen(
                data: (o) => o,
                orElse: () => const <Media>[],
              );
          if (other.isNotEmpty && _sameHead(items, other)) {
            return const SizedBox.shrink();
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: _rowHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                // Défilement en BOUCLE seulement s'il y a assez d'items pour
                // remplir une page large sans qu'un même item réapparaisse en
                // double à l'écran (>= _minCardsForLoop). Sinon liste finie :
                // on présente un très grand nombre d'items virtuels et on ramène
                // l'index dans [0, items.length[ par modulo.
                itemCount: items.length < _minCardsForLoop
                    ? items.length
                    : 100000,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final media = items[i % items.length];
                  return SizedBox(
                    width: _cardWidth,
                    child: MediaCard(
                      media: media,
                      onResume: withResume
                          ? () => resumePlayback(context, ref, media)
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MediaDetailPage(
                            anilistId: media.anilistId,
                            displayTitle: media.animeSamaTitle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  /// Vrai si les deux listes commencent par les mêmes médias (recoupement fort).
  static bool _sameHead(List<Media> a, List<Media> b) {
    final n = a.length < b.length ? a.length : b.length;
    final head = n < 5 ? n : 5;
    if (head == 0) return false;
    for (var i = 0; i < head; i++) {
      if (a[i].anilistId != b[i].anilistId) return false;
    }
    return true;
  }
}

/// Rangée « Recommandé · <genre> » (découverte AniList par genre).
class _GenreRow extends StatelessWidget {
  final String genre;
  const _GenreRow({required this.genre});

  @override
  Widget build(BuildContext context) {
    return _MediaRow(
      title: 'Recommandé · $genre',
      provider: _byGenreProvider(genre),
      excludeLibrary: true,
    );
  }
}
