/// Widget d'image d'anime dérivée du **slug** anime-sama (CDN).
///
/// L'image (cover/thumbnail ou bannière) n'existe pas sous une extension connue
/// d'avance sur le CDN : on essaie les extensions dans l'ordre
/// [animeSamaImageExtensions] (`jpg`, `webp`, `png`) via l'`errorBuilder` de
/// `Image.network`, en passant à la suivante à chaque échec, jusqu'à en trouver
/// une qui charge. Un [fallbackUrl] optionnel (ex. URL déjà en base) est essayé
/// en tout premier. Si tout échoue, affiche un placeholder.
///
/// Aucun effet de bord : le widget ne réécrit rien en base ; il re-dérive l'URL
/// du slug à chaque montage (coût négligeable). La persistance de l'URL en base
/// est assurée ailleurs (revalidation / scraper).
library;

import 'package:flutter/material.dart';

import '../../domain/logic/anime_id.dart';

class AnimeSamaImage extends StatefulWidget {
  /// Slug anime-sama (identité logique), ex. `link-click`.
  final String slug;

  /// `true` = bannière (`.../contenu/<slug>.<ext>`) ; sinon cover/thumbnail
  /// (`.../contenu/thumb/<slug>.<ext>`).
  final bool banner;

  /// Ajustement de l'image dans sa boîte.
  final BoxFit fit;

  /// URL éventuelle déjà connue (ex. depuis la base) essayée en premier.
  final String? fallbackUrl;

  const AnimeSamaImage({
    super.key,
    required this.slug,
    this.banner = false,
    this.fit = BoxFit.cover,
    this.fallbackUrl,
  });

  @override
  State<AnimeSamaImage> createState() => _AnimeSamaImageState();
}

class _AnimeSamaImageState extends State<AnimeSamaImage> {
  /// Liste ordonnée des URLs candidates à essayer (fallback puis extensions).
  late List<String> _candidates;

  /// Index de la candidate en cours d'essai.
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates();
  }

  @override
  void didUpdateWidget(AnimeSamaImage old) {
    super.didUpdateWidget(old);
    // Slug/type/fallback changé : on repart du début.
    if (old.slug != widget.slug ||
        old.banner != widget.banner ||
        old.fallbackUrl != widget.fallbackUrl) {
      setState(() {
        _candidates = _buildCandidates();
        _index = 0;
      });
    }
  }

  /// Construit la liste ordonnée : [fallbackUrl] (si présent) puis chaque
  /// extension du CDN dans l'ordre [animeSamaImageExtensions].
  List<String> _buildCandidates() {
    final urls = <String>[];
    final fb = widget.fallbackUrl;
    if (fb != null && fb.isNotEmpty) urls.add(fb);
    for (final ext in animeSamaImageExtensions) {
      urls.add(widget.banner
          ? animeSamaBannerUrl(widget.slug, ext: ext)
          : animeSamaCoverUrl(widget.slug, ext: ext));
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    // Slug vide ou toutes les candidates épuisées : placeholder.
    if (widget.slug.isEmpty || _index >= _candidates.length) {
      return placeholder;
    }
    return Image.network(
      _candidates[_index],
      fit: widget.fit,
      // Passe à la candidate suivante au prochain frame (evite setState en build).
      errorBuilder: (context, _, __) {
        if (_index < _candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
          // En attendant le rebuild, on montre le placeholder.
          return placeholder;
        }
        return placeholder;
      },
    );
  }
}

/// Placeholder identique visuellement à celui des cartes.
class _Placeholder extends StatelessWidget {
  final Color color;
  const _Placeholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}
