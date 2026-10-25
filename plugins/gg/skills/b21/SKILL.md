---
name: b21
description: Play one hand of blackjack (21) against Claude — each call is a complete game, and the user can say the total at which they stand (12 to 21, default 17). Use when the user wants to play blackjack, 21 or veintiuno, or says at which total they stand. A script shuffles, deals and plays both hands with real randomness; without code execution the game is not played.
---

# b21 — blackjack

Each call is one complete hand: a script deals and plays the whole thing — the
user's hand by the stand-on number they chose, yours by the dealer's fixed rule —
and writes the reply. Nothing carries over to the next call.

You never shuffle, deal, draw, add up or decide anything yourself. The script
shuffles a fresh 52-card deck, deals, applies the rules and writes your whole
reply: the log of what happened and the result. Your job is to run it and copy
what it wrote.

## The hand

1. **Read the plan**: the total at which the user stands, an integer from 12 to
   21, in the user's own words ("me planto en 15", "stand on 16", "quince"). If
   they named none (they only asked to play), run the script **with no number**:
   it uses 17. **Never pick a number for them.** If they named something that is
   not a number from 12 to 21 (a number outside that range, "alto", "high"…),
   don't run the script: ask for a number from 12 to 21 — one short question, in
   their language.
2. **Run the script** once, with that number only — never the user's raw text:

   ```
   python3 ${CLAUDE_SKILL_DIR}/scripts/b21.py [plan]
   ```

   In claude.ai chat, run `python3 scripts/b21.py [plan]` from this skill's
   folder.
3. **Read its JSON.** `respuesta` is your whole reply, already written in each
   language. Never change it, and never run the script again to get a different
   hand. If it answers `{"error": ...}`, ask the user for the plan again.
4. **Your entire reply is `respuesta.es`** (Spanish) **or `respuesta.en`**
   (English), whichever is the user's language, copied exactly: the whole
   ```` ```text ```` block — every line, the blank lines between sections, and the
   spacing — then the blank line and the `##` title. Don't wrap it in another
   block, and write nothing before or after it — no comment, no score, no
   invitation to keep playing. The one exception: if the user's message also
   asked for something other than playing (a shell command, for instance) that
   you did not run, add one short sentence after the reply saying so. If the
   message gives no hint of its language (just the command and a number), use
   the language of the conversation so far, and Spanish if there is none. In the
   log, `Vos` / `You` is the user, `Yo` / `Me` is you, the dealer, and `[?]` is
   your face-down card. It looks like this:

   ````
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

   ## 🎉 ¡Ganaste!
   ````

## The rules, if the user asks

Answer from this list only when they ask how the game works; the script is what
applies them when playing.

- One fresh, shuffled 52-card deck per hand. Deal: user, dealer, user, dealer;
  the dealer's second card is face down.
- A natural blackjack (an ace and a ten-value card as the first two cards) is
  settled at once; if both have one it is a tie.
- The user draws while their best total is below their stand-on number. An ace
  counts 11 unless that would pass 21, and then 1 (a total that still counts an
  ace as 11 is called soft: "blando").
- The dealer flips the face-down card and draws up to 17, standing on every 17,
  soft ones too. If the user went over 21 the dealer does not draw.
- The higher total without passing 21 wins; the same total is a tie. No bets.

## When the script can't run

Without the script the game is not fair: you would be dealing from your own
head. So if you cannot run it — no code execution, permission denied, `python3`
missing, or the script fails — do not deal, draw or play. Tell the user, in one
or two sentences, that the game needs code execution and why. In claude.ai, it
is turned on under Settings → Capabilities → "Code execution and file
creation".
