# commit-style

Proposes a one-line [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
message for your changes. When something is staged it looks only at that and
proposes one header for all of it. When nothing is staged it looks at all pending
changes and, if they mix unrelated purposes, suggests one header per group of
files. It follows the style already used in the repository's history:

```
<type>[(scope)][!]: <description>     # max 72 characters, no body, no footer
```

It only **proposes** the message: what to stage and when to commit is up to you,
so it never runs or suggests `git add`, `git restore` or `git commit`.

## Install

In Claude Code:

```
/plugin marketplace add jrodrigopuca/local-powers
/plugin install commit-style@local-powers
```

## Use

Ask for a commit message ("propose a commit message for what's staged"), or run
the skill directly with `/commit-style:msg`.

## Tests

Tests live outside the plugin, in the repository's `tests/commit-style/`, so they
are not installed with it. Run them with `tests/run.sh commit-style`.
