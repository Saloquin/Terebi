/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Dérive le statut EFFECTIF (affiché) d'un anime à partir du statut STOCKÉ et
/// de la progression réelle.
///
/// Modèle (décision produit) :
/// - « En cours » (`current`) et « Terminé » (`completed`) sont AUTOMATIQUES :
///   dérivés de la progression, jamais choisis à la main.
/// - « Planifié / En pause / Abandonné / Revisionnage » sont MANUELS : choisis
///   par l'utilisateur et stockés tels quels.
///
/// Stockage interne (pour rester local + instantané, sans scraping anime-sama) :
/// - `current` n'est JAMAIS stocké : il est calculé (progression > 0).
/// - `completed` EST stocké comme un drapeau « entièrement vu », posé quand on
///   finit le dernier épisode / marque toutes les saisons vues (déjà local via
///   la progression par saison). C'est le seul statut « auto » persisté.
library;

import '../models/list_entry.dart';
import '../models/list_status.dart';

/// Statuts que l'utilisateur peut choisir MANUELLEMENT (les seuls proposés dans
/// le sélecteur de la fiche). `current`/`completed` en sont volontairement
/// exclus (automatiques).
const List<ListStatus> kManualStatuses = [
  ListStatus.planning,
  ListStatus.paused,
  ListStatus.dropped,
  ListStatus.repeating,
];

/// Vrai si [status] est un statut manuel « gelant » : tant qu'il est posé,
/// regarder un épisode ne repasse PAS l'anime « En cours » automatiquement
/// (on respecte l'intention de l'utilisateur : pause / abandon / revisionnage).
/// `planning` n'est PAS gelant : regarder un anime « planifié » le fait bien
/// passer « En cours ».
bool isFreezingManualStatus(ListStatus status) =>
    status == ListStatus.paused ||
    status == ListStatus.dropped ||
    status == ListStatus.repeating;

/// Calcule le statut EFFECTIF (affiché) d'une entrée.
///
/// - [entry] : l'entrée stockée (peut être `null` si l'anime n'est dans aucune
///   liste).
/// - [hasProgress] : vrai si l'utilisateur a une progression locale > 0 (au
///   moins un épisode/une saison entamé). Calculé par l'appelant depuis
///   `entry.progress > 0` et/ou la progression par saison.
///
/// Retourne `null` si l'anime ne doit apparaître dans AUCUNE liste (jamais
/// ajouté et aucune progression).
///
/// Priorités :
/// 1. `completed` stocké (drapeau « entièrement vu ») → Terminé.
/// 2. Statut manuel gelant (pause/abandonné/revisionnage) → ce statut.
/// 3. Progression > 0 → En cours (calculé).
/// 4. `planning` stocké → Planifié.
/// 5. Sinon → `null` (hors listes).
ListStatus? effectiveStatus({
  required ListEntry? entry,
  required bool hasProgress,
}) {
  final stored = entry?.status;
  if (stored == ListStatus.completed) return ListStatus.completed;
  if (stored != null && isFreezingManualStatus(stored)) return stored;
  if (hasProgress) return ListStatus.current;
  if (stored == ListStatus.planning) return ListStatus.planning;
  return null;
}
