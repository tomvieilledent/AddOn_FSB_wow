#!/bin/sh
# Lance tous les tests hors jeu depuis la racine du dépôt (nécessite luajit).
set -e
cd "$(dirname "$0")/.."
for f in tests/run.lua tests/sets_group.lua tests/inspector.lua tests/usability.lua tests/roles.lua tests/log.lua tests/locale.lua tests/assets.lua tests/smoke.lua; do luajit "$f"; done
