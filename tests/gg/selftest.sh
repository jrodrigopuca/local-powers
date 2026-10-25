#!/usr/bin/env bash
# Runs the self-test of every gg game (tests/gg/<game>/selftest.sh), no model calls.
# Usage: tests/gg/selftest.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
status=0
for t in "$here"/*/selftest.sh; do
  [[ -e "$t" ]] || continue
  echo "##### $(basename "$(dirname "$t")")"
  "$t" || status=1
done
exit "$status"
