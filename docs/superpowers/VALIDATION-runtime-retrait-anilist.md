# Checklist de validation runtime — retrait AniList/Jikan

A executer sur le PC de developpement (non reproductible en CI).

---

## 0. Prerequis

- L'application est deja buildee et lancee au moins une fois (pour que les scripts
  Python soient extraits dans le dossier support de l'application).
- Sur Windows, le dossier support est typiquement :
  `%APPDATA%\terebi\` ou `%LOCALAPPDATA%\terebi\`
  (verifier via : `dart run` ou en cherchant `anime_sama.py` dans
  `%APPDATA%`, `%LOCALAPPDATA%` ou `~/Library/Application Support/terebi`).
- Le wrapper Python (`animesama_wrapper.py` ou `animesama_cli.py`) et
  `anime_sama.py` sont co-localises dans ce dossier support.

> Astuce : pendant les tests, on peut directement utiliser les fichiers
> sources dans `assets/scripts/` du repo, en passant les memes arguments.

---

## 1. Scripts Python — verification directe

Remplacer `<SUPPORT_DIR>` par le chemin reel du dossier support de l'app
(ou par `assets/scripts/` dans le repo pour un test rapide).

### 1a. Catalogue detail (fiche d'un anime)

```bash
python <SUPPORT_DIR>/animesama_wrapper.py catalogue-detail --slug one-piece
```

Attendu : JSON valide avec les cles `slug`, `title`, `synopsis`, `genres`,
`cover`, `seasons`. Verifie que `seasons` contient les saisons de One Piece
(et PAS les saisons de Dragon Ball Z Heroes ou similaire).

### 1b. Page d'accueil

```bash
python <SUPPORT_DIR>/animesama_wrapper.py home
```

Attendu : JSON valide avec les cles `classics` (liste) et `latest_episodes`
(liste). Chaque item doit avoir au moins `slug`, `title`, `cover`.

### 1c. Catalogue filtre par genre

```bash
python <SUPPORT_DIR>/animesama_wrapper.py catalogue-filter --genre Action
```

Attendu : JSON valide, liste d'items anime avec `slug`, `title`, `cover`,
`genres`. Verifier que les resultats correspondent bien au genre "Action".

---

## 2. Accueil — rangees et images

- [ ] Lancer l'application.
- [ ] La page d'accueil affiche les rangees suivantes (avec des images CDN
  anime-sama) :
  - **Les classiques** : serie d'animes anciens/populaires
  - **Derniers episodes ajoutes** : animes recemment mis a jour
  - **Sortis du moment** : planning de la semaine courante
  - **Recommande - <genre>** (une ou plusieurs rangees selon la bibliotheque)
- [ ] Les images des cartes se chargent depuis le CDN anime-sama
  (URLs en `cdn.anime-sama.fr/...` ou similaire), pas d'image cassee.
- [ ] Les rangees "En ce moment" et "Continuer a regarder" s'affichent si
  l'utilisateur a des animes en cours (peuvent etre vides au 1er lancement).

---

## 3. Fiche detail

- [ ] Taper sur une carte de la page d'accueil (ex. One Piece).
- [ ] La fiche affiche :
  - [ ] Le synopsis venant d'anime-sama (en francais si disponible).
  - [ ] Les genres corrects.
  - [ ] L'image de couverture depuis le CDN anime-sama.
- [ ] Les saisons chargees sont les BONNES saisons de l'anime :
  - Ex. One Piece -> les saisons "One Piece" (pas "Dragon Ball Z Heroes").
  - Ex. Naruto -> les saisons Naruto/Naruto Shippuden, pas d'anime etranger.
- [ ] Ouvrir une saison -> les episodes se chargent correctement.

---

## 4. Progression en temps reel

- [ ] Marquer un episode comme vu (clic sur l'episode ou apres lecture).
- [ ] Revenir a la page d'accueil **sans relancer l'app** : la rangee
  "Continuer a regarder" ou "En ce moment" se met a jour immediatement.
- [ ] Rouvrir la fiche de cet anime : la progression (episode marque) est
  correctement affichee, sans relance.
- [ ] Verifier aussi la bibliotheque : l'anime apparait avec la bonne
  progression.

---

## 5. Purge d'un anime

- [ ] Dans la bibliotheque, retirer un anime (bouton supprimer ou purge).
- [ ] Sans relancer l'app : l'anime disparait de la bibliotheque et des
  rangees de decouverte (il peut reapparaitre dans les rangees "classiques"
  etc. puisqu'il n'est plus filtre).

---

## 6. Migration (uniquement si mise a jour depuis une version avec AniList)

> Si c'est un premier lancement propre, ignorer cette section.

- [ ] Au premier lancement apres mise a jour, la progression des animes
  deja suivis est conservee sous la nouvelle identite (slug anime-sama).
- [ ] Pour verifier les eventuels echecs de migration, consulter la cle
  `slug_migration_report` dans la table `app_settings` de la base SQLite :

  ```sql
  SELECT value FROM app_settings WHERE key = 'slug_migration_report';
  ```

  Le JSON contient les slugs qui ont echoue. Pour une reparation manuelle,
  fournir le fichier de base de donnees (`terebi.db`) a l'equipe.

  Chemin de la base de donnees (Windows) :
  `%APPDATA%\terebi\terebi.db` ou `%LOCALAPPDATA%\terebi\terebi.db`

---

## Criteres de validation

| Critere | Attendu |
|---|---|
| Scripts Python | Repondent avec JSON valide, pas d'exception |
| Accueil | 3+ rangees, images CDN, pas de rangee vide inattendue |
| Fiche | Synopsis/genres/image d'anime-sama, bonnes saisons |
| Progression | Mise a jour sans relance de l'app |
| Purge | Disparition immediate sans relance |
| Migration | Progression conservee, rapport consultable si echec |
