/// Page Planning hebdomadaire — source **anime-sama** (retour utilisateur).
///
/// - Le planning vient d'anime-sama (jour + heure), pas d'AniList.
/// - Affichage en **colonnes de jour** (Lundi → Dimanche), cartes « poster ».
/// - Chaque carte s'affiche et reste **cliquable immédiatement** (titre + heure) ;
///   la **vignette** AniList se charge en fond (rematch lazy caché). Le rematch
///   se fait aussi au clic (lecture) / à l'ajout perso s'il n'est pas encore prêt.
/// - Toggle **Global / Perso** : Perso = uniquement les anime du planning que tu
///   as marqués « Planifié ».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart';
import 'player_page.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Planning hebdomadaire anime-sama : alias vers le provider **global**
/// (`animeSamaPlanningProvider`) pour partager le résultat (et le cache) avec la
/// fiche de détail — évite un second scraping du planning.
final _planningProvider = animeSamaPlanningProvider;

/// Résout (lazy, caché) un titre anime-sama en [Media] pour la vignette.
/// Cherche d'abord le cache local (par id anime-sama), puis retourne un Media
/// minimal si absent (couverture absente = dégradé gracieux).
final _mediaForTitleProvider =
    FutureProvider.family<Media?, String>((ref, title) async {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final id = animeSamaIdFor(title);
  final cached = await mediaRepo.getMedia(id);
  if (cached != null) return cached;
  // Pas encore en cache : retourne null (la couverture sera absente).
  return null;
});

/// IDs des médias présents dans la bibliothèque (TOUS statuts). Sert à savoir
/// si l'anime est **déjà suivi** (bouton d'ajout désactivé si oui).
final _libraryIdsProvider = FutureProvider<Set<int>>((ref) async {
  final listRepo = ref.watch(listRepositoryProvider);
  final ids = <int>{};
  for (final status in ListStatus.values) {
    final entries = await listRepo.entriesByStatus(status);
    ids.addAll(entries.map((e) => e.mediaId));
  }
  return ids;
});

/// IDs affichés dans le calendrier PERSO : biblio SAUF Abandonné.
final _persoIdsProvider = FutureProvider<Set<int>>((ref) async {
  final listRepo = ref.watch(listRepositoryProvider);
  final ids = <int>{};
  for (final status in ListStatus.values) {
    if (status == ListStatus.dropped) continue;
    final entries = await listRepo.entriesByStatus(status);
    ids.addAll(entries.map((e) => e.mediaId));
  }
  return ids;
});

// ---------------------------------------------------------------------------
// Ordre des jours (français)
// ---------------------------------------------------------------------------

const _dayOrder = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

int _dayRank(String day) {
  final idx = _dayOrder.indexWhere((d) => d.toLowerCase() == day.toLowerCase());
  return idx < 0 ? 99 : idx;
}

/// Clé de tri d'une heure « HHhMM » ; les heures vides passent en dernier.
int _timeRank(String time) {
  final m = RegExp(r'^(\d{1,2})h(\d{0,2})$').firstMatch(time.trim());
  if (m == null) return 1 << 20;
  final h = int.tryParse(m.group(1)!) ?? 0;
  final min = int.tryParse(m.group(2)!.isEmpty ? '0' : m.group(2)!) ?? 0;
  return h * 60 + min;
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  // true = GLOBAL (tout le planning), false = PERSO (anime suivis seulement).
  bool _showGlobal = true;
  // À l'ouverture, on choisit l'onglet par défaut UNE fois : Perso si non vide.
  bool _defaultChosen = false;

  /// `true` si au moins un anime du planning est dans le calendrier perso
  /// (présent en biblio, hors Abandonné).
  bool _persoHasContent(
      List<AnimeSamaPlanningItem> items, Set<int> persoIds) {
    if (persoIds.isEmpty) return false;
    for (final it in items) {
      if (persoIds.contains(animeSamaIdFor(it.title))) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final planningAsync = ref.watch(_planningProvider);
    final persoIds = ref.watch(_persoIdsProvider).asData?.value;

    // Choix de l'onglet par défaut, une seule fois, quand les deux données
    // sont prêtes : Perso s'il a du contenu, sinon Global.
    if (!_defaultChosen && persoIds != null) {
      final items = planningAsync.asData?.value;
      if (items != null) {
        _defaultChosen = true;
        if (_persoHasContent(items, persoIds)) {
          _showGlobal = false;
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('Planning', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Rafraîchir',
                onPressed: () {
                  ref.invalidate(_planningProvider);
                  ref.invalidate(_persoIdsProvider);
                  ref.invalidate(_libraryIdsProvider);
                },
              ),
              const SizedBox(width: 4),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Global')),
                  ButtonSegment(value: false, label: Text('Perso')),
                ],
                selected: {_showGlobal},
                onSelectionChanged: (s) => setState(() => _showGlobal = s.first),
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: planningAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _PlanningError(
              message: err is ResolveException ? err.message : err.toString(),
            ),
            data: (items) {
              if (items.isEmpty) return const _PlanningEmpty();
              return _PlanningColumns(items: items, showGlobal: _showGlobal);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Colonnes de jour
// ---------------------------------------------------------------------------

class _PlanningColumns extends ConsumerWidget {
  final List<AnimeSamaPlanningItem> items;
  final bool showGlobal;
  const _PlanningColumns({required this.items, required this.showGlobal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persoIds = ref.watch(_persoIdsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => <int>{},
        );
    final libraryIds = ref.watch(_libraryIdsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => <int>{},
        );

    final byDay = <String, List<AnimeSamaPlanningItem>>{};
    for (final item in items) {
      byDay.putIfAbsent(item.day, () => []).add(item);
    }

    final days = byDay.keys.toList()
      ..sort((a, b) => _dayRank(a).compareTo(_dayRank(b)));
    for (final list in byDay.values) {
      list.sort((a, b) => _timeRank(a.time).compareTo(_timeRank(b.time)));
    }

    // Un seul scroll vertical GLOBAL pour toute la page ; scroll horizontal
    // pour parcourir les jours. Les colonnes ont leur hauteur naturelle.
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final day in days)
              _DayColumn(
                day: day,
                items: byDay[day]!,
                showGlobal: showGlobal,
                persoIds: persoIds,
                libraryIds: libraryIds,
              ),
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final String day;
  final List<AnimeSamaPlanningItem> items;
  final bool showGlobal;
  final Set<int> persoIds;
  final Set<int> libraryIds;
  const _DayColumn({
    required this.day,
    required this.items,
    required this.showGlobal,
    required this.persoIds,
    required this.libraryIds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          // Cartes à hauteur naturelle : le scroll vertical est GLOBAL (parent).
          for (final item in items)
            _PlanningCard(
              item: item,
              showGlobal: showGlobal,
              persoIds: persoIds,
              libraryIds: libraryIds,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte « poster » d'un anime du planning
// ---------------------------------------------------------------------------

class _PlanningCard extends ConsumerStatefulWidget {
  final AnimeSamaPlanningItem item;
  final bool showGlobal;
  final Set<int> persoIds;
  final Set<int> libraryIds;
  const _PlanningCard({
    required this.item,
    required this.showGlobal,
    required this.persoIds,
    required this.libraryIds,
  });

  @override
  ConsumerState<_PlanningCard> createState() => _PlanningCardState();
}

class _PlanningCardState extends ConsumerState<_PlanningCard> {
  bool _busy = false;

  /// Récupère le Media depuis le cache local (par id anime-sama), ou construit
  /// un Media minimal si absent. Jamais null : le lecteur a toujours un titre.
  Future<Media> _resolveMedia() async {
    final id = animeSamaIdFor(widget.item.title);
    final cached = await ref.read(mediaRepositoryProvider).getMedia(id);
    if (cached != null) return cached;
    return Media(
      anilistId: id,
      title: MediaTitle(romaji: widget.item.title),
      animeSamaTitle: widget.item.title,
    );
  }

  Future<void> _launch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final media = await _resolveMedia();
      await _memorizeCurrentSeason(media.anilistId);

      final listRepo = ref.read(listRepositoryProvider);
      final progressRepo = ref.read(progressRepositoryProvider);
      final existing = await listRepo.getEntry(media.anilistId);
      final entry = existing ??
          ListEntry(
            mediaId: media.anilistId,
            status: ListStatus.planning,
            updatedAt: DateTime.now(),
          );
      final lastWatched = await progressRepo.lastWatched(media.anilistId);
      final episode = lastWatched?.episodeNumber.toInt() ?? 1;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerPage(
            media: media,
            episode: episode,
            entry: entry,
            animeSamaTitle: widget.item.title,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lecture impossible : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mémorise la saison la plus récente d'anime-sama (best-effort).
  Future<void> _memorizeCurrentSeason(int anilistId) async {
    try {
      // Provider global (cache partagé avec la fiche) plutôt qu'un appel direct.
      final seasons =
          await ref.read(animeSamaSeasonsProvider(widget.item.title).future);
      if (seasons.isNotEmpty) {
        await ref.read(settingsRepositoryProvider).set(
              SettingsKeys.animeSamaSeasonFor(anilistId),
              '${seasons.last.index}',
            );
      }
    } catch (_) {/* best-effort */}
  }

  Future<void> _togglePlanning() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final media = await _resolveMedia();
      final listRepo = ref.read(listRepositoryProvider);
      await ref.read(mediaRepositoryProvider).upsertMedia(media);
      final existing = await listRepo.getEntry(media.anilistId);
      final entry = existing?.copyWith(
            status: ListStatus.planning,
            updatedAt: DateTime.now(),
          ) ??
          ListEntry(
            mediaId: media.anilistId,
            status: ListStatus.planning,
            updatedAt: DateTime.now(),
          );
      await listRepo.upsertEntry(entry);
      ref.invalidate(_persoIdsProvider);
      ref.invalidate(_libraryIdsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('« ${widget.item.title} » ajouté en Planifié'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final mediaAsync = ref.watch(_mediaForTitleProvider(item.title));
    final media = mediaAsync.asData?.value;

    // Identité stable de l'anime (id anime-sama dérivé du titre) : indépendante
    // du rematch AniList, disponible immédiatement.
    final id = animeSamaIdFor(item.title);
    final inLibrary = widget.libraryIds.contains(id);
    final inPerso = widget.persoIds.contains(id);

    // Mode Perso : n'afficher que les anime suivis (biblio sauf Abandonné).
    if (!widget.showGlobal && !inPerso) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final coverUrl = media?.coverUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _busy ? null : _launch,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Poster ---
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                  if (coverUrl != null)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) => progress == null
                          ? child
                          : const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white38),
                      ),
                    )
                  else
                    Center(
                      child: mediaAsync.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.movie_outlined,
                              color: Colors.white38, size: 32),
                    ),

                  // Overlay play + busy.
                  if (_busy)
                    Container(
                      color: Colors.black38,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),

                  // Bouton ajout planning perso (coin haut-droit).
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: IconButton(
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          inLibrary
                              ? Icons.bookmark
                              : Icons.bookmark_add_outlined,
                          color: inLibrary ? Colors.orange : Colors.white,
                        ),
                        tooltip: inLibrary
                            ? 'Déjà dans ta bibliothèque'
                            : 'Ajouter en Planifié',
                        onPressed:
                            (_busy || inLibrary) ? null : _togglePlanning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- Titre + heure ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (item.time.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 13, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(item.time, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// États vide / erreur
// ---------------------------------------------------------------------------

class _PlanningEmpty extends StatelessWidget {
  const _PlanningEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 56, color: Colors.white38),
          SizedBox(height: 12),
          Text('Aucun anime au planning'),
        ],
      ),
    );
  }
}

class _PlanningError extends StatelessWidget {
  final String message;
  const _PlanningError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Planning indisponible',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
