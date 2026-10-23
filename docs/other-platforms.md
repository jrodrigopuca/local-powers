# Other platforms

local-powers targets Claude Code only ([ADR-0002](adr/0002-claude-only.md)).
These are the notes from trying the plugins elsewhere, so a future decision
starts from what was observed instead of from scratch. Each fact is marked
**verified** (we ran it) or **documented** (read in the platform's docs, not run).

All the platforms below that load plugins read the same open format,
**Agent Plugins 1.0.0**: a root `plugin.json` with
`"$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"`, plus
`skills/<name>/SKILL.md`. Claude Code does not read it (it reads
`.claude-plugin/plugin.json`) and ignores it when both are present — verified.
The last commit that shipped it is `250af5b`
(`git show 250af5b:plugins/commit-style/plugin.json`).

## Codex (OpenAI) — supported until `250af5b`, removed by ADR-0002

How to restore it, what the test runner did and the limits found are in
[ADR-0002 → Bringing Codex back](adr/0002-claude-only.md#bringing-codex-back).
In short:

- **Install** — verified with Codex CLI 0.162.1:
  `codex plugin marketplace add jrodrigopuca/local-powers`, then
  `codex plugin add <plugin>@local-powers`. Codex reads our
  `.claude-plugin/marketplace.json`; no extra catalog needed.
- **Invoke** — verified: `$<plugin>:<skill>` (e.g. `$commit-style:msg`), or ask in
  natural language.
- **Results** — verified: `commit-style` passed 10/10 cases with `gpt-6-astra`
  and with `gpt-6-luna` (after making the one-line rule explicit for small models).
- **Why it was removed** — test runs doubled their cost, they could not be
  isolated from `~/.codex` without relocating credentials, and nobody used it.

## Kiro (AWS) — evaluated 2026-10-23, not adopted

Kiro calls plugins **powers**. It has two formats: the legacy `POWER.md` (with
optional `mcp.json` and `steering/`), and Agent Plugins, which is where new
features land first (documented).

- **Install from the CLI** — verified with `kiro-cli` 2.29.1:
  `kiro-cli powers install <catalog-name | local-path>`. It takes a **local
  path, not a GitHub URL**: clone the repo, then point at the plugin folder,
  e.g. `kiro-cli powers install ~/Developer/local-powers/plugins/commit-style`.
  It **copies** the plugin into `~/.kiro/powers/installed/<name>/` and records it
  in `~/.kiro/powers/installed.json`, so every update means uninstall and
  install again. Uninstall: `kiro-cli powers uninstall <name>`.
- **Install from the IDE** — documented: Powers panel → *Add Custom Power* →
  *Import power from GitHub* (a URL) or *Import power from a folder* (the folder
  that holds `plugin.json`); updates via *Check for updates*. The docs don't say
  how a GitHub URL targets a plugin in a subfolder such as `plugins/<name>/`.
- **Marketplace** — Kiro doesn't use our `.claude-plugin/marketplace.json`; each
  power is installed on its own (documented, by omission).
- **Invoke** — verified: `/msg` (the skill name, without the plugin prefix).
  Powers are also meant to activate on their own when a request matches
  (documented, not tried).
- **Custom agents** — documented: custom agents don't load skills unless they're
  listed in the agent's `resources`.
- **Result** — verified, one manual run of `/msg` in a session that had already
  discussed the change: it ran `git diff --staged --stat` only, skipped reading
  the diff and `git log`, and answered with a bare line
  (`feat(commit-style): add plugin.json manifest`) instead of a `text` block.
  Not isolated: the cause may be the session's prior context, the model, or how
  Kiro loads the skill. A fresh session was not tried.
- **Why not adopted** — the skill was followed only partly, and installs are
  local copies that need reinstalling on every update.

## Others — not tried

Agent Plugins was announced with ChatGPT/Codex, Cursor, GitHub Copilot, Kiro and
VS Code as supporting clients (documented, secondary sources: Vercel's
announcement). VS Code's docs say it also detects Claude's plugin format.
`commit-style` needs a terminal with access to the repository (it runs `git`),
so it can only work in agentic clients with one — not in web chat.

## Sources

- [Agent Plugins 1.0.0 (Vercel)](https://vercel.com/changelog/introducing-agent-plugins-1-0-0)
- [OpenAI — Package your plugin](https://developers.openai.com/plugins/build/plugins)
- [Kiro — Powers now support Agent Plugins](https://kiro.dev/blog/powers-supports-plugins/)
- [Kiro — Installing powers (French page, covers Agent Plugins)](https://kiro.dev/fr/docs/powers/installation/)
- [Kiro — Skills in the CLI](https://kiro.dev/docs/cli/skills/)
- [VS Code — Agent plugin authoring reference](https://code.visualstudio.com/docs/agents/reference/agent-plugin-reference)
