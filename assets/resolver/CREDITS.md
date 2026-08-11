# Crédits — scripts du résolveur

## anime_sama.py

`anime_sama.py` provient du projet tiers **animesama-cli** :

- Auteur : Miro-sh
- Dépôt : https://github.com/Miro-sh/animesama-cli

Ce fichier est **embarqué tel quel** dans Terebi (extrait automatiquement au
lancement) pour éviter une installation manuelle. Terebi n'en utilise que les
fonctions de résolution (`get_seasons`, `AnimeDownloader`, `HEADERS_BASE`), via
le wrapper `animesama_resolve.py`.

> ⚠️ Le dépôt d'origine ne publie pas de fichier LICENSE. Ce code est donc
> réutilisé ici dans un cadre **strictement personnel**. En cas de demande de
> l'auteur, ce fichier sera retiré. Merci à Miro-sh pour son travail.

## animesama_resolve.py

Wrapper maison (Terebi) qui pilote `anime_sama.py` en ligne de commande et
expose des actions JSON (resolve, list-seasons, list-episodes, search,
planning) consommées par l'app.
