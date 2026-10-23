# ADR-0002: Plugins target Claude Code only; Codex support is removed

- Status: accepted
- Date: 2026-10-23
- Supersedes: [ADR-0001](0001-dual-manifest-plugins.md)
- Drivers:
  - The plugins are used by one person, in Claude Code only; nobody uses the
    Codex side.
  - Keeping it cost more than its manifest: every test run doubled its model
    calls and spent OpenAI quota, Codex runs could not be isolated from the
    user's `~/.codex` without relocating their credentials, and portability
    limits each plugin to skills and remote MCP — no agents, hooks, commands or
    `userConfig`.
- Decision: each plugin has only `.claude-plugin/plugin.json`. The root
  `plugin.json` (Agent Plugins), the Codex runner in `tests/run.sh` and the
  portable-manifest checks in `scripts/check.sh` are removed. Plugins may use any
  Claude Code component.
- Tradeoff accepted: the repository no longer installs in Codex, ChatGPT or other
  Agent Plugins clients, and a plugin that uses Claude-only components will need
  rework to become portable later.
- Revisit if: someone needs these plugins outside Claude Code (Codex, ChatGPT,
  Cursor, Copilot), or Claude Code adopts the Agent Plugins format itself.

## Bringing Codex back

The last commit with working Codex support is `250af5b`
(`git show 250af5b --stat`). What it had, and what was verified:

1. **Manifest**: a root `plugin.json` next to `.claude-plugin/plugin.json`, with
   `"$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"` and
   the same `name`, `version` and `description`. Claude Code ignores it; Codex
   0.162.1 prefers it over `.codex-plugin/plugin.json` (ADR-0001).
2. **Catalog**: none extra — Codex reads `.claude-plugin/marketplace.json`.
   Install with `codex plugin marketplace add jrodrigopuca/local-powers` and
   `codex plugin add <plugin>@local-powers`; skills are invoked as
   `$<plugin>:<skill>`.
3. **Tests**: `git show 250af5b:tests/run.sh` has `run_codex`. Codex has no
   `--plugin-dir`, so the runner installs the plugin from the local marketplace
   and removes it on exit; it uses `codex exec -s read-only --ephemeral --json -o`,
   `< /dev/null` (otherwise it waits on stdin), `-m gpt-6-luna` as the small
   model, and reads tokens from `turn.completed` events. It runs with the user's
   `~/.codex` (not isolated).
4. **Checks**: `git show 250af5b:scripts/check.sh` compares the two manifests.
5. **Limits found**: only skills and remote (HTTPS) MCP servers carry over;
   OpenAI's public directory drops hooks, agents, commands and `userConfig`.
   MCP config differs: Claude reads `.mcp.json`, Agent Plugins reads `mcp.json`
   with a transport `type` per server.

Restoring is mostly `git checkout 250af5b -- <files>` for the runner and the
checks, then re-adding a `plugin.json` per plugin and re-running the suite.
