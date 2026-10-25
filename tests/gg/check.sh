#!/usr/bin/env bash
# Sends one gg answer to the checker of its game; the fixture says which game in
# .git/expected/GAME. Each game's checker (tests/gg/<game>/check.sh) takes the
# same arguments and finds the session transcript at <answer-file>.jsonl.
# Usage: check.sh <fixture-dir> <answer-file>
set -euo pipefail

fixture="${1:?usage: check.sh <fixture-dir> <answer-file>}"
answer="${2:?usage: check.sh <fixture-dir> <answer-file>}"
here="$(cd "$(dirname "$0")" && pwd)"

game="$(cat "$fixture/.git/expected/GAME" 2>/dev/null || true)"
if [[ ! "$game" =~ ^[a-z0-9-]+$ || ! -x "$here/$game/check.sh" ]]; then
  echo "FAIL: the fixture names no known game (GAME='$game')"; exit 1
fi
exec "$here/$game/check.sh" "$fixture" "$answer"
