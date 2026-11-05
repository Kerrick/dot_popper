Dot Popper playtest kit for macOS
=================================

@BUILD@

Thank you for playtesting Dot Popper! This takes about 15 minutes.

What is in the kit
------------------

- Dot Popper.app: the game, for Macs with Apple silicon (M1 or newer).
- macos-results.txt: the questions. Fill it in as you play, then send it
  back. It is the one file to return (with any screenshots).

1. Open the game
----------------

Unzip the kit (double-click dot-popper-macos-kit.zip), and move
Dot Popper.app anywhere you like, such as Applications.

Dot Popper isn't notarized by Apple, so the first time macOS stops it:

- On macOS 14 (Sonoma) or older: right-click (or Control-click)
  Dot Popper.app, choose Open, then Open again.
- On macOS 15 (Sequoia) or newer: double-click it, choose Done when macOS
  says it can't check it, then open System Settings > Privacy & Security,
  scroll down to "Dot Popper was blocked", click Open Anyway, and confirm
  with your password.

Say in the last note which of these you needed.

2. Play, and fill in macos-results.txt
--------------------------------------

Open macos-results.txt in TextEdit, play, and write each answer after its
arrow. Skip anything you can't try. Check 2 asks you to quit the game
(Escape on the title screen) and open it again.

3. Optional: how smoothly it runs
---------------------------------

To record how smoothly the game draws, quit it and start it from Terminal
instead (Applications > Utilities > Terminal), with the app where you put
it:

    DOT_POPPER_PERF=1 "/Applications/Dot Popper.app/Contents/MacOS/Dot Popper"

Every five seconds it prints a line such as "60 frames a second, longest
frame 18.2 ms". Quit the game, then select the Terminal's text, copy it,
and paste it at the end of macos-results.txt.

The game's saved files (scores, and rounds.csv, a line for each round) are
in ~/Library/Application Support/dot_popper. In Finder, choose Go > Go to
Folder, paste that path, and attach rounds.csv to your message too.
