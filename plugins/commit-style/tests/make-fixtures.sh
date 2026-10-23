#!/usr/bin/env bash
# Builds throwaway git repos whose staged change has an unambiguous type.
# Usage: make-fixtures.sh <output-dir>
# Each fixture dir contains EXPECTED_TYPE (git-ignored via .git/info/exclude).
set -euo pipefail

out="${1:?usage: make-fixtures.sh <output-dir>}"
mkdir -p "$out"

base() { # $1 = fixture name; creates a repo with one initial commit
  local dir="$out/$1"
  rm -rf "$dir" && mkdir -p "$dir" && cd "$dir"
  git init -q
  git config user.name fixture && git config user.email fixture@example.com
  echo "EXPECTED_TYPE" >> .git/info/exclude
  mkdir -p src test
  printf 'export function add(a, b) {\n  return a + b;\n}\n' > src/math.js
  printf 'import { add } from "../src/math.js";\nconsole.assert(add(1, 2) === 3);\n' > test/math.test.js
  printf '# Math\n\nTiny math helpers.\n' > README.md
  printf '{ "name": "math", "lockfileVersion": 3, "packages": {} }\n' > package-lock.json
  git add -A && git commit -qm "chore: initial commit"
}

# docs: only the README changes
base docs-only
printf '\n## Usage\n\nImport `add` from `src/math.js`.\n' >> README.md
git add README.md && echo docs > EXPECTED_TYPE

# test: only a test changes
base test-only
printf 'console.assert(add(-1, 1) === 0);\n' >> test/math.test.js
git add test && echo test > EXPECTED_TYPE

# feat: a new exported function
base feat-export
printf '\nexport function multiply(a, b) {\n  return a * b;\n}\n' >> src/math.js
git add src && echo feat > EXPECTED_TYPE

# fix: a bug fix, plus a noisy lockfile that must be ignored
base fix-with-lockfile
sed -i.bak 's/return a + b;/return Number(a) + Number(b);/' src/math.js && rm src/math.js.bak
python3 -c 'import json;print(json.dumps({"name":"math","lockfileVersion":3,"packages":{f"node_modules/p{i}":{"version":"1.0.0"} for i in range(500)}},indent=2))' > package-lock.json
git add -A && echo fix > EXPECTED_TYPE

# nothing staged: must suggest a git add, not invent a commit
base unstaged-only
printf '\nexport const PI = 3.14159;\n' >> src/math.js
echo feat > EXPECTED_TYPE

echo "Fixtures in $out:"; ls "$out"
