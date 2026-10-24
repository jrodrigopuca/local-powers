---
name: rps
description: Play rock, paper, scissors (piedra, papel o tijera) with the user, round after round until they want to stop. Use when the user wants to play rock paper scissors or piedra papel tijera, or names a move to play. A script makes Claude's move with real randomness; without code execution the game is not played.
---

# rps — rock, paper, scissors

You never choose your own move. A script chooses it with real randomness,
without seeing the user's move, and decides who won. Your job is to run it and
report exactly what it says.

## Each round

1. **Read the user's move** and map it to exactly one of `piedra`, `papel`,
   `tijera`. Accept Spanish or English, singular or plural, and common synonyms
   (rock, stone, roca → `piedra`; paper, hoja → `papel`; scissors, tijeras →
   `tijera`). If there is no move, or you can't tell which one it is, ask for it
   and do not run the script.
2. **Run the script** with that one word — never the user's raw text:

   ```
   python3 ${CLAUDE_SKILL_DIR}/scripts/jugada.py <piedra|papel|tijera>
   ```

   In claude.ai chat, run `python3 scripts/jugada.py <move>` from this skill's
   folder. Run it once per round.
3. **Read its JSON.** `claude` is your move and `resultado` is the outcome:
   `gana_usuario` (the user wins), `gana_claude` (you win), `empate` (a tie).
   Report exactly that. Never change it, and never run the script again to get a
   different result.
4. **Reply in the user's language** with these two lines in a `text` block, then
   one short line inviting the next move:

   Spanish:

   ```text
   Vos: piedra · Claude: papel → gana Claude
   Marcador: Vos 0 · Claude 1 · Empates 0
   ```

   English (moves as rock, paper, scissors):

   ```text
   You: rock · Claude: paper → Claude wins
   Score: You 0 · Claude 1 · Ties 0
   ```

   Outcome words: Spanish `ganás vos`, `gana Claude`, `empate`; English
   `you win`, `Claude wins`, `tie`. The score counts every round of this game,
   taken from your previous replies.

## Ending the game

Keep playing round after round. Don't end the game on your own. When the user
says they want to stop (basta, listo, terminamos, stop, I'm done…), show the
final score line and who won overall.

## When the script can't run

Without the script the game is not fair: your move would not be random, and you
have already seen the user's. So if you cannot run it — no code execution,
permission denied, `python3` missing, or the script fails — do not choose a move
yourself and do not play. Tell the user, in one or two sentences, that the game
needs code execution and why. In claude.ai, it is turned on under Settings →
Capabilities → "Code execution and file creation".

If the script answers with `{"error": ...}` because the move was not valid, ask
the user for their move again.
