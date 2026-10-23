---
name: commit-style
description: Propose a one-line Conventional Commits message for the staged changes (or for the pending changes, suggesting what to stage). Use when the user asks for a commit message, what to commit, or how to describe their changes. Proposes only; never runs git commit.
---

# commit-style

Propose a commit message in the form:

```
<type>[(scope)][!]: <description>
```

One line. No body, no footer. **Maximum 72 characters in total.**

You only PROPOSE the message. Never run `git commit`, `git add`, or any command
that changes the repository. Reading commands only.

## 1. Find what will be committed

1. Run `git diff --staged --stat`.
2. **Something is staged** → that is the commit. Ignore unstaged changes.
3. **Nothing staged** → run `git status --short`. If there are changes, propose
   which files to stage (as a `git add ...` line for the user to run) and the
   message for that set. If there are no changes at all, say so and stop.

## 2. Read the diff without flooding the context

- Read `git diff --staged` (or `git diff` for the unstaged case) **excluding**
  noise: lockfiles (`*.lock`, `package-lock.json`, `pnpm-lock.yaml`,
  `Gemfile.lock`, `Cargo.lock`, `go.sum`), minified or generated files, and
  binaries. Use pathspecs, e.g. `git diff --staged -- . ':!package-lock.json'`.
- If the remaining diff is large (over ~400 changed lines), do not read it all:
  use the `--stat` output plus the hunk headers (`git diff --staged -U0`) and
  read only the files that decide the type.

## 3. Follow the repository's own style

Run `git log --oneline -20`. If the history already uses Conventional Commits,
reuse its scopes, language and casing. If it does not, use English, lowercase
description, imperative mood ("add", not "added").

## 4. Build the header

- **type**: pick from [references/conventional-commits.md](references/conventional-commits.md).
  Choose by the change's effect for the user of the code, not by the files touched.
- **scope** (optional): the area that changed, taken from the path
  (`plugins/commit-style/...` → `commit-style`). Omit it when the change spans
  unrelated areas or the repo does not use scopes.
- **`!`**: only when the change breaks compatibility for callers (removed or
  renamed public API, changed output format, changed config). It is the only
  way to mark a breaking change, since there is no footer.
- **description**: what the change does, imperative, no trailing period.

If the header does not fit in 72 characters, shorten the description — never
truncate mid-word. If it still does not fit, the commit likely does more than
one thing: see step 5.

## 5. One commit, one purpose

If the changes clearly mix purposes (a feature plus an unrelated fix, a refactor
plus a behaviour change), say so and propose a split: which files go in each
commit, and one header for each.

## Output

Reply with the header in a code block, then at most one line explaining the
choice of type. For a split, one code block per commit with its `git add` line.
