/// Domaine pur — liste figée des genres anime-sama et options de tri du
/// catalogue. AUCUN import de package:flutter (testable via `dart test`).
///
/// Les genres servent au menu déroulant du filtre « parcourir » du catalogue.
/// Liste figée (observée sur le site anime-sama) : maintenance manuelle si le
/// site en ajoute. Le filtrage réel est fait côté serveur via `genre[]`.
library;

/// Genres du catalogue anime-sama, en ordre alphabétique pour le dropdown.
const List<String> kAnimeSamaGenres = [
  'Action',
  'Arts martiaux',
  'Autre monde',
  'Aventure',
  'Combats',
  'Comédie',
  'Crime',
  'Démons',
  'Drame',
  'Ecchi',
  'Fantastique',
  'Fantasy',
  'Ghibli',
  'Guerre',
  'Harem',
  'Historique',
  'Horreur',
  'Isekai',
  'Josei',
  'Magie',
  'Mecha',
  'Musique',
  'Mystère',
  'Politique',
  'Psychologique',
  'Réincarnation',
  'Romance',
  'School Life',
  'Science-Fiction',
  'Seinen',
  'Shônen',
  'Slice of Life',
  'Sport',
  'Surnaturel',
  'Thriller',
  'Tournois',
  'Vengeance',
];

/// Champ de tri des résultats du catalogue. Le serveur anime-sama ne trie pas :
/// le tri est appliqué côté app sur la page récupérée. L'année n'est pas triable
/// (absente de la carte catalogue), d'où un tri alphabétique uniquement.
enum CatalogSortField {
  /// Tri alphabétique croissant sur le titre (A → Z).
  titleAsc,

  /// Tri alphabétique décroissant sur le titre (Z → A).
  titleDesc,
}

/// Libellés affichables pour [CatalogSortField].
const Map<CatalogSortField, String> kCatalogSortLabels = {
  CatalogSortField.titleAsc: 'Titre A→Z',
  CatalogSortField.titleDesc: 'Titre Z→A',
};
