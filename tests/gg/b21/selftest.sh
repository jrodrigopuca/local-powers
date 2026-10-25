#!/usr/bin/env bash
# Self-test for the b21 game (no model calls): the engine's rules, the exact
# approved text, the shuffle, and the independent verifier (it must accept what
# the engine writes and reject every kind of mistake). Usage: tests/gg/b21/selftest.sh
set -euo pipefail
exec python3 -I "$(cd "$(dirname "$0")" && pwd)/selftest.py"
