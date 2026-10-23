# ADR-0001: Each plugin ships both manifests side by side, with no build step

- Status: accepted
- Date: 2026-10-23
- Drivers:
  - Skills (`skills/<name>/SKILL.md`) are read as-is by Claude Code and by Codex/ChatGPT;
    only the manifest differs between them.
  - Verified with `commit-style` (5 fixtures per CLI): Claude Code 2.1.309 loaded
    `.claude-plugin/plugin.json` and ignored the root `plugin.json`; Codex 0.162.1
    read the repo's `.claude-plugin/marketplace.json` and installed from the root
    Agent Plugins `plugin.json`. 10/10 headers passed `check-header.sh`.
  - One author, no published users yet: a build pipeline would cost more than the
    duplication it removes.
- Decision: every plugin under `plugins/<name>/` carries `.claude-plugin/plugin.json`
  (Claude Code) and a root `plugin.json` with the Agent Plugins `$schema`
  (Codex, ChatGPT, Cursor, Copilot, VS Code). One catalog at
  `.claude-plugin/marketplace.json` serves both CLIs. Name, version and
  description must match in both manifests.
- Tradeoff accepted: metadata is duplicated by hand and can drift; MCP config is not
  covered (Claude reads `.mcp.json`, Agent Plugins reads `mcp.json` with a `type`).
- Revisit if: the two manifests need to differ in more than metadata, a plugin needs
  MCP servers, Codex stops reading `.claude-plugin/marketplace.json`, or keeping
  the manifests in sync by hand produces a mismatch.
