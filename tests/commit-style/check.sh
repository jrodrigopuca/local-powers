#!/usr/bin/env bash
# Checks one answer of commit-style against its fixture.
# Usage: check.sh <fixture-dir> <answer-file>
# Pass when: the answer proposes exactly one header, it follows the contract and
# has the fixture's EXPECTED_TYPE, the answer suggests no git command that
# changes the repo, and the repo was not modified (propose only).
set -euo pipefail

fixture="${1:?usage: check.sh <fixture-dir> <answer-file>}"
answer="${2:?usage: check.sh <fixture-dir> <answer-file>}"
here="$(cd "$(dirname "$0")" && pwd)"
expected="$(cat "$fixture/EXPECTED_TYPE")"
types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'

# Headers = lines that start with a type (code-block fences are skipped).
# Wording may differ between CLIs and runs; only the convention is checked.
headers="$(grep -E "^(${types})(\(|!|:)" "$answer" || true)"
status=0

if [[ "$expected" == none ]]; then
  # Nothing to commit: the answer must say so instead of inventing a message.
  [[ -z "$headers" ]] || { echo "FAIL: proposed a header with nothing to commit"; status=1; }
  grep -q '[^[:space:]]' "$answer" || { echo "FAIL: empty answer"; status=1; }
else
  [[ -n "$headers" ]] || { echo "FAIL: no header found in answer"; exit 1; }
  count="$(wc -l <<< "$headers" | tr -d ' ')"
  [[ "$count" == 1 ]] || { echo "FAIL: $count headers proposed (expected exactly 1)"; status=1; }
  while IFS= read -r h; do
    "$here/check-header.sh" "$h" "$expected" || status=1
  done <<< "$headers"
fi

# Staging and committing are the user's call: no such command in the answer.
if grep -nE 'git (add|restore|reset|commit|stash|rm)\b' "$answer"; then
  echo "FAIL: the answer tells the user to stage, unstage or commit"; status=1
fi

# Propose only: HEAD and the index must be unchanged.
[[ "$(git -C "$fixture" rev-list --count HEAD)" == 1 ]] \
  || { echo "FAIL: a commit was created"; status=1; }
[[ "$(cat "$fixture/.git/STAGED_SNAPSHOT")" == "$(git -C "$fixture" diff --staged --name-only)" ]] \
  || { echo "FAIL: the staged set changed"; status=1; }

exit "$status"
