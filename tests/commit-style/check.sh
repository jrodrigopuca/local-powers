#!/usr/bin/env bash
# Checks one answer of commit-style against its fixture.
# Usage: check.sh <fixture-dir> <answer-file>
# Pass when: every proposed header follows the contract, at least one header has
# the fixture's EXPECTED_TYPE, and the repo was not modified (propose only).
set -euo pipefail

fixture="${1:?usage: check.sh <fixture-dir> <answer-file>}"
answer="${2:?usage: check.sh <fixture-dir> <answer-file>}"
here="$(cd "$(dirname "$0")" && pwd)"
expected="$(cat "$fixture/EXPECTED_TYPE")"
types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'

# Headers = lines that start with a type (code-block fences are skipped).
headers="$(grep -E "^(${types})(\(|!|:)" "$answer" || true)"
[[ -n "$headers" ]] || { echo "FAIL: no header found in answer"; exit 1; }

status=0; matched=no
while IFS= read -r h; do
  "$here/check-header.sh" "$h" || status=1
  [[ "${h%%[(!:]*}" == "$expected" ]] && matched=yes
done <<< "$headers"

[[ "$matched" == yes ]] || { echo "FAIL: no header of type '$expected'"; status=1; }

# Propose only: HEAD and the index must be unchanged.
[[ "$(git -C "$fixture" rev-list --count HEAD)" == 1 ]] \
  || { echo "FAIL: a commit was created"; status=1; }
[[ "$(cat "$fixture/.git/STAGED_SNAPSHOT")" == "$(git -C "$fixture" diff --staged --name-only)" ]] \
  || { echo "FAIL: the staged set changed"; status=1; }

exit "$status"
