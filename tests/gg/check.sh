#!/usr/bin/env bash
# Checks one rps answer against its fixture, using the session transcript
# (<answer>.jsonl, stream-json) to see whether and how Claude ran the script.
# Usage: check.sh <fixture-dir> <answer-file>
#
# A played round passes when: the script ran exactly once, as
# `python3 <path>/jugada.py <piedra|papel|tijera>` with the expected move and
# nothing else on the line; and the whole reply is exactly the reply the script
# wrote for its language (respuesta.es / respuesta.en) — nothing added before
# or after, no spacing changed.
# A case that must not be played passes when no result was reported (and, for
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

# --- what the reply reports. The script writes the whole reply (respuesta.es /
# respuesta.en); Claude must copy it exactly. Before comparing: \r\n → \n, NFC,
# and U+FE0F (the emoji presentation selector in ✌️) dropped — copying text may
# lose it and it renders the same; whitespace is trimmed only at the two ends,
# so a collapsed space inside the table still fails.
import unicodedata
def same(s):
    s = unicodedata.normalize("NFC", s.replace("\r\n", "\n")).replace("️", "")
    return s.strip()

reply = same(text)
# Any sign that a result was shown: a result title, or a table row.
result_shown = re.search(r"^#+ *(🎉|🤖|🤝)|^(Vos|Yo|You|Me) +(piedra|papel|tijera|rock|paper|scissors)\b",
                         reply, re.M)

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
    want = same((r.get("respuesta") or {}).get(lang, ""))
    if not want:
        fails.append(f"the script returned no respuesta.{lang}")
    elif reply != want:
        fails.append(f"the reply is not the script's respuesta.{lang}:\n"
                     f"--- reply\n{reply}\n--- expected\n{want}")

def not_played(may_call):
    if not may_call and calls:
        fails.append(f"the script ran {len(calls)} times (expected none)")
    if result_shown:
        fails.append("the reply shows a result although none could be played")
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
