# Terebi

> **Terebi** (テレビ, « télé ») — application de suivi, planning et visionnage d'anime, avec
> lecteur vidéo intégré. Desktop **et** Android (téléphone / TV).

Terebi récupère tout depuis **anime-sama** (catalogue, saisons, épisodes, flux vidéo, planning) via
un résolveur **100 % Dart** — aucune dépendance externe à installer.

## Fonctionnalités

- **Suivi** : statuts (en cours / planifié / terminé / en pause / abandonné / revisionnage),
  progression par saison — source de vérité **locale (SQLite)**.
- **Catalogue & découverte** : recherche, fiches (synopsis, genres, couverture), filtres par genre,
  sections d'accueil.
- **Planning** : calendrier hebdomadaire des diffusions (VOSTFR / VF).
- **Lecture** : lecteur vidéo **encastré** (media_kit / libmpv), reprise au timestamp, enchaînement
  automatique de l'épisode suivant, contrôles tactiles sur mobile.
- **AniSkip** : saut automatique de l'intro / outro (timestamps via MyAnimeList + api.aniskip.com).

## Stack

| Couche | Technologie |
|--------|-------------|
| UI | **Flutter** (Windows, Linux, Android — téléphone & TV) |
| État | **Riverpod** |
| Lecteur | **media_kit** (libmpv) — vidéo encastrée |
| Persistance | **SQLite** (drift) — source de vérité du suivi |
| Source & résolution | **anime-sama** — scraping + résolution de flux 100 % Dart (`package:http` + `package:html`) |

Le résolveur est écrit entièrement en Dart (`lib/src/services/animesama_*.dart`) : plus aucun
processus externe, ce qui rend l'app autonome sur toutes les plateformes, y compris Android où les
sous-processus sont impossibles.

## Développement

Le poste de développement principal bloque `flutter_tester` (EDR) ; les tests, l'analyse et les
builds Linux/Android passent par un conteneur Docker Linux.

```bash
# Analyse statique
./scripts/flutter-ci.sh analyze

# Tests (logique pure + widgets)
./scripts/flutter-ci.sh test

# Build Linux (debug)
./scripts/flutter-ci.sh build linux --debug
```

Builds natifs (hors conteneur) :

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # génère le code drift

flutter build windows --release   # Windows (requiert Visual Studio + « Desktop C++ »)
flutter build apk --release        # Android (requiert le keystore, cf. android/key.properties)
```

## Documentation

- **Cahier des charges** : [`docs/CAHIER_DES_CHARGES_STREAMING.md`](docs/CAHIER_DES_CHARGES_STREAMING.md)
- **Backlog produit** : [`docs/BACKLOG.md`](docs/BACKLOG.md)

## Signature Android

L'app est signée avec une **clé unique** (debug + release) référencée par `android/key.properties`
(non versionné). Le keystore est conservé **hors du dépôt**. Conserver cette clé est indispensable
pour publier des mises à jour installables par-dessus une version existante.
