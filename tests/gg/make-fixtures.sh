#!/usr/bin/env bash
# Builds the test fixtures of every gg game into one folder. Each game's own
# make-fixtures.sh (tests/gg/<game>/) makes its cases; here they are renamed
# <game>-<case> and the game is recorded in each fixture's .git/expected/GAME,
# which tests/gg/check.sh uses to pick the game's checker.
# Usage: make-fixtures.sh <output-dir>
set -euo pipefail

out="${1:?usage: make-fixtures.sh <output-dir>}"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/gg-fixtures.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

for gamedir in "$here"/*/; do
  game="$(basename "$gamedir")"
  [[ -x "$gamedir/make-fixtures.sh" ]] || continue
  mkdir -p "$tmp/$game"
  "$gamedir/make-fixtures.sh" "$tmp/$game" >/dev/null
  for fx in "$tmp/$game"/*/; do
    name="$game-$(basename "$fx")"
    rm -rf "$out/$name"
    mv "$fx" "$out/$name"
    printf '%s\n' "$game" > "$out/$name/.git/expected/GAME"
  done
done

echo "Fixtures in $out:"; ls "$out"
