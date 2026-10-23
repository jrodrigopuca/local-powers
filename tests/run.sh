#!/usr/bin/env bash
# Runs a plugin's test cases through Claude Code and/or Codex.
#
# Usage: tests/run.sh <plugin> [claude|codex|both] [case]
#   cli defaults to both; case (a fixture name) runs only that case.
#
# Each plugin's test folder, tests/<plugin>/, provides:
#   make-fixtures.sh <dir>        builds one throwaway git repo per case
#   prompt.txt                    what is asked in every case
#   check.sh <fixture> <answer>   exits 0 when the answer passes
#
# Every case is one model call per CLI. Codex has no --plugin-dir, so the
# plugin is installed from this repo's marketplace and removed on exit.
#
# Models default to small ones to keep test runs cheap; override per CLI:
#   CLAUDE_MODEL=sonnet tests/run.sh commit-style claude
#   CODEX_MODEL=default tests/run.sh commit-style codex   ("default" = the CLI's configured model)
# The model and tokens of every case are reported at the end of each CLI.
set -euo pipefail

claude_model="${CLAUDE_MODEL:-haiku}"
codex_model="${CODEX_MODEL:-gpt-6-luna}"

plugin="${1:?usage: tests/run.sh <plugin> [claude|codex|both]}"
clis="${2:-both}"
only="${3:-}"
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

# Each runner writes the answer text to $2 and "<model>\t<input>\t<output>" to $2.meta.
run_claude() { # $1 fixture, $2 answer file
  local model_flag=(); [[ "$claude_model" == default ]] || model_flag=(--model "$claude_model")
  # Isolated from the user's setup: no user/project/local settings (their skills,
  # agents, hooks), no MCP servers, no saved session; per-machine sections (cwd,
  # git status) move out of the system prompt so cases share its cache.
  # (--safe-mode is not usable: it also disables --plugin-dir skills.)
  (cd "$1" && claude -p "$prompt" --plugin-dir "$plugin_dir" "${model_flag[@]}" \
    --setting-sources "" --strict-mcp-config --no-session-persistence \
    --exclude-dynamic-system-prompt-sections \
    --allowedTools "Bash(git diff:*)" "Bash(git status:*)" "Bash(git log:*)" "Read" \
    --output-format json < /dev/null > "$2.json" 2> "$2.err") || true
  python3 -I - "$2.json" "$2" <<'PY'
import json, sys
src, answer = sys.argv[1], sys.argv[2]
try:
    r = json.load(open(src))
except ValueError:
    r = {}
open(answer, "w").write(r.get("result", ""))
u = r.get("usage", {})
fresh = u.get("input_tokens", 0) + u.get("cache_creation_input_tokens", 0)
cached = u.get("cache_read_input_tokens", 0)
models = ",".join(r.get("modelUsage", {})) or "?"
cost = r.get("total_cost_usd")
cost = f"{cost:.4f}" if isinstance(cost, (int, float)) else "-"
open(answer + ".meta", "w").write(f"{models}\t{fresh}\t{cached}\t{u.get('output_tokens', 0)}\t{cost}\n")
PY
}

run_codex() { # $1 fixture, $2 answer file
  local model_flag=() model="$codex_model"
  if [[ "$codex_model" == default ]]; then
    model="$(sed -nE 's/^model *= *"(.*)"/\1/p' "$HOME/.codex/config.toml" 2>/dev/null | head -1)"
  else
    model_flag=(-m "$codex_model")
  fi
  codex exec -C "$1" -s read-only "${model_flag[@]}" --json -o "$2" "$prompt" \
    < /dev/null > "$2.log" 2> "$2.err" || true
  python3 -I - "$2.log" "$2" "${model:-?}" <<'PY'
import json, sys
log, answer, model = sys.argv[1:4]
fresh = cached = out = 0
for line in open(log):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get("type") == "turn.completed":
        u = e.get("usage", {})
        c = u.get("cached_input_tokens", 0)  # a subset of input_tokens
        fresh += u.get("input_tokens", 0) - c
        cached += c
        out += u.get("output_tokens", 0)
# Codex does not report cost.
open(answer + ".meta", "w").write(f"{model}\t{fresh}\t{cached}\t{out}\t-\n")
PY
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
  if [[ -n "$only" ]]; then
    [[ -d "$work/$cli/fixtures/$only" ]] || { echo "unknown case: $only"; exit 2; }
    find "$work/$cli/fixtures" -mindepth 1 -maxdepth 1 ! -name "$only" -exec rm -rf {} +
  fi
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

  # Model(s) used and tokens spent by this CLI, summed over its cases.
  cat "$work/$cli/answers"/*.meta 2>/dev/null | awk -F'\t' '
    { models[$1] = 1; f += $2; c += $3; o += $4; if ($5 != "-") { cost += $5; has = 1 } }
    END { m = ""; for (k in models) m = m (m ? ", " : "") k
          printf "  model: %s — tokens: %d new in, %d cached in, %d out", m, f, c, o
          if (has) printf " — cost: US$%.4f", cost
          printf "\n" }'
done

exit "$fail"
