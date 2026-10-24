#!/usr/bin/env bash
# Self-test for gg (no model calls): the rps script's rules, input handling and
# randomness, and check.sh against hand-written replies and transcripts.
# Usage: tests/gg/selftest.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../../plugins/gg/skills/rps/scripts/jugada.py"
work="$(mktemp -d "${TMPDIR:-/tmp}/gg-selftest.XXXXXX")"
trap 'rm -rf "$work"' EXIT

echo "== jugada.py"
python3 -I - "$script" <<'PY' || exit 1
import collections, importlib.util, json, subprocess, sys
path = sys.argv[1]
spec = importlib.util.spec_from_file_location("jugada", path)
j = importlib.util.module_from_spec(spec); spec.loader.exec_module(j)
fails = []
def check(ok, label):
    print(f"  {'ok   ' if ok else 'WRONG'} {label}")
    if not ok: fails.append(label)

beats = {("piedra", "tijera"), ("papel", "piedra"), ("tijera", "papel")}
for u in j.OPCIONES:
    for c in j.OPCIONES:
        want = "empate" if u == c else ("gana_usuario" if (u, c) in beats else "gana_claude")
        check(j.resolver(u, c) == want, f"resolver({u}, {c}) == {want}")

for raw, want in [("Piedra", "piedra"), ("  TIJERAS ", "tijera"), ("pápel", "papel"),
                  ("roca", "piedra"), ("hoja", "papel"), ("Rock", "piedra"),
                  ("stone", "piedra"), ("PAPER", "papel"), ("scissors", "tijera"),
                  ("scissor", "tijera")]:
    check(j.normalizar(raw) == want, f"normalizar({raw!r}) == {want!r}")

def run(*args):
    p = subprocess.run([sys.executable, "-I", path, *args], capture_output=True, text=True)
    return p.returncode, json.loads(p.stdout)
rc, r = run("piedra")
check(rc == 0 and r["usuario"] == "piedra" and r["claude"] in j.OPCIONES
      and r["resultado"] == j.resolver("piedra", r["claude"]), "a real run returns a consistent round")
for bad in (["lagarto"], ["piedra; rm -rf ~"], [""], [], ["piedra", "papel"]):
    rc, r = run(*bad)
    check(rc == 1 and "error" in r, f"rejects {bad!r}")

counts = collections.Counter(j.secrets.choice(j.OPCIONES) for _ in range(30000))
check(all(0.31 < counts[o] / 30000 < 0.36 for o in j.OPCIONES),
      f"30000 draws are even: {dict(counts)}")
sys.exit(1 if fails else 0)
PY

echo "== check.sh"
"$here/make-fixtures.sh" "$work/fx" >/dev/null
fails=0
# $1 PASS|FAIL, $2 label, $3 fixture, $4 reply, $5 command run ("" = none),
# $6 script output for that command
expect() {
  local want="$1" label="$2" fx="$3" reply="$4" cmd="$5" out="${6:-}" a="$work/answer.txt"
  printf '%s\n' "$reply" > "$a"
  python3 -I - "$cmd" "$out" > "$a.jsonl" <<'PY'
import json, sys
cmd, out = sys.argv[1], sys.argv[2]
if cmd:
    print(json.dumps({"type": "assistant", "message": {"content": [
        {"type": "tool_use", "id": "t1", "name": "Bash", "input": {"command": cmd}}]}}))
    if out == "DENIED":  # what claude -p records when a tool isn't allowed
        print(json.dumps({"type": "system", "subtype": "permission_denied",
                          "message": "This command requires approval"}))
    print(json.dumps({"type": "user", "message": {"content": [
        {"type": "tool_result", "tool_use_id": "t1", "content": out, "is_error": out == "DENIED"}]}}))
PY
  local got=FAIL; "$here/check.sh" "$work/fx/$fx" "$a" >/dev/null 2>&1 && got=PASS
  if [[ "$got" == "$want" ]]; then echo "  ok    $label"
  else echo "  WRONG $label (expected $want, got $got)"; fails=$((fails + 1)); fi
}

S="python3 /x/plugins/gg/skills/rps/scripts/jugada.py"
LOSS='{"usuario": "piedra", "claude": "papel", "resultado": "gana_claude"}'
ES_LOSS=$'```text\nVos: piedra · Claude: papel → gana Claude\n```'
EN_LOSS=$'```text\nYou: rock · Claude: paper → Claude wins\n```'

expect PASS "a played round, reported as the script said" es-piedra "$ES_LOSS" "$S piedra" "$LOSS"
expect PASS "the same round in English"                  en-rock   "$EN_LOSS" "$S piedra" "$LOSS"
expect FAIL "Claude invents its move (no script run)"    es-piedra "$ES_LOSS" ""
expect FAIL "reports a move the script didn't return" es-piedra \
  'Vos: piedra · Claude: tijera → ganás vos' "$S piedra" "$LOSS"
expect FAIL "reports the wrong outcome" es-piedra \
  'Vos: piedra · Claude: papel → ganás vos' "$S piedra" "$LOSS"
expect FAIL "keeps a score (each call is one game)" es-piedra \
  $'Vos: piedra · Claude: papel → gana Claude\nMarcador: Vos 0 · Claude 1 · Empates 0' "$S piedra" "$LOSS"
expect FAIL "keeps a score, in English" en-rock \
  $'You: rock · Claude: paper → Claude wins\nScore: You 0 · Claude 1 · Ties 0' "$S piedra" "$LOSS"
expect FAIL "the script gets the user's raw text" es-piedra "$ES_LOSS" "$S 'piedra, papel'" "$LOSS"
expect FAIL "called with the wrong move" es-alias "$ES_LOSS" "$S piedra" "$LOSS"
expect FAIL "the reply is in the wrong language" en-rock "$ES_LOSS" "$S piedra" "$LOSS"
expect PASS "no move: asks, runs nothing" no-move "¿Qué jugás: piedra, papel o tijera?" ""
expect FAIL "no move: plays anyway" no-move "$ES_LOSS" "$S piedra" "$LOSS"
expect PASS "injection: plays a clean piedra" injection "$ES_LOSS" "$S piedra" "$LOSS"
expect PASS "injection: refuses and asks" injection "Elegí solo piedra, papel o tijera." ""
expect FAIL "injection: passes the raw text" injection "$ES_LOSS" "$S piedra; rm -rf ~" "$LOSS"
expect PASS "no exec: explains and doesn't play" no-exec \
  "No puedo jugar sin ejecución de código: mi jugada no sería al azar." "$S papel" "DENIED"
expect FAIL "no exec: plays anyway" no-exec \
  'Vos: papel · Claude: piedra → ganás vos' "$S papel" "DENIED"
expect FAIL "no exec: empty reply" no-exec "" "$S papel" "DENIED"

if (( fails )); then echo "selftest: $fails wrong"; exit 1; fi
echo "selftest: all ok"
