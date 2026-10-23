# local-powers

Plugins for **Claude Code** and **Codex / ChatGPT**, from one source.

Each plugin is a folder of portable skills (`skills/<name>/SKILL.md`) that both
assistants read as-is, plus one small manifest per platform. No build step: this
repository is itself the marketplace both CLIs install from.

## Plugins

| Plugin | What it does |
|--------|--------------|
| [`commit-style`](plugins/commit-style/) | Proposes one-line [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) headers for your staged changes, or for your pending changes when nothing is staged. Only proposes: staging and committing stay with you. |

## Install

**Claude Code**

```
/plugin marketplace add jrodrigopuca/local-powers
/plugin install commit-style@local-powers
```

From your shell: `claude plugin install commit-style --marketplace jrodrigopuca/local-powers`.

**Codex** (CLI, and Codex in the ChatGPT desktop app)

```
codex plugin marketplace add jrodrigopuca/local-powers
codex plugin add commit-style@local-powers
```

Then just ask, e.g. *"propose a commit message for my changes"*, or invoke a skill
directly as `/<plugin>:<skill>` in Claude Code and `$<plugin>:<skill>` in the Codex
CLI (`/commit-style:msg`, `$commit-style:msg`). The skill runs on
whatever model your session is using; it adds no model or service of its own.

> Not yet listed in Anthropic's or OpenAI's public plugin directories: install from
> this repository as shown above.

## Repository layout

```
.claude-plugin/marketplace.json     the catalog (read by Claude Code and Codex)
plugins/<plugin>/
├── .claude-plugin/plugin.json      manifest for Claude Code
├── plugin.json                     manifest for Codex/ChatGPT (Agent Plugins format)
├── README.md
└── skills/<skill>/SKILL.md         the part both platforms share
tests/
├── run.sh                          runs a plugin's cases through both CLIs
└── <plugin>/                       that plugin's test cases
docs/adr/                           architecture decisions
```

Why two manifests side by side instead of a build step:
[ADR-0001](docs/adr/0001-dual-manifest-plugins.md).

## Adding a plugin

1. Create `plugins/<name>/` with `skills/`, a `README.md`, and both manifests.
   `name`, `version` and `description` must match in the two manifests.
2. Add an entry to `.claude-plugin/marketplace.json`.
3. Keep anything that must hold every time in `SKILL.md` itself: models don't
   always open files under `references/`.
4. Avoid "claude" in plugin names: `claude plugin validate` rejects or warns on it.
5. Check it: `claude plugin validate --strict plugins/<name>`.
6. Add tests under `tests/<name>/` (below) — never inside the plugin folder,
   or they get installed with it.

Only skills and remote MCP servers work on both platforms. Agents, hooks and
commands are Claude Code only (see ADR-0001).

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

Run them:

```
tests/run.sh commit-style                    # both CLIs, every case
tests/run.sh commit-style codex              # one CLI
tests/run.sh commit-style both no-changes    # one case
```

- **Models:** small ones by default (`haiku`, `gpt-6-luna`) to keep runs cheap.
  Override with `CLAUDE_MODEL=…` / `CODEX_MODEL=…`; `default` uses the CLI's
  configured model. Run once with `default` before a release: a pass on a small
  model does not guarantee one on a large model.
- **Cost:** each case is a real model call per CLI. The end of each CLI's run
  reports the model and the tokens used (and the cost, for Claude).
- **Isolation:** Claude runs without your settings, skills, agents, MCP servers
  or session history. Codex runs with your own `~/.codex` (skills and agents
  included) and installs the plugin from this repository for the run, removing
  it on exit.

## License

[MIT](LICENSE)
