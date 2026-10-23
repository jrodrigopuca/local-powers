#!/usr/bin/env bash
# Self-test of the commit-style checkers (no model calls): feeds hand-written
# answers to check.sh / check-header.sh and asserts which pass and which fail.
# Usage: tests/commit-style/selftest.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/commit-style-selftest.XXXXXX")"
trap 'rm -rf "$work"' EXIT
"$here/make-fixtures.sh" "$work/fx" >/dev/null

fails=0
expect() { # $1 PASS|FAIL, $2 label, rest = command
  local want="$1" label="$2"; shift 2
  local got=FAIL; "$@" >/dev/null 2>&1 && got=PASS
  if [[ "$got" == "$want" ]]; then echo "  ok    $label"
  else echo "  WRONG $label (expected $want, got $got)"; fails=$((fails + 1)); fi
}
answer() { # $1 fixture, $2 answer text
  printf '%s\n' "$2" > "$work/answer.txt"
  "$here/check.sh" "$work/fx/$1" "$work/answer.txt"
}

echo "== check-header.sh"
h="$here/check-header.sh"
expect PASS "scoped feat"                 "$h" "feat(commit-style): add header length check"
expect PASS "breaking change with !"      "$h" "fix!: drop legacy flag"
expect PASS "one-character description"   "$h" "docs: x"
expect FAIL "no type"                     "$h" "Added stuff"
expect FAIL "trailing period"             "$h" "feat: ends with period."
expect FAIL "description is only a dot"   "$h" "feat: ."
expect FAIL "double space after colon"    "$h" "feat:  leading space"
expect FAIL "over 72 characters"          "$h" "feat(api): $(printf 'x%.0s' {1..70})"
expect FAIL "type differs from expected"  "$h" "fix: handle numeric strings" feat

echo "== check.sh"
expect PASS "one correct header" \
  answer docs-only $'```text\ndocs: add usage section\n```\nOnly README changed.'
expect FAIL "wrong type" \
  answer docs-only $'```text\nfeat: add usage section\n```'
expect FAIL "header as a shell comment" \
  answer fix-with-lockfile $'```sh\ngit add src/math.js\n# fix: convert inputs\n```'
expect FAIL "suggests git add" \
  answer unstaged-only $'```sh\ngit add src/math.js\n```\n```text\nfeat: export PI\n```'
expect PASS "pending changes, one purpose" \
  answer unstaged-only $'```text\nfeat: export PI\n```'
expect PASS "staged wins, note without commands" \
  answer staged-and-pending $'```text\ndocs: add usage section\n```\nThere is also an unrelated pending change in src.'
expect PASS "mixed staged set names both changes" \
  answer mixed-staged $'```text\nfeat(math): add multiply and coerce add operands\n```'
expect FAIL "mixed staged set names only one" \
  answer mixed-staged $'```text\nfeat(math): add multiply function\n```'
expect FAIL "mixed staged set split in two" \
  answer mixed-staged $'```text\nfeat: add multiply\n```\n```text\nfix: coerce add operands\n```'
expect PASS "unstaged split, files before each header" \
  answer unstaged-mixed $'`src/math.js`:\n```text\nfeat(math): add multiply function\n```\n`.github/workflows/test.yml`:\n```text\nci: run tests on push\n```'
expect FAIL "unstaged split, files listed at the end" \
  answer unstaged-mixed $'```text\nfeat(math): add multiply function\n```\n```text\nci: run tests on push\n```\nFiles: src/math.js, .github/'
expect FAIL "unstaged split, files crossed" \
  answer unstaged-mixed $'`.github/workflows/test.yml`:\n```text\nfeat(math): add multiply function\n```\n`src/math.js`:\n```text\nci: run tests on push\n```'
expect FAIL "unstaged mixed in one header" \
  answer unstaged-mixed $'```text\nfeat: add multiply and ci workflow\n```'
expect PASS "no changes, says so" \
  answer no-changes "There are no changes to commit."
expect FAIL "no changes, invents a header" \
  answer no-changes $'```text\nchore: update files\n```'
expect FAIL "no changes, empty answer" \
  answer no-changes ""

# Last: these modify their fixture.
git -C "$work/fx/test-only" commit -qm "test: x"
expect FAIL "a commit was created" \
  answer test-only $'```text\ntest: cover negative operands\n```'
git -C "$work/fx/feat-export" reset -q
expect FAIL "the staged set changed" \
  answer feat-export $'```text\nfeat: add multiply function\n```'

if (( fails )); then echo "selftest: $fails wrong"; exit 1; fi
echo "selftest: all ok"
