library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/logic/effective_status_service.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../pages/resume_helper.dart';
import '../widgets/anime_sama_image.dart';
import '../widgets/tv_focusable.dart';
import 'widgets/tv_side_panel.dart';

// ---------------------------------------------------------------------------
// Providers locaux (copiés depuis media_detail_page.dart — non exportés)
// ---------------------------------------------------------------------------

final _resolvedSlugProvider =
    FutureProvider.family<String, String>((ref, title) async {
  if (title.trim().isEmpty) return '';
  try {
    final resolver = await ref.watch(animeSamaResolverProvider.future);
    final items = await resolver.search(query: title);
    if (items.isEmpty) return '';
    var best = items.first;
    var bestScore = -1;
    for (final it in items) {
      final s = titleMatchScore(title, it.title);
      if (s > bestScore) {
        bestScore = s;
        best = it;
      }
    }
    return best.slug;
  } catch (_) {
    return '';
  }
});

final _mediaDetailProvider =
    StreamProvider.family<Media?, ({int id, String? title})>(
        (ref, arg) async* {
  final repo = ref.watch(mediaRepositoryProvider);
  final cached = await repo.getMedia(arg.id);
  var slug = cached?.animeSamaSlug;
  if ((slug == null || slug.isEmpty) &&
      arg.title != null &&
      arg.title!.trim().isNotEmpty) {
    slug = await ref.watch(_resolvedSlugProvider(arg.title!).future);
  }
  if (slug != null && slug.isNotEmpty) {
    final service = await ref.watch(animeSamaCatalogServiceProvider.future);
    yield* service.watchDetail(slug);
    return;
  }
  yield* repo.watchMedia(arg.id);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class MediaDetailPageTv extends ConsumerStatefulWidget {
  final int mediaId;
  final String? displayTitle;

  const MediaDetailPageTv({
    super.key,
    required this.mediaId,
    this.displayTitle,
  });

  @override
  ConsumerState<MediaDetailPageTv> createState() =>
      _MediaDetailPageTvState();
}

class _MediaDetailPageTvState extends ConsumerState<MediaDetailPageTv> {
  // null = pas de panneau ; 'seasons' | 'status' = panneau ouvert
  String? _openPanel;

  void _closePanel() => setState(() => _openPanel = null);

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(
        _mediaDetailProvider((id: widget.mediaId, title: widget.displayTitle)));
    final media = mediaAsync.asData?.value ??
        (widget.displayTitle != null
            ? Media.fromAnimeSama(
                slug: normalizeAnimeTitle(widget.displayTitle!),
                title: widget.displayTitle!)
            : Media(
                mediaId: widget.mediaId,
                title: const MediaTitle(romaji: 'Anime')));

    final title = widget.displayTitle ??
        media.animeSamaTitle ??
        media.title.preferred;
    final slug = media.animeSamaSlug ?? '';

    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.goBack) {
          if (_openPanel != null) {
            _closePanel();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // --- Fond : bannière floue ---
            _BlurredBackground(slug: slug, media: media),
            // --- Gradient sombre ---
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.black87, Colors.transparent],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                  stops: [0.0, 0.5],
                ),
              ),
            ),
            // --- Contenu : infos + boutons ---
            Padding(
              padding: const EdgeInsets.all(48),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Panneau latéral gauche (saisons ou statut)
                  if (_openPanel != null)
                    _buildPanel(media, title),
                  // Infos (gauche)
                  Expanded(
                    flex: 3,
                    child: _InfoColumn(
                        media: media, title: title, displayTitle: widget.displayTitle),
                  ),
                  const SizedBox(width: 48),
                  // Boutons (droite)
                  _ButtonColumn(
                    media: media,
                    title: title,
                    onOpenStatus: () =>
                        setState(() => _openPanel = 'status'),
                    onOpenSeasons: () =>
                        setState(() => _openPanel = 'seasons'),
                  ),
                ],
              ),
            ),
            // Bouton Retour
            Positioned(
              top: 16,
              left: 16,
              child: TvFocusable(
                onPressed: () => Navigator.of(context).pop(),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(Media media, String title) {
    final searchTitle =
        media.animeSamaTitle ?? widget.displayTitle ?? media.title.preferred;
    if (_openPanel == 'seasons') {
      return _SeasonsPanel(
        media: media,
        searchTitle: searchTitle,
        onClose: _closePanel,
      );
    }
    // Panneau statut
    final items = [
      const TvSidePanelItem(label: '— Auto (selon progression)', value: null),
      TvSidePanelItem(label: 'En pause', value: ListStatus.paused),
      TvSidePanelItem(label: 'Abandonné', value: ListStatus.dropped),
      TvSidePanelItem(label: 'Revisionnage', value: ListStatus.repeating),
    ];
    return TvSidePanel(
      title: 'Statut',
      items: items,
      onSelected: (item) async {
        _closePanel();
        final newStatus = item.value as ListStatus?;
        final repo = ref.read(listRepositoryProvider);
        await ref.read(mediaRepositoryProvider).upsertMedia(media);
        final existing = await repo.getEntry(media.mediaId);
        if (newStatus == null) {
          if (existing == null) return;
          await repo.upsertEntry(existing.copyWith(
            status: ListStatus.planning,
            updatedAt: DateTime.now(),
          ));
        } else {
          final updated = existing?.copyWith(
                status: newStatus,
                updatedAt: DateTime.now(),
              ) ??
              ListEntry(
                mediaId: media.mediaId,
                status: newStatus,
                updatedAt: DateTime.now(),
              );
          await repo.upsertEntry(updated);
        }
        ref.invalidate(entriesByStatusProvider);
        ref.invalidate(countByStatusProvider);
      },
      onClose: _closePanel,
    );
  }
}

// ---------------------------------------------------------------------------
// Fond flouté
// ---------------------------------------------------------------------------

class _BlurredBackground extends StatelessWidget {
  final String slug;
  final Media media;
  const _BlurredBackground({required this.slug, required this.media});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: slug.isNotEmpty
          ? AnimeSamaImage(
              slug: slug,
              banner: true,
              fallbackUrl: media.bannerUrl ?? media.coverUrl,
              fit: BoxFit.cover,
            )
          : media.bannerUrl != null
              ? Image.network(media.bannerUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.black))
              : Container(color: Colors.black),
    );
  }
}

// ---------------------------------------------------------------------------
// Colonne d'infos (gauche)
// ---------------------------------------------------------------------------

class _InfoColumn extends StatelessWidget {
  final Media media;
  final String title;
  final String? displayTitle;
  const _InfoColumn(
      {required this.media, required this.title, required this.displayTitle});

  String get _cleanSynopsis {
    final raw = media.description ?? '';
    return raw
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 8)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        if (_cleanSynopsis.isNotEmpty) ...[
          Text(
            _cleanSynopsis,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
        ],
        if (media.genres.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final g in media.genres.take(5))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(g,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Colonne de boutons (droite)
// ---------------------------------------------------------------------------

class _ButtonColumn extends ConsumerWidget {
  final Media media;
  final String title;
  final VoidCallback onOpenStatus;
  final VoidCallback onOpenSeasons;

  const _ButtonColumn({
    required this.media,
    required this.title,
    required this.onOpenStatus,
    required this.onOpenSeasons,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(listEntryProvider(media.mediaId));
    final entry = entryAsync.asData?.value;
    final searchTitle = media.animeSamaTitle ?? title;
    final seasonsAsync =
        ref.watch(animeSamaSeasonsProvider(searchTitle));
    final seasons = seasonsAsync.asData?.value ?? [];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lire
        _TvActionButton(
          autofocus: true,
          icon: Icons.play_arrow,
          label: 'Lire',
          onPressed: () => resumePlayback(context, ref, media),
        ),
        const SizedBox(height: 12),
        // Ajouter / Modifier statut
        if (entry == null)
          _TvActionButton(
            icon: Icons.add,
            label: 'Ajouter',
            onPressed: () async {
              await ref.read(mediaRepositoryProvider).upsertMedia(media);
              final hasProgress = await ref
                  .read(seasonProgressRepositoryProvider)
                  .hasAnyProgress(media.mediaId);
              final status =
                  effectiveStatus(entry: null, hasProgress: hasProgress) ??
                      ListStatus.planning;
              await ref.read(listRepositoryProvider).upsertEntry(ListEntry(
                    mediaId: media.mediaId,
                    status: status,
                    updatedAt: DateTime.now(),
                  ));
              ref.invalidate(entriesByStatusProvider);
              ref.invalidate(countByStatusProvider);
            },
          )
        else
          _TvActionButton(
            icon: Icons.edit,
            label: 'Modifier statut',
            onPressed: onOpenStatus,
          ),
        // Saisons (si plusieurs)
        if (seasons.length > 1) ...[
          const SizedBox(height: 12),
          _TvActionButton(
            icon: Icons.layers,
            label: 'Saisons',
            onPressed: onOpenSeasons,
          ),
        ],
      ],
    );
  }
}

class _TvActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  const _TvActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panneau des saisons
// ---------------------------------------------------------------------------

class _SeasonsPanel extends ConsumerWidget {
  final Media media;
  final String searchTitle;
  final VoidCallback onClose;

  const _SeasonsPanel({
    required this.media,
    required this.searchTitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonsAsync = ref.watch(animeSamaSeasonsProvider(searchTitle));

    return seasonsAsync.when(
      loading: () => const SizedBox(
        width: 280,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox(
        width: 280,
        child: Center(
            child: Text('Erreur', style: TextStyle(color: Colors.white54))),
      ),
      data: (seasons) {
        final items = seasons
            .map((s) => TvSidePanelItem(
                  label: s.name.isNotEmpty ? s.name : 'Saison ${s.index}',
                  value: s.index,
                ))
            .toList();
        return TvSidePanel(
          title: 'Saisons',
          items: items,
          onSelected: (item) async {
            final index = item.value as int;
            await ref
                .read(settingsRepositoryProvider)
                .set(SettingsKeys.animeSamaSeasonFor(media.mediaId),
                    '$index');
            onClose();
          },
          onClose: onClose,
        );
      },
    );
  }
}
