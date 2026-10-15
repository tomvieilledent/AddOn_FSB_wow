#!/bin/sh
# Lance tous les tests hors jeu depuis la racine du dépôt (luajit par défaut ; LUA=lua5.1 sh tests/run_all.sh).
set -e
cd "$(dirname "$0")/.."
LUA="${LUA:-luajit}"
for f in tests/run.lua tests/sets_group.lua tests/inspector.lua tests/usability.lua tests/roles.lua tests/equipment.lua tests/log.lua tests/fairness.lua tests/locale.lua tests/assets.lua tests/smoke.lua; do "$LUA" "$f"; done
