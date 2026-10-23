#!/usr/bin/env bash
# Checks one answer of commit-style against its fixture.
# Usage: check.sh <fixture-dir> <answer-file>
# Expectations are read from <fixture>/.git/expected/. Pass when: every header
# follows the contract; the header types match TYPE ("none" = no header); the
# answer suggests no git command that changes the repo; the repo was not
# modified (propose only); and, when the fixture has them:
#   GROUPS    "<type> <path>..." per line: each path is listed between the
#             previous header and the header of that type
#   KEYWORDS  one extended regex per line that the headers must match
#             (case-insensitive)
set -euo pipefail

fixture="${1:?usage: check.sh <fixture-dir> <answer-file>}"
answer="${2:?usage: check.sh <fixture-dir> <answer-file>}"
here="$(cd "$(dirname "$0")" && pwd)"
exp="$fixture/.git/expected"
expected="$(cat "$exp/TYPE")"
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
  # TYPE lists one type per expected header ("feat", or "ci feat" for a split).
  [[ -n "$headers" ]] || { echo "FAIL: no header found in answer"; exit 1; }
  while IFS= read -r h; do
    "$here/check-header.sh" "$h" || status=1
  done <<< "$headers"
  want="$(tr ' ' '\n' <<< "$expected" | sort | xargs)"
  got="$(while IFS= read -r h; do echo "${h%%[(!:]*}"; done <<< "$headers" | sort | xargs)"
  [[ "$got" == "$want" ]] || { echo "FAIL: header types [$got], expected [$want]"; status=1; }
fi

# Each group's files are listed right before its header.
if [[ -f "$exp/GROUPS" ]]; then
  header_lines="$(grep -nE "^(${types})(\(|!|:)" "$answer" | cut -d: -f1 || true)"
  while read -r type paths; do
    [[ -n "$type" ]] || continue
    at="$(grep -nE "^${type}(\(|!|:)" "$answer" | head -1 | cut -d: -f1 || true)"
    [[ -n "$at" ]] || { echo "FAIL: no '$type' header for group: $paths"; status=1; continue; }
    prev="$(awk -v h="$at" '$1 < h' <<< "$header_lines" | tail -1)"
    from=$(( ${prev:-0} + 1 )); to=$(( at - 1 ))
    segment=""; (( to >= from )) && segment="$(sed -n "${from},${to}p" "$answer")"
    for p in $paths; do
      grep -qF -- "$p" <<< "$segment" \
        || { echo "FAIL: '$p' not listed before the '$type' header"; status=1; }
    done
  done < "$exp/GROUPS"
fi

# The headers carry what the fixture says they must name.
if [[ -f "$exp/KEYWORDS" ]]; then
  while IFS= read -r rx; do
    [[ -n "$rx" ]] || continue
    grep -qiE -- "$rx" <<< "$headers" \
      || { echo "FAIL: headers do not match /$rx/"; status=1; }
  done < "$exp/KEYWORDS"
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
