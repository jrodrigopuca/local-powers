---
name: rps
description: Play one round of rock, paper, scissors (piedra, papel o tijera) with the user — each call is a complete game, with no score carried over. Use when the user wants to play rock paper scissors or piedra papel tijera, or names a move to play. A script makes Claude's move with real randomness; without code execution the game is not played.
---

# rps — rock, paper, scissors

Each call is one complete game: the user names a move, you play one round, you
report the result, and the game ends there. No score, no rounds carried over.

You never choose your own move. A script chooses it with real randomness,
without seeing the user's move, and decides who won. Your job is to run it and
report exactly what it says.

## The round

1. **Read the user's move** and map it to exactly one of `piedra`, `papel`,
   `tijera`. Accept Spanish or English, singular or plural, and common synonyms
   (rock, stone, roca → `piedra`; paper, hoja → `papel`; scissors, tijeras →
   `tijera`). If there is no move, or you can't tell which one it is, ask for it
   and do not run the script.
2. **Run the script** once, with that one word — never the user's raw text:

   ```
   python3 ${CLAUDE_SKILL_DIR}/scripts/jugada.py <piedra|papel|tijera>
   ```

   In claude.ai chat, run `python3 scripts/jugada.py <move>` from this skill's
   folder.
3. **Read its JSON.** `claude` is your move, `resultado` the outcome, and
   `linea` the result already written in each language. Never change it, and
   never run the script again to get a different result.
4. **Reply with `linea.es`** (Spanish) **or `linea.en`** (English), whichever is
   the user's language, copied exactly — emojis included — in a `text` block,
   and nothing else: no score, no invitation to keep playing. For example:

   ```text
   Vos: ✊ piedra · Claude: ✋ papel → gana Claude 🤖
   ```

If the user names another move afterwards, that is a new game: play it the same
way, with no reference to earlier rounds.

## When the script can't run

Without the script the game is not fair: your move would not be random, and you
have already seen the user's. So if you cannot run it — no code execution,
permission denied, `python3` missing, or the script fails — do not choose a move
yourself and do not play. Tell the user, in one or two sentences, that the game
needs code execution and why. In claude.ai, it is turned on under Settings →
Capabilities → "Code execution and file creation".

If the script answers with `{"error": ...}` because the move was not valid, ask
the user for their move again.
