# commit-style

Proposes a one-line [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
message for your changes. It reads the staged changes (or the pending ones, when
nothing is staged), follows the style already used in the repository's history,
and replies with a single header:

```
<type>[(scope)][!]: <description>     # max 72 characters, no body, no footer
```

It only **proposes** the message: what to stage and when to commit is up to you,
so it never runs or suggests `git add`, `git restore` or `git commit`.

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

Tests live outside the plugin, in the repository's `tests/commit-style/`, so they
are not installed with it. Run them with `tests/run.sh commit-style`.
