# Checklist de validation runtime — retrait AniList/Jikan

A executer sur le PC de developpement (non reproductible en CI).

---

## 0. Prerequis

- Il y a DEUX scripts Python (embarques dans les assets du repo sous
  `assets/resolver/`, extraits au 1er lancement dans le dossier support) :
  - **`animesama_resolve.py`** : le wrapper maison (celui qu'on lance) ;
  - **`anime_sama.py`** : le script tiers, passe au wrapper via `--script`.
- Sur Windows, le dossier support est typiquement :
  `%APPDATA%\terebi\` ou `%LOCALAPPDATA%\terebi\`
  (verifier en cherchant `animesama_resolve.py` dans `%APPDATA%`,
  `%LOCALAPPDATA%` ou `~/Library/Application Support/terebi`).

> Astuce : pour un test rapide, on peut lancer directement les fichiers sources
> du repo, dans `assets/resolver/`, avec les memes arguments.

---

## 1. Scripts Python — verification directe

Le wrapper prend TOUJOURS `--script <chemin d'anime_sama.py>` et `--action <action>`.
Ci-dessous, on teste depuis le repo (`assets/resolver/`) ; remplacer par
`<SUPPORT_DIR>` pour tester les fichiers extraits par l'app.

### 1a. Catalogue detail (enrichissement d'un anime)

```bash
python assets/resolver/animesama_resolve.py \
  --script assets/resolver/anime_sama.py \
  --action catalogue-detail --slug one-piece
```

Attendu : une ligne `DETAIL_JSON: {...}` avec les cles `slug`, `title`,
`synopsis`, `genres`, `cover_url`, `banner_url`. Verifie que `title`/`synopsis`
correspondent bien a One Piece (et pas a une autre serie). Note : les SAISONS
ne sont PAS dans cette action — elles se testent avec `--action list-seasons`.

### 1b. Page d'accueil

```bash
python assets/resolver/animesama_resolve.py \
  --script assets/resolver/anime_sama.py \
  --action home
```

Attendu : une ligne `HOME_JSON: {...}` avec les cles `classics` (liste) et
`latest_episodes` (liste). Chaque item a au moins `slug`, `title`, `cover_url`.

### 1c. Catalogue filtre par genre

```bash
python assets/resolver/animesama_resolve.py \
  --script assets/resolver/anime_sama.py \
  --action catalogue-filter --genre Action
```

Attendu : une ligne `CATALOGUE_JSON: [...]`, liste d'items avec `slug`, `title`,
`url`, `cover_url`, `genres`. Verifier que les resultats correspondent au genre.

> En cas de sortie vide (`[]` / champs `null`) : le HTML d'anime-sama a
> probablement change ; les regex de `assets/resolver/animesama_resolve.py`
> (`action_catalogue_detail`, `action_home`, `_cards_from_html`) sont a ajuster.

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
  (URLs en `cdn.jsdelivr.net/gh/Anime-Sama/IMG/...`), pas d'image cassee.
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
