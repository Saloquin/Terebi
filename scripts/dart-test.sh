#!/usr/bin/env bash
# Lance les tests de logique pure via `dart test` (flutter_tester.exe est bloqué par l'EDR,
# donc `flutter test` est inutilisable — voir docs/BACKLOG.md §0.7).
# Usage : ./scripts/dart-test.sh [chemin/vers/test.dart]  (par défaut : tout test/)
set -euo pipefail
DART="C:/SAPDevelop/flutter/bin/cache/dart-sdk/bin/dart.exe"
cd "$(dirname "$0")/.."
exec cmd.exe //c "${DART//\//\\} test ${*:-}"
