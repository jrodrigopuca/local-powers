# gg

Games to play with Claude, one skill per game.

| Skill | Game | Start it with |
|-------|------|---------------|
| `rps` | Rock, paper, scissors (piedra, papel o tijera): each call is one round, a complete game with no score kept | "let's play rock paper scissors, I pick rock", "juguemos piedra, papel o tijera: piedra", or `/gg:rps piedra` (in claude.ai chat the slash menu lists it as `/rps`) |
| `b21` | Blackjack (21): each call is one complete hand, played and logged step by step; you choose the total at which you stand | "let's play blackjack, I stand on 15", "jugá al veintiuno, me planto en 16", or `/gg:b21 15` (`/b21 15` in claude.ai chat) |

## How the games stay fair

In a chat, someone has to write their move first, and a model can't deal or
choose at random. So Claude doesn't: a script does everything that has to be
right — Claude only runs it and copies what it wrote.

- **`rps`**: `skills/rps/scripts/jugada.py` picks Claude's move with Python's
  `secrets` module, without seeing yours, and applies the rules.
- **`b21`**: `skills/b21/scripts/b21.py` shuffles a fresh 52-card deck *before* it
  looks at your plan, deals, plays your hand by the stand-on total you named
  (12 to 21, 17 if you name none) and the dealer's by the house rule (draws to 17,
  stands on every 17, soft ones too), and writes the whole reply: a log of what
  happened and the result. A natural blackjack is settled at once. It looks
  like this:

  ```text
  Reparto
    Vos: K♠ 7♥ → 17
    Yo:  10♣ [?]

  Tu turno (plan 17)
    Con 17 te plantás.

  Mi turno
    Doy vuelta 6♦ → 16
    Con 16 pido 9♠ → 25 💥 me paso

  Final: Vos 17, Yo 25 💥
  ```

  You name the total at which you stand, as a number from 12 to 21 or just a word
  like "alto" or "conservador" (Claude picks a number that fits and tells you
  which; the log always shows the plan used). Without one it stands on 17. The
  reply is followed by the result as a title (`🎉 ¡Ganaste!`, `🤖 Gané` or `🤝 Empate`). The
  reply is also written in English when you play in English. `Vos` is you, `Yo`
  is Claude as the dealer, and `[?]` is its face-down card.

Both need code execution. Claude Code runs the script with your `python3`.
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

In the repository's `tests/gg/`, one folder per game. Run them with
`tests/run.sh gg` (or `tests/run.sh gg b21` for one game). Besides the cases that
play with a model, `b21` has an independent verifier (`tests/gg/b21/verify_log.py`)
that reads a reply's log and recalculates every total, decision and result from
the cards shown, so the script's arithmetic is checked by a second implementation.
