#!/usr/bin/env bash
# Structural checks for the whole repository. No model calls, no network.
# Usage: scripts/check.sh
#
#   1. JSON files parse
#   2. Each plugin has .claude-plugin/plugin.json, named after its folder
#      (Claude Code only: ADR-0002)
#   3. Every plugin is listed in the marketplace, with the right source
#   4. Every skill has a SKILL.md whose frontmatter name matches its folder
#      and that has a description
#   5. No tests inside plugin folders (they would be installed with the plugin)
#   6. Shell scripts parse
#   7. claude plugin validate --strict, when the claude CLI is installed
#   8. Each plugin's checker self-test (tests/<plugin>/selftest.sh)
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
fails=0
fail() { echo "  FAIL  $*"; fails=$((fails + 1)); }
ok()   { echo "  ok    $*"; }

echo "== manifests, marketplace and skills"
python3 -I - "$root" <<'PY' || fails=$((fails + 1))
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
errors = []

def load(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as e:
        errors.append(f"{path.relative_to(root)}: {e}")
        return None

market = load(root / ".claude-plugin/marketplace.json") or {}
entries = {p.get("name"): p for p in market.get("plugins", [])}

for plugin in sorted((root / "plugins").iterdir()):
    if not plugin.is_dir():
        continue
    name = plugin.name
    claude = load(plugin / ".claude-plugin/plugin.json")
    if claude is None:
        continue
    if claude.get("name") != name:
        errors.append(f"{name}: folder name differs from manifest name {claude.get('name')!r}")
    entry = entries.get(name)
    if entry is None:
        errors.append(f"{name}: not listed in .claude-plugin/marketplace.json")
    elif entry.get("source") != f"./plugins/{name}":
        errors.append(f"{name}: marketplace source is {entry.get('source')!r}")
    if (plugin / "tests").exists():
        errors.append(f"{name}: has a tests/ folder; move it to tests/{name}/")
    for skill in sorted((plugin / "skills").glob("*/")):
        md = skill / "SKILL.md"
        if not md.is_file():
            errors.append(f"{name}: {skill.name}/ has no SKILL.md")
            continue
        m = re.match(r"^---\n(.*?)\n---\n", md.read_text(), re.S)
        front = dict(re.findall(r"^(\w+):\s*(.+)$", m.group(1), re.M)) if m else {}
        if front.get("name") != skill.name:
            errors.append(f"{name}: skill folder {skill.name}/ has frontmatter name {front.get('name')!r}")
        if not front.get("description"):
            errors.append(f"{name}: skill {skill.name} has no description")

for missing in set(entries) - {p.name for p in (root / "plugins").iterdir() if p.is_dir()}:
    errors.append(f"marketplace lists {missing!r}, which has no plugins/{missing}/ folder")

for e in errors:
    print(f"  FAIL  {e}")
if not errors:
    print("  ok    manifests named after their folders, marketplace complete, skills named after their folders")
sys.exit(1 if errors else 0)
PY

echo "== shell scripts parse"
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null && ok "$f" || fail "$f does not parse"
done < <(git ls-files '*.sh')

echo "== claude plugin validate --strict"
if command -v claude >/dev/null; then
  for target in . plugins/*/; do
    out="$(claude plugin validate --strict "$target" 2>&1)" \
      && ok "${target%/}" || { fail "${target%/}"; sed 's/^/        /' <<< "$out"; }
  done
else
  echo "  skip  claude CLI not installed"
fi

echo "== checker self-tests"
for t in tests/*/selftest.sh; do
  [[ -e "$t" ]] || continue
  if out="$("$t" 2>&1)"; then ok "$t"
  else fail "$t"; grep -E 'WRONG|selftest:' <<< "$out" | sed 's/^/        /'; fi
done

echo
if (( fails )); then echo "check: $fails failed"; exit 1; fi
echo "check: all ok"
