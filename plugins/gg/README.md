# gg

Games to play with Claude, one skill per game.

| Skill | Game | Start it with |
|-------|------|---------------|
| `rps` | Rock, paper, scissors (piedra, papel o tijera), round after round until you stop | "let's play rock paper scissors", "juguemos piedra, papel o tijera", or `/gg:rps` |

## How rps stays fair

In a chat, someone has to write their move first. If Claude chose after reading
yours, it wouldn't be a fair game, and models aren't good at randomness anyway.
So Claude doesn't choose: `skills/rps/scripts/jugada.py` picks Claude's move with
Python's `secrets` module, without seeing yours, and applies the rules. Claude
only runs it and reports the result.

That needs code execution. Claude Code runs the script with your `python3`.
In claude.ai, the desktop and mobile apps, it runs in the code execution sandbox
(Settings → Capabilities → "Code execution and file creation"). Without it,
Claude tells you the game can't be played instead of playing unfairly.

## Install

In Claude Code:

```
/plugin marketplace add jrodrigopuca/local-powers
/plugin install gg@local-powers
```

In claude.ai or the desktop app: Customize → Plugins → Add → Add marketplace →
`jrodrigopuca/local-powers`, then add `gg`.

## Tests

In the repository's `tests/gg/`. Run them with `tests/run.sh gg`.
