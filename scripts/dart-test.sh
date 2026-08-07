#!/usr/bin/env bash
# Lance les tests de logique pure. PC perso : `dart` est dans le PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
exec dart test "$@"
