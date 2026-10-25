#!/usr/bin/env bash
# Runs a plugin's test cases through Claude Code.
#
# Usage: tests/run.sh <plugin> [case]
#   case (a fixture name, or the prefix of several) runs only those cases.
#
# Each plugin's test folder, tests/<plugin>/, provides:
#   make-fixtures.sh <dir>        builds one throwaway git repo per case
#   prompt.txt                    what is asked in every case
#   allowed-tools                 the tools Claude may use, one per line;
#                                 {plugin_dir} is replaced by the plugin's path
#   check.sh <fixture> <answer>   exits 0 when the answer passes; the session's
#                                 transcript (stream-json) is at <answer>.jsonl
# A case can override the first two in its .git/expected/: PROMPT, and TOOLS
# (an empty TOOLS file means no tools at all).
#
# Every case is one model call. The model defaults to a small one to keep runs
# cheap; override it with CLAUDE_MODEL (an alias or a model id):
#   CLAUDE_MODEL=opus tests/run.sh commit-style
# "default" means Claude Code's built-in default, not the model in the user's
# settings: runs use --setting-sources "", so those settings are never read.
# The model, tokens and cost are reported at the end.
#
# (Codex support was removed in ADR-0002; docs/adr/0002-claude-only.md says how
# to bring it back.)
set -euo pipefail

claude_model="${CLAUDE_MODEL:-haiku}"

plugin="${1:?usage: tests/run.sh <plugin> [case]}"
only="${2:-}"
root="$(cd "$(dirname "$0")/.." && pwd)"
suite="$root/tests/$plugin"
plugin_dir="$root/plugins/$plugin"

[[ -d "$plugin_dir" && -d "$suite" ]] || { echo "unknown plugin: $plugin"; exit 2; }

work="$(mktemp -d "${TMPDIR:-/tmp}/local-powers-$plugin.XXXXXX")"
echo "Work dir: $work"

cleanup() {
  # Claude still creates an empty memory/ folder per fixture under
  # ~/.claude/projects; remove this run's folders, and only while they are empty.
  local tag; tag="$(basename "$work" | tr '.' '-')"
  find "$HOME/.claude/projects" -maxdepth 1 -type d -name "*${tag}-claude-fixtures-*" \
    -exec find {} -depth -type d -empty -delete \; 2>/dev/null || true
}
trap cleanup EXIT

# Writes the answer text to $2, the transcript to $2.jsonl, and
# "<model>\t<new in>\t<cached in>\t<out>\t<cost>" to $2.meta.
run_claude() { # $1 fixture, $2 answer file
  local model_flag=(); [[ "$claude_model" == default ]] || model_flag=(--model "$claude_model")
  local prompt tools_file tools=()
  if [[ -f "$1/.git/expected/PROMPT" ]]; then prompt="$(cat "$1/.git/expected/PROMPT")"
  else prompt="$(cat "$suite/prompt.txt")"; fi
  tools_file="$suite/allowed-tools"
  [[ -f "$1/.git/expected/TOOLS" ]] && tools_file="$1/.git/expected/TOOLS"
  while IFS= read -r t; do
    [[ -n "$t" ]] && tools+=("${t//\{plugin_dir\}/$plugin_dir}")
  done < "$tools_file"
  # Isolated from the user's setup: no user/project/local settings (their skills,
  # agents, hooks), no MCP servers, no saved session; per-machine sections (cwd,
  # git status) move out of the system prompt so cases share its cache.
  # (--safe-mode is not usable: it also disables --plugin-dir skills.)
  local tool_flag=(); [[ ${#tools[@]} -gt 0 ]] && tool_flag=(--allowedTools "${tools[@]}")
  # ${a[@]+"${a[@]}"}: expands an empty array to nothing under set -u on bash 3.2 (macOS)
  (cd "$1" && claude -p "$prompt" --plugin-dir "$plugin_dir" ${model_flag[@]+"${model_flag[@]}"} \
    --setting-sources "" --strict-mcp-config --no-session-persistence \
    --exclude-dynamic-system-prompt-sections \
    ${tool_flag[@]+"${tool_flag[@]}"} \
    --output-format stream-json --verbose < /dev/null > "$2.jsonl" 2> "$2.err") || true
  python3 -I - "$2.jsonl" "$2" <<'PY'
import json, sys
src, answer = sys.argv[1], sys.argv[2]
r = {}
for line in open(src):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get("type") == "result":
        r = e
open(answer, "w").write(r.get("result") or "")
u = r.get("usage", {})
fresh = u.get("input_tokens", 0) + u.get("cache_creation_input_tokens", 0)
cached = u.get("cache_read_input_tokens", 0)
models = ",".join(r.get("modelUsage", {})) or "?"
cost = r.get("total_cost_usd")
cost = f"{cost:.4f}" if isinstance(cost, (int, float)) else "-"
open(answer + ".meta", "w").write(f"{models}\t{fresh}\t{cached}\t{u.get('output_tokens', 0)}\t{cost}\n")
PY
}

fixtures="$work/claude/fixtures"
answers="$work/claude/answers"
"$suite/make-fixtures.sh" "$fixtures" >/dev/null
if [[ -n "$only" ]]; then
  # A case name, or the prefix of several: "rps" keeps every rps-… case.
  find "$fixtures" -mindepth 1 -maxdepth 1 ! \( -name "$only" -o -name "$only-*" \) -exec rm -rf {} +
  [[ -n "$(ls -A "$fixtures")" ]] || { echo "unknown case: $only"; exit 2; }
fi
mkdir -p "$answers"

pids=()
for fixture in "$fixtures"/*/; do
  run_claude "$fixture" "$answers/$(basename "$fixture").txt" & pids+=($!)
done
for p in "${pids[@]}"; do wait "$p" || true; done

fail=0
for fixture in "$fixtures"/*/; do
  case_name="$(basename "$fixture")"
  if out="$("$suite/check.sh" "$fixture" "$answers/$case_name.txt" 2>&1)"; then
    echo "  PASS  $case_name"
  else
    echo "  FAIL  $case_name"; sed 's/^/        /' <<< "$out"; fail=1
  fi
done

# Model(s) used, tokens and cost, summed over the cases.
cat "$answers"/*.meta 2>/dev/null | awk -F'\t' '
  { models[$1] = 1; f += $2; c += $3; o += $4; if ($5 != "-") { cost += $5; has = 1 } }
  END { m = ""; for (k in models) m = m (m ? ", " : "") k
        printf "  model: %s — tokens: %d new in, %d cached in, %d out", m, f, c, o
        if (has) printf " — cost: US$%.4f", cost
        printf "\n" }'

exit "$fail"
