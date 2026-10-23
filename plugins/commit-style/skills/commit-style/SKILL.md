---
name: commit-style
description: Propose a one-line Conventional Commits message for the staged changes, or for the pending changes when nothing is staged. Use when the user asks for a commit message or how to describe their changes. Proposes the message only; staging and committing stay with the user.
---

# commit-style

Propose a commit message in the form:

```
<type>[(scope)][!]: <description>
```

One line. No body, no footer. **Maximum 72 characters in total.**

You only PROPOSE the message. What to stage and whether to commit is the
user's decision: never run, and never suggest, `git add`, `git restore`,
`git commit` or any command that changes the repository. Reading commands only.

## 1. Find what the message describes

1. Run `git diff --staged --stat`.
2. **Something is staged** → look at the staged changes only, and propose
   exactly one header for them (see "Everything staged goes together" below).
3. **Nothing staged** → run `git status --short` and look at all pending
   changes (modified and untracked files). If they share one purpose, propose
   one header. If they clearly mix unrelated purposes, suggest separate commits:
   one header per group, each with the files it covers. If there are no
   changes at all, say so and stop.

## 2. Read the diff without flooding the context

- Read `git diff --staged` (or `git diff` plus the untracked files when nothing
  is staged) **excluding** noise: lockfiles (`*.lock`, `package-lock.json`,
  `pnpm-lock.yaml`, `Gemfile.lock`, `Cargo.lock`, `go.sum`), minified or
  generated files, and binaries. Use pathspecs, e.g.
  `git diff --staged -- . ':!package-lock.json'`.
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
  Tie-breakers: code plus its tests → the code's type; lockfile-only or
  dependency changes → `build` (not `chore`), unless they fix a bug the user
  sees → `fix`.
- **Everything staged goes together**: the user staged it on purpose, so the
  header describes the whole set — do not question the grouping. When it mixes
  purposes, the type is the one with the most impact for the user of the code:
  `feat` > `fix` > `perf` > `refactor` > the rest (a fix plus the dependency
  bump it needed → `fix`; a new function plus an unrelated fix → `feat`).
- **scope** (optional): the area that changed, taken from the path
  (`plugins/commit-style/...` → `commit-style`). Omit it when the change spans
  unrelated areas or the repo does not use scopes.
- **`!`**: only when the change breaks compatibility for callers (removed or
  renamed public API, changed output format, changed config). It is the only
  way to mark a breaking change, since there is no footer.
- **description**: what the change does, imperative, no trailing period. When
  the set mixes purposes, name each one if they fit (`add multiply and coerce
  add operands`).

If the header does not fit in 72 characters, shorten the description to the
purpose that gave the type — never truncate mid-word.

## Output

Each header alone in a `text` code block, then at most one line explaining the
choice of type.

- Staged changes: exactly one header. No advice on how to group or split them.
- Pending changes split into groups: for each group, one line listing its files
  and then its header block. No git commands: staging stays with the user.
