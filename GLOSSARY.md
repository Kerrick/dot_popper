<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Glossary

Dot Popper's Ubiquitous Language. Code, screens, docs and the server use the same word for the same thing. A different word in the code than on screen needs the maintainer's approval. Where a thing has no entry here, use the universal industry term (screen, button, dialog, list), and no metaphors.

| Term | Means | Don't say |
| --- | --- | --- |
| **game** | One go, from pressing Play until Game Over. Dot Popper is also a game; show counts as "games left" so the two can't be confused. | round, run, a play |
| **Play** | The verb, and the button that starts a game. Never a noun. | |
| **Game Over** | The state and screen after a game. | Finale |
| **Time's up!** | The words shown at the moment a game ends. | |
| **bright dot** | A dot to tap. | |
| **popped dot** | A dot already tapped, which stays in play. | |
| **pop** | The verb. Never a noun in what players read. | "pops", "slowest pop" |
| **mistake** | Tapping a popped dot. | slip |
| **dots in a row** | Bright dots popped in one game without a mistake. | run, streak, pops in a row |
| **streak** | The daily one only: days in a row of meeting the daily goal, as in phone apps. | |
| **Longest Time to Pop** | The longest wait that ended in popping a dot. | slowest pop, longest wait |
| **score** | Points in one game. | |
| **record** | A personal best at one thing, as in "New record!" | "best", or records meaning every statistic |
| **Stats** | The screen and data about all your games. | Records, lifetime |
| **Free** | The game without a purchase. | trial, demo |
| **Pro** | The one purchase: unlimited games, achievements, themes, friend groups. Nothing in Pro changes how the game plays or scores. | paid, the full game, premium |
| **license key** | The signed text a website purchase of Pro sends by email, which "Paste license key" enters. One key holds Pro on one device at a time. Store copies have none: their store keeps the purchase. | serial, code, activation, product key |
| **receipt** | A store's signed record of a purchase of Pro (StoreKit's signed transaction, Play's signed purchase), which the game verifies itself, offline, each launch. The Microsoft Store has none: there, "receipt" is Windows' own license for Pro, taken at each launch from the store helper. Code and docs only; no screen shows the word. | token, flag |
| **Theme** | A set of art and sound for the game. | Looks, skin, wardrobe |
| **current theme** | The theme in use now. | worn |
| **use** | What a player does with a theme, as in "Use Ghost". | wear, dress, equip |
| **achievement** | A goal earned once. | feat |
| **friend group** | Players who compete for one title. | |
| **title** | The one prize a friend group has, held by whoever has its top score. | trophy, crown, belt |
| **champion** | The member holding the title. | holder |
| **win / take the title** | To beat the group's top score. | steal, theft, thief |
| **top score** | The highest score in a friend group since its members joined. | score to beat |
| **title change** | The title passing to another member, seen by the whole group and never acknowledged. | news, theft |
| **Home** | The main screen, with Play on it, and the button that returns there. | the title screen, main menu |

## Not yet decided

- `Cabinet` names the app's screen flow in code. Players never see it.

Don't write "bank" or "pool" for free games: say "your first 20 games" and "3 games a day". Don't call Free a trial or demo anywhere.
