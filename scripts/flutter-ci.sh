#!/usr/bin/env bash
# Lance une commande Flutter dans le conteneur de CI (hors EDR du poste Windows).
# Le poste bloque flutter_tester.exe (EDR) et n'a pas Visual Studio ; ce conteneur
# Linux permet `flutter test` (widgets), `flutter analyze`, `flutter build linux`.
#
# Usage :
#   ./scripts/flutter-ci.sh test
#   ./scripts/flutter-ci.sh analyze
#   ./scripts/flutter-ci.sh build linux --debug
#
# Prérequis : image construite via `docker build -f Dockerfile.flutter-ci -t terebi-ci .`
set -euo pipefail
PROJECT="/c/SAPDevelop/perso/Dashboard-sama-scrapper"
cd "$PROJECT"
# MSYS_NO_PATHCONV évite que Git Bash réécrive les chemins Unix passés à Docker.
MSYS_NO_PATHCONV=1 exec docker run --rm \
  -v "${PROJECT}:/app" -w /app terebi-ci \
  bash -c "flutter pub get >/dev/null 2>&1 && flutter ${*:-test}"
