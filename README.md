# local-powers

Plugins for **Claude Code**.

Each plugin is a folder with its manifest and its skills; this repository is
itself the marketplace Claude Code installs from. No build step.

## Plugins

| Plugin | What it does |
|--------|--------------|
| [`commit-style`](plugins/commit-style/) | Proposes one-line [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) headers for your staged changes, or for your pending changes when nothing is staged. Only proposes: staging and committing stay with you. |

## Install

```
/plugin marketplace add jrodrigopuca/local-powers
/plugin install commit-style@local-powers
```

From your shell: `claude plugin install commit-style --marketplace jrodrigopuca/local-powers`.

Then just ask, e.g. *"propose a commit message for my changes"*, or invoke a skill
directly as `/<plugin>:<skill>` (`/commit-style:msg`). The skill runs on whatever
model your session is using; it adds no model or service of its own.

Third-party marketplaces don't auto-update by default: run
`claude plugin update <plugin>@local-powers` to get a new version.

> Claude Code only. Codex/ChatGPT support existed and was removed
> ([ADR-0002](docs/adr/0002-claude-only.md)), which also explains how to bring it back.

## Repository layout

```
.claude-plugin/marketplace.json     the catalog
plugins/<plugin>/
├── .claude-plugin/plugin.json      the manifest
├── README.md
└── skills/<skill>/SKILL.md         plus agents/, hooks/… when a plugin needs them
tests/
├── run.sh                          runs a plugin's cases through Claude Code
└── <plugin>/                       that plugin's test cases
scripts/check.sh                    structural checks (no model calls)
.githooks/pre-push                  runs scripts/check.sh before every push
docs/adr/                           architecture decisions
```

## Adding a plugin

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json` (its `name` equal
   to the folder name), a `README.md`, and its components — skills, agents,
   hooks, commands: any Claude Code component is fine.
2. Add an entry to `.claude-plugin/marketplace.json`.
3. Keep anything that must hold every time in `SKILL.md` itself: models don't
   always open files under `references/`.
4. Avoid "claude" in plugin names: `claude plugin validate` rejects or warns on it.
5. Add tests under `tests/<name>/` (below) — never inside the plugin folder,
   or they get installed with it.
6. Run `scripts/check.sh`.

## Testing

**Structural checks** (no model calls, a few seconds): `scripts/check.sh` checks
the manifests, the marketplace, the skills' names, the scripts, runs
`claude plugin validate --strict` when the `claude` CLI is installed, and runs
each plugin's checker self-test. To run it before every push, enable the hook
once per clone:

```
git config core.hooksPath .githooks
```

A failing check stops the push; `git push --no-verify` skips it.

**Behaviour tests** (real model calls) live in `tests/<plugin>/`. Each plugin's
test folder provides:

| File | Purpose |
|------|---------|
| `make-fixtures.sh <dir>` | builds one throwaway git repo per case; expectations go in each repo's `.git/expected/`, out of the model's sight |
| `prompt.txt` | what is asked in every case |
| `check.sh <fixture> <answer>` | exits 0 when the answer passes |
| `selftest.sh` | optional: proves `check.sh` accepts and rejects hand-written answers (run by `scripts/check.sh`) |

Run them:

```
tests/run.sh commit-style               # every case
tests/run.sh commit-style no-changes    # one case
```

- **Model:** `haiku` by default to keep runs cheap. Override with
  `CLAUDE_MODEL=…`. Before a release, run once with the model you actually
  work with (e.g. `CLAUDE_MODEL=opus`): a pass on a small model does not
  guarantee one on a large model. `CLAUDE_MODEL=default` is Claude Code's
  built-in default, **not** the model in your settings — the runs don't read
  your settings.
- **Cost:** each case is a real model call. The end of the run reports the
  model, the tokens and the cost.
- **Isolation:** tests run without your settings, skills, agents, MCP servers
  or session history, so only the plugin under test is loaded.

## License

[MIT](LICENSE)
