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
| 5 | **ani-cli** | Résout l'URL du flux | Oui (lecture) |
| 6 | **fzf** | Dépendance d'ani-cli | Oui (ani-cli en dépend) |
| 7 | **Developer Mode Windows** | Support des symlinks (plugins Flutter) | Oui |

---

## 1. Git

- Télécharger : <https://git-scm.com/download/win>
- Ou via winget :
  ```powershell
  winget install --id Git.Git -e
  ```
- Fournit aussi **Git Bash**, utile pour ani-cli.

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

## 5. ani-cli (résolution de la source)

- Dépôt officiel : <https://github.com/pystardust/ani-cli>
- Installation Windows (via **Scoop**, recommandé) :
  <https://github.com/pystardust/ani-cli#windows>
  ```powershell
  scoop bucket add extras
  scoop install ani-cli
  ```
- Ou manuellement (Git Bash) :
  ```bash
  curl -sL https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli -o "$HOME/bin/ani-cli"
  chmod +x "$HOME/bin/ani-cli"
  ```
  (et ajouter `~/bin` au PATH)

## 6. fzf (requis par ani-cli)

- Dépôt : <https://github.com/junegunn/fzf>
- Via Scoop / winget :
  ```powershell
  scoop install fzf
  ```
  ```powershell
  winget install --id junegunn.fzf -e
  ```

> Astuce : **Scoop** (<https://scoop.sh/>) installe proprement mpv, ani-cli et fzf
> d'un coup. Installation de Scoop :
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
→ le lecteur encastré charge le flux via ani-cli.

---

## Vérifications (facultatif)

```bash
flutter test            # tests widgets (marche sur un poste sans EDR)
flutter analyze         # analyse statique
flutter build windows   # produit l'exécutable Release
```

## Tester ani-cli seul (diagnostic lecture)

Dans Git Bash, pour confirmer qu'ani-cli résout bien une URL :
```bash
ANI_CLI_PLAYER=debug ani-cli -S 1 -e 1 "cowboy bebop"
```
Doit afficher des liens `.m3u8` (`All links:` / `Selected link:`). C'est ce que
Terebi capture pour alimenter le lecteur encastré.

---

## VOSTFR (anime-sama) — source de lecture française

Par défaut, Terebi lit en **VOSTFR/VF** via **anime-sama**, en s'appuyant sur le projet
**animesama-cli** (Python). ani-cli reste disponible en secours (VO sous-titrée **anglais**).

1. **Python 3** : <https://www.python.org/downloads/> (ou `winget install Python.Python.3.12`).
2. **Dépendances Python** :
   ```powershell
   pip install requests beautifulsoup4
   ```
3. **animesama-cli** (fournit `anime_sama.py`) : <https://github.com/Miro-sh/animesama-cli>
   ```powershell
   pipx install animesama-cli   # ou : git clone puis noter le chemin de anime_sama.py
   ```
4. Dans **Terebi → Paramètres → Source de lecture** : choisir « Anime-sama (VOSTFR/VF) ».
   Si le chemin de `anime_sama.py` n'est pas détecté automatiquement, renseigne-le dans le
   champ prévu (ex. le fichier `anime_sama.py` du dépôt cloné ou de l'install pipx).

> Pour basculer en anglais (ani-cli) : Paramètres → Source de lecture → « ani-cli (anglais) ».

---

## Références

- Flutter (install Windows desktop) : <https://docs.flutter.dev/get-started/install/windows/desktop>
- media_kit : <https://pub.dev/packages/media_kit>
- mpv : <https://mpv.io/>
- ani-cli : <https://github.com/pystardust/ani-cli>
- fzf : <https://github.com/junegunn/fzf>
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
- **Usage personnel** : Terebi orchestre la lecture via des sources tierces
  (ani-cli/allanime), fragiles et non contractuelles. Usage perso uniquement.
