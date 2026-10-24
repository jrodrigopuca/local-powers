#!/usr/bin/env bash
# Checks one rps answer against its fixture, using the session transcript
# (<answer>.jsonl, stream-json) to see whether and how Claude ran the script.
# Usage: check.sh <fixture-dir> <answer-file>
#
# A played round passes when: the script ran exactly once, as
# `python3 <path>/jugada.py <piedra|papel|tijera>` with the expected move and
# nothing else on the line; the reply's round line is exactly the line the
# script wrote for the reply's language (linea.es / linea.en); and there is no
# score line (each call is one complete game, nothing is carried over).
# A case that must not be played passes when no round was reported (and, for
# "none", the script never ran) and the reply is not empty.
set -euo pipefail

fixture="${1:?usage: check.sh <fixture-dir> <answer-file>}"
answer="${2:?usage: check.sh <fixture-dir> <answer-file>}"

python3 -I - "$fixture/.git/expected" "$answer" "$answer.jsonl" <<'PY'
import json, re, sys
from pathlib import Path

exp, answer, transcript = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
arg = (exp / "ARG").read_text().strip()
lang = (exp / "LANG").read_text().strip()
text = answer.read_text() if answer.exists() else ""
fails = []

# --- what the transcript says Claude ran, and what the script returned
uses, results = {}, {}
if transcript.exists():
    for line in transcript.read_text().splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        message = e.get("message")
        if not isinstance(message, dict):  # e.g. system/permission_denied carries a string
            continue
        for block in message.get("content") or []:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use" and block.get("name") == "Bash":
                uses[block["id"]] = block.get("input", {}).get("command", "")
            if block.get("type") == "tool_result":
                c = block.get("content")
                if isinstance(c, list):
                    c = "".join(x.get("text", "") for x in c if isinstance(x, dict))
                results[block.get("tool_use_id")] = (c or "", bool(block.get("is_error")))
calls = [(i, cmd) for i, cmd in uses.items() if "jugada.py" in cmd]

def outcome(i):
    out, is_error = results.get(i, ("", True))
    if is_error:
        return None
    try:
        r = json.loads(out.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return None
    return r if "claude" in r else None

# --- what the reply reports. The script writes the line (linea.es / linea.en);
# Claude must copy it exactly. U+FE0F (the emoji presentation selector in ✌️)
# is ignored in comparisons: copying text may drop it and it renders the same.
def same(s):
    return s.replace("️", "").strip()

round_re = re.compile(r"^(Vos|You): ")
score_re = re.compile(r"^(Marcador|Score)\b", re.I)
lines = [same(l) for l in text.splitlines()]
rounds = [l for l in lines if round_re.match(l)]
scores = [l for l in lines if score_re.match(l)]

CLEAN = re.compile(r"^python3 \S*/?jugada\.py (piedra|papel|tijera)$")

def played(move):
    if len(calls) != 1:
        fails.append(f"the script ran {len(calls)} times (expected once)")
        return
    i, cmd = calls[0]
    m = CLEAN.match(cmd.strip())
    if not m:
        fails.append(f"unexpected command: {cmd!r}")
        return
    if m.group(1) != move:
        fails.append(f"script called with {m.group(1)!r}, expected {move!r}")
    r = outcome(i)
    if r is None:
        fails.append("the script returned no result")
        return
    if len(rounds) != 1:
        fails.append(f"{len(rounds)} round lines in the reply (expected 1)")
        return
    want = same((r.get("linea") or {}).get(lang, ""))
    if rounds[0] != want:
        fails.append(f"reply line {rounds[0]!r} is not the script's linea.{lang} {want!r}")
    if scores:
        fails.append("the reply keeps a score; each call is a single game")

def not_played(may_call):
    if not may_call and calls:
        fails.append(f"the script ran {len(calls)} times (expected none)")
    if rounds or scores:
        fails.append("the reply reports a round although none could be played")
    if not text.strip():
        fails.append("empty reply")

if arg in ("piedra", "papel", "tijera"):
    played(arg)
elif arg == "none":
    not_played(may_call=False)
elif arg == "piedra-or-none":
    if calls:
        played("piedra")
    else:
        not_played(may_call=False)
elif arg == "denied":
    if any(outcome(i) for i, _ in calls):
        fails.append("the script ran although no tools were allowed")
    not_played(may_call=True)
else:
    fails.append(f"unknown ARG {arg!r}")

for f in fails:
    print(f"FAIL: {f}")
sys.exit(1 if fails else 0)
PY
