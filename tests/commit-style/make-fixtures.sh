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
  printf '{ "name": "math", "dependencies": { "left-pad": "^1.2.0" } }\n' > package.json
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

big_lockfile() { # a 500-package lockfile: noise the skill must not read in full
  python3 -c 'import json;print(json.dumps({"name":"math","lockfileVersion":3,"packages":{f"node_modules/p{i}":{"version":"1.0.1"} for i in range(500)}},indent=2))' > package-lock.json
}

# fix: a bug fix plus the dependency bump; the type follows the main purpose
base fix-with-lockfile
sed -i.bak 's/return a + b;/return Number(a) + Number(b);/' src/math.js && rm src/math.js.bak
sed -i.bak 's/\^1.2.0/^1.3.0/' package.json && rm package.json.bak
big_lockfile
git add -A && echo fix > EXPECTED_TYPE

# build: only the lockfile changes (tie-breaker: lockfile-only → build, not chore)
base build-lockfile-only
big_lockfile
git add -A && echo build > EXPECTED_TYPE

# nothing staged: the message describes the pending changes
base unstaged-only
printf '\nexport const PI = 3.14159;\n' >> src/math.js
echo feat > EXPECTED_TYPE

# staged wins: a staged docs change plus a pending feature → describe only the docs
base staged-and-pending
printf '\n## Usage\n\nImport `add` from `src/math.js`.\n' >> README.md
git add README.md
printf '\nexport function multiply(a, b) {\n  return a * b;\n}\n' >> src/math.js
echo docs > EXPECTED_TYPE

# nothing at all: say there is nothing to commit, propose no header
base no-changes
echo none > EXPECTED_TYPE

# Snapshot the staged set so check.sh can prove the skill only proposed.
for d in "$out"/*/; do
  git -C "$d" diff --staged --name-only > "$d/.git/STAGED_SNAPSHOT"
done

echo "Fixtures in $out:"; ls "$out"
