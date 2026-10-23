#!/usr/bin/env bash
# Builds one throwaway git repo per test case.
# Usage: make-fixtures.sh <output-dir>
# Expectations live in <fixture>/.git/expected/ (TYPE, GROUPS, KEYWORDS), out of
# the working tree, so the model under test does not see them; check.sh reads them.
set -euo pipefail

out="${1:?usage: make-fixtures.sh <output-dir>}"
mkdir -p "$out"

base() { # $1 = fixture name; creates a repo with one initial commit
  local dir="$out/$1"
  rm -rf "$dir" && mkdir -p "$dir" && cd "$dir"
  git init -q
  git config user.name fixture && git config user.email fixture@example.com
  mkdir -p src test .git/expected
  printf 'export function add(a, b) {\n  return a + b;\n}\n' > src/math.js
  printf 'import { add } from "../src/math.js";\nconsole.assert(add(1, 2) === 3);\n' > test/math.test.js
  printf '# Math\n\nTiny math helpers.\n' > README.md
  printf '{ "name": "math", "dependencies": { "left-pad": "^1.2.0" } }\n' > package.json
  printf '{ "name": "math", "lockfileVersion": 3, "packages": {} }\n' > package-lock.json
  git add -A && git commit -qm "chore: initial commit"
}

expect() { # $1 = TYPE | GROUPS | KEYWORDS, rest = lines
  local kind="$1"; shift
  printf '%s\n' "$@" > ".git/expected/$kind"
}

big_lockfile() { # a 500-package lockfile: noise the skill must not read in full
  python3 -c 'import json;print(json.dumps({"name":"math","lockfileVersion":3,"packages":{f"node_modules/p{i}":{"version":"1.0.1"} for i in range(500)}},indent=2))' > package-lock.json
}

# docs: only the README changes
base docs-only
printf '\n## Usage\n\nImport `add` from `src/math.js`.\n' >> README.md
git add README.md
expect TYPE docs

# test: only a test changes
base test-only
printf 'console.assert(add(-1, 1) === 0);\n' >> test/math.test.js
git add test
expect TYPE test

# feat: a new exported function
base feat-export
printf '\nexport function multiply(a, b) {\n  return a * b;\n}\n' >> src/math.js
git add src
expect TYPE feat

# fix: a bug fix plus the dependency bump; the type follows the main purpose
base fix-with-lockfile
sed -i.bak 's/return a + b;/return Number(a) + Number(b);/' src/math.js && rm src/math.js.bak
sed -i.bak 's/\^1.2.0/^1.3.0/' package.json && rm package.json.bak
big_lockfile
git add -A
expect TYPE fix

# build: only the lockfile changes (tie-breaker: lockfile-only → build, not chore)
base build-lockfile-only
big_lockfile
git add -A
expect TYPE build

# nothing staged: the message describes the pending changes
base unstaged-only
printf '\nexport const PI = 3.14159;\n' >> src/math.js
expect TYPE feat

# nothing staged, two unrelated purposes: a split, each group with its files
base unstaged-mixed
printf '\nexport function multiply(a, b) {\n  return a * b;\n}\n' >> src/math.js
mkdir -p .github/workflows
printf 'name: test\non: [push]\njobs:\n  test:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - run: node test/math.test.js\n' > .github/workflows/test.yml
expect TYPE "ci feat"
expect GROUPS "feat src/math.js" "ci .github/"

# staged wins: a staged docs change plus a pending feature → describe only the docs
base staged-and-pending
printf '\n## Usage\n\nImport `add` from `src/math.js`.\n' >> README.md
git add README.md
printf '\nexport function multiply(a, b) {\n  return a * b;\n}\n' >> src/math.js
expect TYPE docs

# staged together on purpose: a new function plus an unrelated fix → one feat
# header that names both
base mixed-staged
sed -i.bak 's/return a + b;/return Number(a) + Number(b);/' src/math.js && rm src/math.js.bak
printf '\nexport function multiply(a, b) {\n  return a * b;\n}\n' >> src/math.js
git add src
expect TYPE feat
expect KEYWORDS "multipl" "number|numeric|coerce|convert|cast|operand"

# nothing at all: say there is nothing to commit, propose no header
base no-changes
expect TYPE none

# Snapshot the staged set so check.sh can prove the skill only proposed.
for d in "$out"/*/; do
  git -C "$d" diff --staged --name-only > "$d/.git/STAGED_SNAPSHOT"
done

echo "Fixtures in $out:"; ls "$out"
