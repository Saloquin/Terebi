/// Page de détail d'un média : cover, synopsis, genres, relations, actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart';
import 'library_page.dart';
import 'player_page.dart';

// ---------------------------------------------------------------------------
// Providers locaux
// ---------------------------------------------------------------------------

/// Charge le média : **cache local d'abord** (source de vérité anime-sama), puis
/// AniList seulement en bonus si absent du cache ET id réel (> 0). Retourne
/// `null` si rien trouvé → le widget fabrique un Media minimal depuis le titre.
final _mediaDetailProvider =
    FutureProvider.family<Media?, int>((ref, id) async {
  final local = await ref.watch(mediaRepositoryProvider).getMedia(id);
  if (local != null) return local;
  // Id négatif = anime hors-AniList → ne pas appeler AniList.
  if (id <= 0) return null;
  try {
    final media = await ref.watch(aniListClientProvider).mediaDetail(id);
    await ref.read(mediaRepositoryProvider).upsertMedia(media);
    return media;
  } catch (_) {
    return null; // AniList indisponible → fiche minimale.
  }
});


/// Entrée de liste (statut/progression) d'un média. Public pour que d'autres
/// pages (bibliothèque) puissent l'invalider après un changement de statut.
final listEntryProvider =
    FutureProvider.family<ListEntry?, int>((ref, mediaId) async {
  return ref.watch(listRepositoryProvider).getEntry(mediaId);
});

/// Provider saisons anime-sama : liste les saisons disponibles sur anime-sama
/// pour un titre donné. Keyed sur le titre préféré du média.
final _animeSamaSeasonsProvider =
    FutureProvider.family<List<AnimeSamaSeason>, String>((ref, title) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  return resolver.listSeasons(title: title);
});

/// Titres normalisés présents au planning anime-sama (diffusion en cours).
/// Sert à décider « À jour » (au planning) vs « Terminée » (hors planning).
final _planningTitlesProvider = FutureProvider<Set<String>>((ref) async {
  try {
    final resolver = await ref.watch(animeSamaResolverProvider.future);
    final items = await resolver.planning();
    return items.map((e) => _normTitle(e.title)).toSet();
  } catch (_) {
    return <String>{};
  }
});

/// Normalise un titre pour comparaison (minuscule, alphanumérique).
String _normTitle(String t) =>
    t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

/// Page de détail d'un anime identifié par son [anilistId] AniList.
///
/// [displayTitle] (optionnel) : titre à afficher à la place du titre AniList.
/// Fourni depuis le catalogue/planning anime-sama pour montrer le titre propre
/// (« Dr Stone » plutôt que « Dr Stone Saison 2 ») tout en gardant les infos
/// AniList (synopsis, note, image). `null` ailleurs → titre AniList.
class MediaDetailPage extends ConsumerWidget {
  final int anilistId;
  final String? displayTitle;

  const MediaDetailPage({
    super.key,
    required this.anilistId,
    this.displayTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(_mediaDetailProvider(anilistId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleFor(mediaAsync.asData?.value),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Jamais bloquant : en cas d'erreur, on retombe sur un média minimal.
        error: (_, __) => _DetailBody(
          media: _fallbackMedia(),
          displayTitle: displayTitle,
        ),
        data: (media) => _DetailBody(
          media: media ?? _fallbackMedia(),
          displayTitle: displayTitle,
        ),
      ),
    );
  }

  /// Titre affiché : priorité au titre anime-sama (source de vérité).
  String _titleFor(Media? m) =>
      displayTitle ?? m?.animeSamaTitle ?? m?.title.preferred ?? 'Détail';

  /// Média minimal quand AniList ne fournit rien (id négatif ou hors-ligne).
  Media _fallbackMedia() => displayTitle != null
      ? Media.fromAnimeSama(title: displayTitle!)
      : Media(anilistId: anilistId, title: const MediaTitle(romaji: 'Anime'));
}

// ---------------------------------------------------------------------------
// Corps de la page (média chargé)
// ---------------------------------------------------------------------------

class _DetailBody extends ConsumerWidget {
  final Media media;
  final String? displayTitle;

  const _DetailBody({required this.media, this.displayTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(listEntryProvider(media.anilistId));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Banner / cover header ---
          _Header(media: media, displayTitle: displayTitle),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Métadonnées rapides ---
                _MetaChips(media: media),
                const SizedBox(height: 16),

                // --- Actions : reprise + statut ---
                entryAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (entry) => _ActionBar(media: media, entry: entry),
                ),
                const SizedBox(height: 16),

                // --- Synopsis ---
                if (media.description != null &&
                    media.description!.isNotEmpty) ...[
                  Text('Synopsis',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SynopsisText(raw: media.description!),
                  const SizedBox(height: 16),
                ],

                // --- Genres ---
                if (media.genres.isNotEmpty) ...[
                  Text('Genres',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final g in media.genres)
                        Chip(label: Text(g), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // --- Saisons anime-sama (seul point de choix de saison) ---
                _AnimeSamaSeasonsSection(
                    media: media, displayTitle: displayTitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header (banner + cover flottante)
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final Media media;
  final String? displayTitle;
  const _Header({required this.media, this.displayTitle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          // Banner
          Positioned.fill(
            child: media.bannerUrl != null
                ? Image.network(media.bannerUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ))
                : Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          // Cover + titre
          Positioned(
            left: 16,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: media.coverUrl != null
                      ? Image.network(media.coverUrl!,
                          width: 80,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 80, height: 110))
                      : const SizedBox(width: 80, height: 110),
                ),
                const SizedBox(width: 12),
                // Titre + score
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle ?? media.title.preferred,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (media.averageScore != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${media.averageScore}%',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chips de métadonnées
// ---------------------------------------------------------------------------

class _MetaChips extends StatelessWidget {
  final Media media;
  const _MetaChips({required this.media});

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      _formatLabel(media),
      if (media.episodes != null) '${media.episodes} épisodes',
      if (media.durationMinutes != null) '${media.durationMinutes} min/ep',
      if (media.seasonYear != null)
        '${_seasonLabel(media.season?.name)} ${media.seasonYear}',
      _statusLabel(media.status.name),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final item in items)
          Chip(
            label: Text(item),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  static String _formatLabel(Media m) => switch (m.format.name) {
        'tv' => 'TV',
        'tvShort' => 'TV Court',
        'movie' => 'Film',
        'special' => 'Spécial',
        'ova' => 'OVA',
        'ona' => 'ONA',
        'music' => 'Musique',
        _ => '?',
      };

  static String _seasonLabel(String? s) => switch (s) {
        'winter' => 'Hiver',
        'spring' => 'Printemps',
        'summer' => 'Été',
        'fall' => 'Automne',
        _ => '',
      };

  static String _statusLabel(String s) => switch (s) {
        'finished' => 'Terminé',
        'releasing' => 'En cours',
        'notYetReleased' => 'À venir',
        'cancelled' => 'Annulé',
        'hiatus' => 'En pause',
        _ => 'Inconnu',
      };
}

// ---------------------------------------------------------------------------
// Barre d'actions
// ---------------------------------------------------------------------------

class _ActionBar extends ConsumerWidget {
  final Media media;
  final ListEntry? entry;

  const _ActionBar({required this.media, required this.entry});

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer de la bibliothèque ?'),
        content: Text(
          '« ${media.title.preferred} » sera retiré de tes listes. '
          'Ta progression (épisodes vus) est conservée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(listRepositoryProvider).deleteEntry(media.anilistId);
    ref.invalidate(listEntryProvider(media.anilistId));
    // Rafraîchit la bibliothèque (onglets + compteurs).
    ref.invalidate(entriesByStatusProvider);
    ref.invalidate(countByStatusProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${media.title.preferred} » retiré')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La lecture se lance depuis la section « Saisons (anime-sama) » ci-dessous.
    // Ici : statut + retrait de la bibliothèque.
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _StatusDropdown(media: media, entry: entry),
        if (entry != null)
          OutlinedButton.icon(
            onPressed: () => _remove(context, ref),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Retirer de la bibliothèque'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _StatusDropdown extends ConsumerWidget {
  final Media media;
  final ListEntry? entry;

  const _StatusDropdown({required this.media, required this.entry});

  static const _labels = {
    ListStatus.current: 'En cours',
    ListStatus.planning: 'Planifié',
    ListStatus.completed: 'Terminé',
    ListStatus.paused: 'En pause',
    ListStatus.dropped: 'Abandonné',
    ListStatus.repeating: 'Re-vision',
  };

  /// Marque toutes les saisons anime-sama comme entièrement vues (dernier
  /// épisode = total). Best-effort : ignore les erreurs réseau.
  Future<void> _markAllSeasonsWatched(WidgetRef ref, Media media) async {
    try {
      final resolver = await ref.read(animeSamaResolverProvider.future);
      final seasonProgress = ref.read(seasonProgressRepositoryProvider);
      final title = media.animeSamaTitle ?? media.title.preferred;
      final seasons = await resolver.listSeasons(title: title);
      for (final s in seasons) {
        try {
          final eps =
              await resolver.listEpisodes(title: title, seasonIndex: s.index);
          if (eps.isNotEmpty) {
            await seasonProgress.setLastWatched(
                media.anilistId, s.index, eps.length);
          }
        } catch (_) {/* saison ignorée */}
      }
    } catch (_) {/* best-effort */}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = entry?.status;

    return DropdownButton<ListStatus>(
      value: current,
      hint: const Text('Ajouter à la liste'),
      items: ListStatus.values
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(_labels[s] ?? s.name),
              ))
          .toList(),
      onChanged: (newStatus) async {
        if (newStatus == null) return;
        final repo = ref.read(listRepositoryProvider);
        // Sauvegarde les métadonnées du média (titre/cover) pour la bibliothèque.
        await ref.read(mediaRepositoryProvider).upsertMedia(media);
        final existing = await repo.getEntry(media.anilistId);
        final updated = existing?.copyWith(
              status: newStatus,
              updatedAt: DateTime.now(),
            ) ??
            ListEntry(
              mediaId: media.anilistId,
              status: newStatus,
              updatedAt: DateTime.now(),
            );
        await repo.upsertEntry(updated);

        // « Terminé » manuel → marque toutes les saisons anime-sama à fond,
        // pour que les barres affichent « Terminée » et que le recheck ne
        // redégrade pas l'anime en « En cours ». Best-effort.
        if (newStatus == ListStatus.completed) {
          await _markAllSeasonsWatched(ref, media);
        }

        // Invalide le provider d'entrée + la bibliothèque (onglets + compteurs).
        ref.invalidate(listEntryProvider(media.anilistId));
        ref.invalidate(entriesByStatusProvider);
        ref.invalidate(countByStatusProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Statut mis à jour : ${_labels[newStatus]}')),
          );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Synopsis (retire les balises HTML basiques d'AniList)
// ---------------------------------------------------------------------------

class _SynopsisText extends StatelessWidget {
  final String raw;
  const _SynopsisText({required this.raw});

  String get _clean => raw
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();

  @override
  Widget build(BuildContext context) {
    return Text(_clean, style: Theme.of(context).textTheme.bodyMedium);
  }
}

// ---------------------------------------------------------------------------
// Section Saisons anime-sama
// ---------------------------------------------------------------------------

/// Liste les saisons disponibles sur anime-sama pour ce média.
/// Un clic mémorise l'index choisi et lance la lecture à l'épisode de reprise.
class _AnimeSamaSeasonsSection extends ConsumerWidget {
  final Media media;
  final String? displayTitle;
  const _AnimeSamaSeasonsSection({required this.media, this.displayTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Titre de recherche anime-sama : le titre anime-sama exact fait foi
    // (displayTitle transmis, ou animeSamaTitle stocké). Le titre AniList
    // (title.preferred) n'est utilisé qu'en dernier recours car il peut différer
    // et provoquer un mauvais match (ex. « 10 saisons + OAV » d'un autre anime).
    final searchTitle =
        displayTitle ?? media.animeSamaTitle ?? media.title.preferred;
    final seasonsAsync = ref.watch(_animeSamaSeasonsProvider(searchTitle));

    return seasonsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) {
        // Anime-sama ne connaît pas cet anime ou le résolveur est indisponible :
        // on affiche un message discret plutôt que de crasher.
        final msg = err is ResolveException ? err.message : err.toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Saisons anime-sama indisponibles : $msg',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        );
      },
      data: (seasons) {
        if (seasons.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saisons (anime-sama)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final season in seasons)
              _AnimeSamaSeasonTile(
                media: media,
                season: season,
                searchTitle: searchTitle,
                isLastSeason: season.index == seasons.last.index,
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _AnimeSamaSeasonTile extends ConsumerStatefulWidget {
  final Media media;
  final AnimeSamaSeason season;
  final String searchTitle;
  final bool isLastSeason;

  const _AnimeSamaSeasonTile({
    required this.media,
    required this.season,
    required this.searchTitle,
    required this.isLastSeason,
  });

  @override
  ConsumerState<_AnimeSamaSeasonTile> createState() =>
      _AnimeSamaSeasonTileState();
}

class _AnimeSamaSeasonTileState extends ConsumerState<_AnimeSamaSeasonTile> {
  int _lastWatched = 0; // dernier épisode vu de cette saison (0 = rien)
  int? _total; // nombre d'épisodes anime-sama de la saison
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgress());
  }

  Future<void> _loadProgress() async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final last = await seasonProgress.lastWatched(
        widget.media.anilistId, widget.season.index);

    int? total;
    try {
      final resolver = await ref.read(animeSamaResolverProvider.future);
      final eps = await resolver.listEpisodes(
        title: widget.searchTitle,
        seasonIndex: widget.season.index,
      );
      if (eps.isNotEmpty) total = eps.length;
    } catch (_) {/* total inconnu → barre indéterminée */}

    if (mounted) {
      setState(() {
        _lastWatched = last;
        _total = total;
        _loaded = true;
      });
    }
  }

  Future<void> _play() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    // Mémorise la saison choisie (le lecteur lira dernier vu + 1 tout seul).
    await settingsRepo.set(
      SettingsKeys.animeSamaSeasonFor(widget.media.anilistId),
      '${widget.season.index}',
    );

    final listRepo = ref.read(listRepositoryProvider);
    final existingEntry = await listRepo.getEntry(widget.media.anilistId);
    final entry = existingEntry ??
        ListEntry(
          mediaId: widget.media.anilistId,
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        );

    if (!mounted) return;
    // Le lecteur recalcule l'épisode (dernier vu + 1) ; on passe une valeur
    // cohérente au cas où (source non-anime-sama).
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          media: widget.media,
          episode: _lastWatched + 1,
          entry: entry,
          cameFromDetail: true,
          animeSamaTitle: widget.searchTitle,
        ),
      ),
    ).then((_) {
      // Au retour du lecteur, la progression a pu changer → recharger la barre.
      _loadProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _total;
    final done = total != null && total > 0 && _lastWatched >= total;
    final ratio = (total != null && total > 0)
        ? (_lastWatched / total).clamp(0.0, 1.0)
        : null;

    // « À jour » si saison finie + dernière saison + anime au planning
    // (nouveaux épisodes possibles) ; sinon « Terminée ».
    final planningTitles = ref.watch(_planningTitlesProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const <String>{},
        );
    final atPlanning = planningTitles.contains(_normTitle(widget.searchTitle));
    final doneLabel =
        (widget.isLastSeason && atPlanning) ? 'À jour' : 'Terminée';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: _play,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.play_circle_outline,
                  color: done ? Colors.green : null,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.season.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(
                  !_loaded
                      ? '…'
                      : done
                          ? doneLabel
                          : total != null
                              ? '$_lastWatched/$total'
                              : '$_lastWatched vu(s)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: done
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: done ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio, // null → barre indéterminée si total inconnu
                minHeight: 5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: done ? Colors.green : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
