library;

import 'package:flutter/material.dart';

import '../../../domain/catalog_genre.dart';
import '../../widgets/tv_focusable.dart';

/// Grille des genres anime-sama, navigable au D-pad.
/// Appelle [onGenreSelected] avec le label du genre choisi.
class TvGenreGrid extends StatelessWidget {
  final void Function(String genre) onGenreSelected;

  const TvGenreGrid({super.key, required this.onGenreSelected});

  // Icônes associées à chaque genre (ordre identique à kAnimeSamaGenres).
  static const _icons = <String, IconData>{
    'Action': Icons.sports_martial_arts,
    'Arts martiaux': Icons.sports_kabaddi,
    'Autre monde': Icons.public,
    'Aventure': Icons.explore,
    'Combats': Icons.sports_mma,
    'Comédie': Icons.sentiment_very_satisfied,
    'Crime': Icons.gavel,
    'Démons': Icons.whatshot,
    'Drame': Icons.theater_comedy,
    'Ecchi': Icons.favorite_border,
    'Fantastique': Icons.auto_awesome,
    'Fantasy': Icons.castle,
    'Ghibli': Icons.forest,
    'Guerre': Icons.military_tech,
    'Harem': Icons.group,
    'Historique': Icons.history_edu,
    'Horreur': Icons.nightlight,
    'Isekai': Icons.swap_horiz,
    'Josei': Icons.woman,
    'Magie': Icons.stars,
    'Mecha': Icons.precision_manufacturing,
    'Musique': Icons.music_note,
    'Mystère': Icons.search,
    'Politique': Icons.account_balance,
    'Psychologique': Icons.psychology,
    'Réincarnation': Icons.refresh,
    'Romance': Icons.favorite,
    'School Life': Icons.school,
    'Science-Fiction': Icons.rocket_launch,
    'Seinen': Icons.man,
    'Shônen': Icons.boy,
    'Slice of Life': Icons.home,
    'Sport': Icons.sports_soccer,
    'Surnaturel': Icons.blur_on,
    'Thriller': Icons.crisis_alert,
    'Tournois': Icons.emoji_events,
    'Vengeance': Icons.flash_on,
  };

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemCount: kAnimeSamaGenres.length,
      itemBuilder: (context, i) {
        final genre = kAnimeSamaGenres[i];
        final icon = _icons[genre] ?? Icons.category;
        return TvFocusable(
          autofocus: i == 0,
          onPressed: () => onGenreSelected(genre),
          child: GestureDetector(
            onTap: () => onGenreSelected(genre),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      genre,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
