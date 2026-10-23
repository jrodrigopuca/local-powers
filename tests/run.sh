#!/usr/bin/env bash
# Runs a plugin's test cases through Claude Code and/or Codex.
#
# Usage: tests/run.sh <plugin> [claude|codex|both]   (default: both)
#
# Each plugin's test folder, tests/<plugin>/, provides:
#   make-fixtures.sh <dir>        builds one throwaway git repo per case
#   prompt.txt                    what is asked in every case
#   check.sh <fixture> <answer>   exits 0 when the answer passes
#
# Every case is one model call per CLI. Codex has no --plugin-dir, so the
# plugin is installed from this repo's marketplace and removed on exit.
set -euo pipefail

plugin="${1:?usage: tests/run.sh <plugin> [claude|codex|both]}"
clis="${2:-both}"
root="$(cd "$(dirname "$0")/.." && pwd)"
suite="$root/tests/$plugin"
plugin_dir="$root/plugins/$plugin"
marketplace="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["name"])' "$root/.claude-plugin/marketplace.json")"

[[ -d "$plugin_dir" && -d "$suite" ]] || { echo "unknown plugin: $plugin"; exit 2; }
case "$clis" in claude) clis=(claude);; codex) clis=(codex);; both) clis=(claude codex);;
  *) echo "cli must be claude, codex or both"; exit 2;; esac

work="$(mktemp -d "${TMPDIR:-/tmp}/local-powers-$plugin.XXXXXX")"
prompt="$(cat "$suite/prompt.txt")"
echo "Work dir: $work"

codex_installed=no
cleanup() {
  if [[ "$codex_installed" == yes ]]; then
    codex plugin remove "$plugin@$marketplace" >/dev/null 2>&1 || true
    codex plugin marketplace remove "$marketplace" >/dev/null 2>&1 || true
    rmdir "$HOME/.codex/plugins/cache/$marketplace" 2>/dev/null || true
  fi
}
trap cleanup EXIT

run_claude() { # $1 fixture, $2 answer file
  (cd "$1" && claude -p "$prompt" --plugin-dir "$plugin_dir" \
    --allowedTools "Bash(git diff:*)" "Bash(git status:*)" "Bash(git log:*)" "Read" \
    < /dev/null > "$2" 2> "$2.err")
}

run_codex() { # $1 fixture, $2 answer file
  codex exec -C "$1" -s read-only -o "$2" "$prompt" < /dev/null > "$2.log" 2>&1
}

fail=0
for cli in "${clis[@]}"; do
  if [[ "$cli" == codex ]]; then
    if codex plugin marketplace list 2>/dev/null | grep -q "^$marketplace "; then
      echo "Codex already has a '$marketplace' marketplace; refusing to touch it."; exit 2
    fi
    codex plugin marketplace add "$root" >/dev/null
    codex_installed=yes
    codex plugin add "$plugin@$marketplace" >/dev/null
  fi

  # Fresh fixtures per CLI, so one CLI can't affect the other's cases.
  "$suite/make-fixtures.sh" "$work/$cli/fixtures" >/dev/null
  mkdir -p "$work/$cli/answers"

  pids=()
  for fixture in "$work/$cli/fixtures"/*/; do
    case_name="$(basename "$fixture")"
    "run_$cli" "$fixture" "$work/$cli/answers/$case_name.txt" & pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p" || true; done

  echo "== $cli"
  for fixture in "$work/$cli/fixtures"/*/; do
    case_name="$(basename "$fixture")"
    if out="$("$suite/check.sh" "$fixture" "$work/$cli/answers/$case_name.txt" 2>&1)"; then
      echo "  PASS  $case_name"
    else
      echo "  FAIL  $case_name"; sed 's/^/        /' <<< "$out"; fail=1
    fi
  done
done

exit "$fail"
