/// Page de détail d'un média : cover, synopsis, genres, relations, actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/effective_status_service.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/season_progress_repository.dart';
import '../../services/stream_resolver.dart';
import 'library_page.dart';
import 'player_page.dart';
import 'resume_helper.dart';

// ---------------------------------------------------------------------------
// Providers locaux
// ---------------------------------------------------------------------------

/// Charge le média. Si on a un titre anime-sama, on délègue à
/// [TitleMatcher.resolve] qui gère le cache ET le réessai d'enrichissement
/// (image AniList) : réutilise le cache si déjà enrichi ou si « pas de match »
/// définitif, mais retente si l'échec précédent était réseau. Sans titre : id
/// AniList réel → lecture directe. `null` → le widget fabrique un Media minimal.
final _mediaDetailProvider =
    FutureProvider.family<Media?, ({int id, String? title})>((ref, arg) async {
  // Avec titre : resolve() est la source de vérité (cache + réessai gérés).
  if (arg.title != null) {
    try {
      return await ref.read(titleMatcherProvider).resolve(arg.title!);
    } catch (_) {
      final local = await ref.read(mediaRepositoryProvider).getMedia(arg.id);
      return local ?? Media.fromAnimeSama(title: arg.title!);
    }
  }

  final local = await ref.watch(mediaRepositoryProvider).getMedia(arg.id);
  if (local != null) return local;

  // Pas de titre : id AniList réel → lecture directe (bonus).
  if (arg.id <= 0) return null;
  try {
    final media = await ref.watch(aniListClientProvider).mediaDetail(arg.id);
    await ref.read(mediaRepositoryProvider).upsertMedia(media);
    return media;
  } catch (_) {
    return null;
  }
});


/// Entrée de liste (statut/progression) d'un média. Public pour que d'autres
/// pages (bibliothèque) puissent l'invalider après un changement de statut.
final listEntryProvider =
    FutureProvider.family<ListEntry?, int>((ref, mediaId) async {
  return ref.watch(listRepositoryProvider).getEntry(mediaId);
});

/// Compteur de rafraîchissement de la progression des saisons. Les tuiles de
/// saison le watchent : l'incrémenter (après « Terminé » manuel, marquage à
/// fond…) force chaque tuile à recharger `lastWatched`/total sans dépendre de
/// la survie du widget qui a déclenché l'action.
final seasonProgressRefreshProvider = StateProvider<int>((ref) => 0);

/// Saisons anime-sama d'un titre : alias vers le provider **global**
/// (`animeSamaSeasonsProvider`) pour partager le résultat (et le cache) avec le
/// lecteur et le recheck de la bibliothèque — évite de relancer le wrapper.
final _animeSamaSeasonsProvider = animeSamaSeasonsProvider;

/// Titres normalisés présents au planning anime-sama (diffusion en cours).
/// Sert à décider « À jour » (au planning) vs « Terminée » (hors planning).
/// Dérive du planning **global** partagé avec le calendrier (pas de 2e scraping).
final _planningTitlesProvider = FutureProvider<Set<String>>((ref) async {
  try {
    final items = await ref.watch(animeSamaPlanningProvider.future);
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
    final mediaAsync =
        ref.watch(_mediaDetailProvider((id: anilistId, title: displayTitle)));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleFor(mediaAsync.asData?.value),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // Affichage IMMÉDIAT : on montre le corps (titre + saisons anime-sama)
      // sans attendre l'enrichissement AniList. L'image/description se
      // remplissent quand la résolution arrive (data). Jamais de spinner plein
      // écran ni de chargement bloquant.
      body: _DetailBody(
        media: mediaAsync.asData?.value ?? _fallbackMedia(),
        displayTitle: displayTitle,
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

    final nextAt = media.nextAiringAt;
    final nextEp = media.nextAiringEpisode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
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
        ),
        if (nextAt != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                nextEp != null
                    ? 'Prochain épisode (ép. $nextEp) ${_formatAiring(nextAt.toLocal())}'
                    : 'Prochain épisode ${_formatAiring(nextAt.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Formate une date de diffusion de façon lisible et relative (« demain à
  /// 18h30 », « le 14/08 à 18h30 »).
  static String _formatAiring(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diffDays = day.difference(today).inDays;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final heure = 'à ${hh}h$mm';
    if (diffDays == 0) return "aujourd'hui $heure";
    if (diffDays == 1) return 'demain $heure';
    if (diffDays > 1 && diffDays < 7) {
      const jours = [
        'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
      ];
      return '${jours[dt.weekday - 1]} $heure';
    }
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return 'le $d/$mo $heure';
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
        // Reprendre en 1 clic (saison mémorisée + dernier vu, sans réseau).
        FilledButton.icon(
          onPressed: () => resumePlayback(context, ref, media),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Reprendre'),
        ),
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

  /// Libellés des statuts MANUELS uniquement (les seuls choisissables). « En
  /// cours » / « Terminé » sont automatiques (dérivés de la progression) et ne
  /// figurent PAS dans le sélecteur.
  static const _manualLabels = {
    ListStatus.planning: 'Planifié',
    ListStatus.paused: 'En pause',
    ListStatus.dropped: 'Abandonné',
    ListStatus.repeating: 'Re-vision',
  };

  /// Libellé du statut EFFECTIF (affiché en info, incluant les auto).
  static const _effectiveLabels = {
    ListStatus.current: 'En cours',
    ListStatus.planning: 'Planifié',
    ListStatus.completed: 'Terminé',
    ListStatus.paused: 'En pause',
    ListStatus.dropped: 'Abandonné',
    ListStatus.repeating: 'Re-vision',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // « A une progression » : progress global OU une saison anime-sama entamée
    // (sinon un anime suivi via le lecteur, progress=0, resterait « Planifié »).
    final hasProgress = ref.watch(hasProgressProvider(media.anilistId)).maybeWhen(
          data: (v) => v,
          orElse: () => (entry?.progress ?? 0) > 0,
        );
    // Statut EFFECTIF (calculé) pour l'affichage informatif.
    final eff = effectiveStatus(
      entry: entry,
      hasProgress: hasProgress,
    );
    // Valeur du dropdown = statut MANUEL réellement choisi, ou null (« Auto »).
    // Subtilité : `planning` sert de statut par défaut/fourre-tout. On ne le
    // considère comme un choix MANUEL « Planifié » que si l'anime n'a AUCUNE
    // progression. Dès qu'il y a une progression, un `planning` stocké est
    // interprété comme « Auto » (l'effectif est « En cours ») — sinon, après
    // avoir démarqué une saison, l'anime restait bloqué sur « Planifié » sans
    // pouvoir revenir à « Auto ».
    final stored = entry?.status;
    final isManualPlanning = stored == ListStatus.planning && !hasProgress;
    final isOtherManual = stored != null &&
        stored != ListStatus.planning &&
        kManualStatuses.contains(stored);
    final manualValue =
        (isManualPlanning || isOtherManual) ? stored : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge informatif du statut effectif (auto ou manuel).
        if (eff != null) ...[
          Chip(
            label: Text(_effectiveLabels[eff] ?? eff.name),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
        ],
        DropdownButton<ListStatus?>(
          value: manualValue,
          hint: const Text('Définir un statut'),
          items: [
            const DropdownMenuItem<ListStatus?>(
              value: null,
              child: Text('— Auto (selon progression)'),
            ),
            for (final s in kManualStatuses)
              // « Planifié » = « pas encore commencé » : sans intérêt (et
              // trompeur) sur un anime déjà entamé → on le masque dans ce cas.
              if (!(s == ListStatus.planning && hasProgress))
                DropdownMenuItem<ListStatus?>(
                  value: s,
                  child: Text(_manualLabels[s] ?? s.name),
                ),
          ],
          onChanged: (newStatus) => _applyManualStatus(context, ref, newStatus),
        ),
      ],
    );
  }

  /// Applique un statut MANUEL (ou le retire → retour au calcul auto).
  /// - `newStatus` null → on retire l'entrée des listes manuelles : si l'anime
  ///   a une progression, il redeviendra « En cours » (calculé) ; sinon il sort
  ///   des listes. Concrètement on repasse le statut stocké à `planning` si une
  ///   progression existe (pour rester « suivi »), sinon on retire l'entrée.
  /// - sinon → on stocke ce statut manuel.
  Future<void> _applyManualStatus(
      BuildContext context, WidgetRef ref, ListStatus? newStatus) async {
    final repo = ref.read(listRepositoryProvider);
    await ref.read(mediaRepositoryProvider).upsertMedia(media);
    final existing = await repo.getEntry(media.anilistId);

    if (newStatus == null) {
      // Retour au mode auto : on efface un éventuel statut manuel « gelant ».
      // Si l'anime a une progression (globale OU par saison) → stocké `planning`
      // (l'effectif sera « En cours ») ; sinon on retire l'entrée. On teste la
      // progression PAR SAISON aussi (un anime suivi via le lecteur a souvent
      // progress=0 mais une progression par saison → ne PAS le supprimer).
      if (existing == null) return;
      final hasProgress = existing.progress > 0 ||
          await ref
              .read(seasonProgressRepositoryProvider)
              .hasAnyProgress(media.anilistId);
      if (hasProgress) {
        await repo.upsertEntry(existing.copyWith(
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        ));
      } else {
        await repo.deleteEntry(media.anilistId);
      }
    } else {
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
    }

    ref.invalidate(listEntryProvider(media.anilistId));
    ref.invalidate(entriesByStatusProvider);
    ref.invalidate(countByStatusProvider);
    ref.invalidate(hasProgressProvider(media.anilistId));

    if (context.mounted) {
      final msg = newStatus == null
          ? 'Statut : automatique'
          : 'Statut : ${_manualLabels[newStatus]}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
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
      // Passe par le provider global (cache partagé avec le lecteur) plutôt que
      // d'appeler le resolver directement → évite un scraping redondant.
      final eps = await ref.read(animeSamaEpisodesProvider(
        (title: widget.searchTitle, seasonIndex: widget.season.index),
      ).future);
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

  /// Recharge UNIQUEMENT `lastWatched` (local, instantané, pas de réseau). Sert
  /// après un « Terminé » manuel : le total n'a pas changé, seule la
  /// progression a été mise à fond → on rafraîchit la barre sans re-scraper.
  Future<void> _reloadWatchedOnly() async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final last = await seasonProgress.lastWatched(
        widget.media.anilistId, widget.season.index);
    if (mounted && last != _lastWatched) {
      setState(() => _lastWatched = last);
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
    // Épisode de départ = dernier vu + 1. Si la saison a été marquée
    // « entièrement vue » via la sentinelle (« Terminé » manuel), _lastWatched
    // est artificiellement énorme : on repart au dernier épisode réel connu
    // (ou à 1 si le total est inconnu) plutôt qu'à un numéro inexistant.
    final markedFull =
        _lastWatched >= SeasonProgressRepository.fullyWatchedSentinel;
    final startEpisode =
        markedFull ? (_total != null && _total! > 0 ? _total! : 1) : _lastWatched + 1;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          media: widget.media,
          episode: startEpisode,
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

  /// Marque UNIQUEMENT cette saison comme entièrement vue (sans toucher aux
  /// autres saisons ni au statut global de l'anime). Rafraîchit la barre, puis
  /// tente de passer l'anime « Terminé » si c'était la dernière saison manquante.
  Future<void> _markThisSeasonWatched() async {
    await ref
        .read(seasonProgressRepositoryProvider)
        .markSeasonFullyWatched(widget.media.anilistId, widget.season.index);
    await _reloadWatchedOnly();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${widget.season.name} » marquée comme vue')),
      );
    }
    // Si toutes les saisons sont désormais vues → l'anime passe « Terminé ».
    await _maybeMarkSeriesCompleted();
  }

  /// Annule le marquage « vue » de cette saison : remet son compteur à 0 et,
  /// si l'anime était « Terminé », le repasse « En cours » (on n'a plus tout vu).
  Future<void> _unmarkThisSeason() async {
    await ref
        .read(seasonProgressRepositoryProvider)
        .setLastWatched(widget.media.anilistId, widget.season.index, 0);
    await _reloadWatchedOnly();

    // L'anime n'est plus entièrement vu → retire le drapeau « Terminé »
    // (repasse `planning` ; l'effectif redeviendra « En cours » via la
    // progression restante).
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final existing = await listRepo.getEntry(widget.media.anilistId);
      if (existing != null && existing.status == ListStatus.completed) {
        await listRepo.upsertEntry(existing.copyWith(
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        ));
        ref.invalidate(entriesByStatusProvider);
        ref.invalidate(countByStatusProvider);
        ref.invalidate(listEntryProvider(widget.media.anilistId));
      }
    } catch (_) {/* best-effort */}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${widget.season.name} » marquée non vue')),
      );
    }
  }

  /// Passe l'anime « Terminé » si TOUTES ses saisons anime-sama sont vues.
  /// Best-effort (données anime-sama en cache via les providers globaux).
  Future<void> _maybeMarkSeriesCompleted() async {
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final existing = await listRepo.getEntry(widget.media.anilistId);
      if (existing != null && existing.status == ListStatus.completed) return;

      final seasons =
          await ref.read(animeSamaSeasonsProvider(widget.searchTitle).future);
      if (seasons.isEmpty) return;
      final seasonProgress = ref.read(seasonProgressRepositoryProvider);
      var totalEpisodes = 0;
      for (final s in seasons) {
        final eps = await ref.read(animeSamaEpisodesProvider(
          (title: widget.searchTitle, seasonIndex: s.index),
        ).future);
        if (eps.isEmpty) return;
        totalEpisodes += eps.length;
        final watched =
            await seasonProgress.lastWatched(widget.media.anilistId, s.index);
        final done = watched >= SeasonProgressRepository.fullyWatchedSentinel ||
            watched >= eps.last;
        if (!done) return;
      }
      final base = existing ??
          ListEntry(
            mediaId: widget.media.anilistId,
            status: ListStatus.completed,
            updatedAt: DateTime.now(),
          );
      final newProgress =
          totalEpisodes > base.progress ? totalEpisodes : base.progress;
      await listRepo.upsertEntry(base.copyWith(
        status: ListStatus.completed,
        progress: newProgress,
        updatedAt: DateTime.now(),
      ));
      ref.invalidate(entriesByStatusProvider);
      ref.invalidate(countByStatusProvider);
      ref.invalidate(listEntryProvider(widget.media.anilistId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anime terminé ! 🎉')),
        );
      }
    } catch (_) {/* best-effort */}
  }

  @override
  Widget build(BuildContext context) {
    // Rechargement déclenché de l'extérieur (« Terminé » manuel a marqué toutes
    // les saisons à fond) → rafraîchit la barre sans appel réseau.
    ref.listen<int>(seasonProgressRefreshProvider, (_, __) {
      _reloadWatchedOnly();
    });
    final theme = Theme.of(context);
    final total = _total;
    // Saison finie : soit on a atteint le total réel, soit elle a été marquée
    // « entièrement vue » via la sentinelle (« Terminé » manuel, sans compter
    // les épisodes → total parfois inconnu).
    final markedFull =
        _lastWatched >= SeasonProgressRepository.fullyWatchedSentinel;
    final done =
        markedFull || (total != null && total > 0 && _lastWatched >= total);
    final ratio = done
        ? 1.0
        : (total != null && total > 0)
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
                // Bascule vu/pas vu : si la saison n'est pas finie → la marquer
                // vue ; si elle est finie → l'annuler (remettre à 0 épisode vu).
                if (_loaded)
                  IconButton(
                    icon: Icon(done ? Icons.remove_done : Icons.done_all,
                        size: 18),
                    tooltip: done
                        ? 'Annuler : saison non vue'
                        : 'Marquer la saison comme vue',
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        done ? _unmarkThisSeason : _markThisSeasonWatched,
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
