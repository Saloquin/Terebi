## Nouveautés & correctifs (v2.3.12)

- **Correction de la fuite de position entre épisodes lors du changement de vidéo** :
  - **Arrêt préalable du lecteur vidéo** : lors du passage à un autre épisode (manuel ou automatique), le lecteur multimédia est désormais immédiatement stoppé avant toute mise à jour de l'épisode courant. Cela empêche les derniers événements de progression de l'épisode précédent (générique ou fin de vidéo) d'être attribués par erreur au nouvel épisode.
  - **Protection des abonnements aux flux MediaKit** : les écouteurs de position, durée et fin de vidéo ignorent les événements émis pendant les phases de chargement, de navigation ou lorsque le lecteur n'est pas encore prêt.
- **Gestion intelligente des génériques de fin et seuil de reprise** :
  - **Seuil de complétion adapté aux animés** : tout arrêt de lecture situé dans le générique de fin (au-delà de 88% de la vidéo ou à moins de 90 secondes de la fin) marque directement l'épisode comme vu et ne stocke aucune position intermédiaire résiduelle.
  - **Suppression des invites de reprise en fin d'épisode** : le lecteur ne propose plus jamais de reprendre une vidéo interrompue à la fin / pendant les crédits ; il réinitialise automatiquement la position à 0 pour démarrer proprement.
  - **Bouton « Recommencer » persistant** : choisir « Recommencer » dans la boîte de dialogue de reprise réinitialise immédiatement la position à zéro dans la base SQLite locale pour ne plus reproposer l'invite lors des lancements futurs.
- **Nettoyage automatique de la base de données SQLite** :
  - Requête d'assainissement exécutée automatiquement à l'ouverture de la base pour remettre à zéro toutes les positions parasites accumulées en fin d'épisode sur les vidéos non complétées.
