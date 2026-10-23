# commit-style

Proposes a one-line [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
message for what you are about to commit. It reads the staged changes (or, when
nothing is staged, suggests what to stage), follows the style already used in the
repository's history, and replies with a single header:

```
<type>[(scope)][!]: <description>     # max 72 characters, no body, no footer
```

It only **proposes**: it never runs `git add` or `git commit`.

## Install

Claude Code:

```
/plugin marketplace add jrodrigopuca/local-powers
/plugin install commit-style@local-powers
```

Codex:

```
codex plugin marketplace add jrodrigopuca/local-powers
```

## Use

Ask for a commit message ("propose a commit message for what's staged").

## Tests

- `tests/check-header.sh "<header>" [type]` checks a header against the contract.
- `tests/make-fixtures.sh <dir>` builds throwaway repos with an unambiguous type.
