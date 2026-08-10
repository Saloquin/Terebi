# Installation de Terebi sur PC perso (Windows)

Guide pour cloner **Terebi** et le lancer en natif sur un PC Windows personnel
(sans les restrictions EDR du poste pro). À faire une fois.

> Rappel : Terebi est une app **Flutter** (langage **Dart**). Visual Studio n'est
> requis que comme **compilateur C++ en arrière-plan** pour produire l'exécutable
> Windows — tu n'écris pas de C++ et tu n'ouvriras jamais Visual Studio.

---

## Résumé de ce qu'il faut installer

| # | Outil | Rôle | Obligatoire ? |
|---|-------|------|---------------|
| 1 | **Git** | Cloner le dépôt | Oui |
| 2 | **Flutter SDK** (inclut Dart) | Framework de l'app | Oui |
| 3 | **Visual Studio 2022 + « Desktop C++ »** | Compiler pour Windows | **Oui** (lancement Windows) |
| 4 | **mpv / libmpv** | Moteur du lecteur vidéo (media_kit) | Oui (lecture) |
| 5 | **Python 3** | Exécute le résolveur anime-sama | Oui (lecture) |
| 6 | **animesama-cli** (`anime_sama.py`) | Résout l'URL du flux VOSTFR/VF | Oui (lecture) |
| 7 | **Developer Mode Windows** | Support des symlinks (plugins Flutter) | Oui |

---

## 1. Git

- Télécharger : <https://git-scm.com/download/win>
- Ou via winget :
  ```powershell
  winget install --id Git.Git -e
  ```
- Fournit aussi **Git Bash**, utile pour les commandes shell.

## 2. Flutter SDK (inclut Dart)

- Guide officiel : <https://docs.flutter.dev/get-started/install/windows/desktop>
- Méthode simple (Git Bash ou PowerShell) — cloner la branche stable :
  ```bash
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
  ```
  Puis ajouter `…\flutter\bin` au **PATH** (variables d'environnement Windows).
- Vérifier :
  ```powershell
  flutter --version
  flutter doctor
  ```
  `flutter doctor` liste ce qui manque (Visual Studio, etc.). L'Android SDK
  peut être ignoré (on ne cible pas Android).

## 3. Visual Studio 2022 avec la charge « Desktop development with C++ »

- Télécharger Visual Studio Community (gratuit) :
  <https://visualstudio.microsoft.com/fr/downloads/>
- **IMPORTANT** : à l'installation, cocher la charge de travail
  **« Développement Desktop en C++ » / « Desktop development with C++ »**
  (avec les composants par défaut).
- Ou en ligne de commande (Build Tools seuls, plus léger, sans l'IDE) :
  ```powershell
  winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
  ```
- Doc Flutter à ce sujet : <https://docs.flutter.dev/get-started/install/windows/desktop#development-tools>

## 4. mpv / libmpv (moteur du lecteur)

media_kit (le lecteur encastré de Terebi) s'appuie sur **libmpv**.

- Site officiel mpv : <https://mpv.io/installation/>
- Builds Windows recommandés (shinchiro) :
  <https://github.com/shinchiro/mpv-winbuild-cmake/releases>
- Ou via winget / Scoop :
  ```powershell
  winget install --id=9NV1GV1PXRP9   # mpv (Microsoft Store)
  ```
  ```powershell
  scoop install mpv                   # si tu utilises Scoop
  ```
- Doc media_kit (dépendances) : <https://pub.dev/packages/media_kit#windows>
  (media_kit télécharge normalement libmpv automatiquement au build ; garder mpv
  installé permet aussi le fallback lecteur externe).

## 5. Python 3 (résolveur anime-sama)

Terebi résout l'URL du flux **VOSTFR/VF** via un wrapper Python autour du projet
**animesama-cli**.

- Télécharger : <https://www.python.org/downloads/> (ou `winget install Python.Python.3.12`).
- Dépendances Python :
  ```powershell
  pip install requests beautifulsoup4
  ```

## 6. animesama-cli (`anime_sama.py`)

- Dépôt : <https://github.com/Miro-sh/animesama-cli>
  ```powershell
  pipx install animesama-cli   # ou : git clone puis noter le chemin de anime_sama.py
  ```
- Dans **Terebi → Paramètres → Source (anime-sama)** : renseigne le chemin de
  `anime_sama.py` s'il n'est pas détecté automatiquement (chemin du dépôt cloné
  ou de l'install pipx), ainsi que le chemin Python si besoin.

> Astuce : **Scoop** (<https://scoop.sh/>) installe proprement mpv et Python.
> Installation de Scoop :
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> irm get.scoop.sh | iex
> ```

## 7. Activer le Developer Mode Windows (symlinks)

Flutter en a besoin pour les plugins. Ouvre :
```powershell
start ms-settings:developers
```
puis active **« Mode développeur »**.

---

## Lancer Terebi

Une fois 1→7 installés :

```bash
# 1. Cloner le dépôt (remplace par l'URL de ton remote)
git clone <URL_DU_DEPOT> terebi
cd terebi
git checkout feat/terebi-flutter-rewrite   # branche de la réécriture Flutter

# 2. Récupérer les dépendances Dart
flutter pub get

# 3. Générer le code drift (base de données)
dart run build_runner build --delete-conflicting-outputs

# 4. Vérifier l'environnement
flutter doctor          # tout doit être vert (Android ignorable)

# 5. Lancer l'app en natif Windows
flutter run -d windows
```

L'app **Terebi** devrait s'ouvrir. Teste : recherche un anime → fiche → « Reprendre »
→ le lecteur encastré charge le flux via anime-sama.

---

## Vérifications (facultatif)

```bash
flutter test            # tests widgets (marche sur un poste sans EDR)
flutter analyze         # analyse statique
flutter build windows   # produit l'exécutable Release
```

## Tester le résolveur anime-sama (diagnostic lecture)

Dans Git Bash, pour confirmer que le wrapper résout bien une URL (adapte le
chemin de `anime_sama.py`) :
```bash
python anime_sama.py --help
```
Le lecteur de Terebi capture l'URL `.m3u8`/`.mp4` renvoyée par le résolveur pour
alimenter le lecteur encastré.

---

## Source de lecture (anime-sama, VOSTFR/VF)

Terebi lit en **VOSTFR/VF** via **anime-sama**, en s'appuyant sur le projet
**animesama-cli** (Python) — voir les étapes 5 et 6 ci-dessus.

- Dans **Terebi → Paramètres → Source (anime-sama)** : renseigne au besoin le
  chemin de `anime_sama.py` et le chemin Python.
- La langue (VOSTFR/VF) se choisit dans **Paramètres → Lecture** (défaut) et se
  change à la volée depuis le lecteur ; elle est mémorisée par anime.

---

## Références

- Flutter (install Windows desktop) : <https://docs.flutter.dev/get-started/install/windows/desktop>
- media_kit : <https://pub.dev/packages/media_kit>
- mpv : <https://mpv.io/>
- animesama-cli : <https://github.com/Miro-sh/animesama-cli>
- Scoop : <https://scoop.sh/>
- AniList API (métadonnées) : <https://anilist.gitbook.io/anilist-apiv2-docs/>

---

## Notes

- **Poste pro vs perso** : sur le poste pro, l'antivirus (EDR) bloque
  `flutter_tester.exe` et Visual Studio manque → on développe via un conteneur
  Docker (`Dockerfile.flutter-ci`). Sur ton PC perso, aucune de ces limites :
  `flutter run -d windows` fonctionne directement.
- **OAuth AniList** : pour le MVP, le token se colle manuellement dans
  Paramètres. Crée une app OAuth sur <https://anilist.co/settings/developer>
  si besoin (Redirect URI affiché dans la page Paramètres).
- **Usage personnel** : Terebi orchestre la lecture via une source tierce
  (anime-sama), fragile et non contractuelle. Usage perso uniquement.
