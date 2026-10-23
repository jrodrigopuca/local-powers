#!/usr/bin/env bash
# Checks that a proposed commit header follows commit-style's contract:
#   <type>[(scope)][!]: <description>   — one line, max 72 characters.
# Usage: check-header.sh "<header>" [expected-type]
set -euo pipefail

header="${1:?usage: check-header.sh \"<header>\" [expected-type]}"
expected="${2:-}"
types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
pattern="^(${types})(\([a-z0-9][a-z0-9-]*\))?!?: [^ ].*[^.]$"

fail() { echo "FAIL: $1 — '$header'"; exit 1; }

[[ "$header" != *$'\n'* ]] || fail "more than one line"
(( ${#header} <= 72 )) || fail "${#header} chars (max 72)"
[[ "$header" =~ $pattern ]] || fail "not <type>[(scope)][!]: <description>"

if [[ -n "$expected" ]]; then
  actual="${header%%[(!:]*}"
  [[ "$actual" == "$expected" ]] || fail "type '$actual', expected '$expected'"
fi

echo "PASS: $header"
