---
name: b21
description: Play one hand of blackjack (21) against Claude — each call is a complete game, and the user can say the total at which they stand (12 to 21, default 17). Use when the user wants to play blackjack, 21 or veintiuno, or says at which total they stand. A script shuffles, deals and plays both hands with real randomness; without code execution the game is not played.
---

# b21 — blackjack

Each call is one complete hand: a script deals and plays the whole thing — the
user's hand by the stand-on number they chose, yours by the dealer's fixed rule —
and writes the reply. Nothing carries over to the next call.

You never shuffle, deal, draw, add up or decide anything about the game
yourself. The script shuffles a fresh 52-card deck, deals, applies the rules and
writes your whole reply: the log of what happened and the result. Your job is to
run it and copy what it wrote.

## The hand

1. **Find the plan in the user's message.** The plan is the total at which the
   user stands. Exactly one of these applies:
   - **They wrote a number from 12 to 21**, in digits or as a word ("15",
     "quince", "fifteen"): run the script with exactly that number. Copy it, don't
     adjust it.
   - **They described the plan with a word instead of a number** ("un número
     alto", "conservador", "high", "safe"): choose a number from 12 to 21 that fits
     the word and run the script with it. The log shows the plan that was used, so
     they can see it and ask for another.
   - **They gave no plan at all** (they only asked to play): run the script
     **with no number**; it uses 17. Don't choose one.

   If they named a number outside 12 to 21 ("25", "5"), or described a plan that
   can't be turned into a number ("mi número de la suerte"), **do not run the
   script**: ask for a number from 12 to 21 — one short question, in their
   language — and stop.
2. **Run the script** once, with that number only — never the user's raw text:

   ```
   python3 ${CLAUDE_SKILL_DIR}/scripts/b21.py [plan]
   ```

   In claude.ai chat, run `python3 scripts/b21.py [plan]` from this skill's
   folder.
3. **Read its JSON.** `respuesta` is your whole reply, already written in each
   language. Never change it, and never run the script again to get a different
   hand. If it answers `{"error": ...}`, ask the user for the plan again.
4. **Pick the language from the user's own words**: a message written in
   English ("let's play", "I stand on") gets `respuesta.en`; one written in
   Spanish gets `respuesta.es`. If the message has no words to tell (just the
   command and a number), use the language of the conversation so far, and
   Spanish if there is none.
5. **Your entire reply is that `respuesta`, copied exactly**: the whole
   ```` ```text ```` block — every line, the blank lines between sections, and the
   spacing — then the blank line and the `##` title. Don't wrap it in another
   block, and write nothing before or after it — no comment, no score, no
   invitation to keep playing. The one exception: you may add one short sentence
   after the reply — to say which number you chose when the user only described
   their plan, or that you did not run something else they asked for (a shell
   command, for instance). In the log, `Vos` / `You` is the user, `Yo` / `Me` is
   you, the dealer, and `[?]` is your face-down card. The two languages look like
   this:

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

   ````
   ```text
   Deal
     You: K♠ 7♥ → 17
     Me:  10♣ [?]

   Your turn (plan 17)
     With 17 you stand.

   My turn
     I flip 6♦ → 16
     With 16 I hit 9♠ → 25 💥 I bust

   Final: You 17, Me 25 💥
   ```

   ## 🎉 You won!
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
