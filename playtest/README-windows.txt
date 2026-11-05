Dot Popper playtest kit for Windows
===================================

@BUILD@

Thank you for playtesting Dot Popper! This takes about 15 minutes.

1. Unzip the whole kit: right-click dot-popper-windows-kit.zip, choose
   "Extract All...", then "Extract". Open the folder it makes.

2. Right-click playtest.ps1 and choose "Run with PowerShell". (On Windows
   11 it may be under "Show more options".) A blue window opens and asks
   its first question.

3. The script starts Dot Popper by itself. Keep its window beside the
   game. For each check it says what to try, then asks one question.
   Answer with y (yes), n (no), or just press Enter to skip, then add a
   note if you like. One check asks you to quit the game; the script then
   starts it again by itself.

4. At the end, quit Dot Popper. The script then tells you where its one
   results file is: dot-popper-results.txt, in this folder. Please send
   that file back to Kerrick, attached to an email or a message.

What the script records: your answers; your Windows version, graphics card
and driver, display size, scale and refresh rate, and any controllers;
what Dot Popper printed while it ran; and the files Dot Popper saves in
%APPDATA%\dot_popper (your scores and a line for each round). It changes no
setting, needs no administrator, and sends nothing anywhere. You send the
file yourself.

If something goes wrong
-----------------------

- "Windows protected your PC": Dot Popper isn't signed. Choose "More
  info", then "Run anyway", and say so in the last note.
- "Run with PowerShell" isn't there, or a red message says running scripts
  is disabled: open the Start menu, type powershell, open Windows
  PowerShell, and paste this line (with the path of this folder):
      powershell -ExecutionPolicy Bypass -File "C:\path\to\this\folder\playtest.ps1"
  This allows scripts for that one run only.
- The game freezes: press Enter in the script's window and it closes the
  game for you, then carries on.
- The script's window closes by itself: send dot-popper-results.txt
  anyway. It is written as you go, so it holds everything up to there.

Running the script again keeps the earlier results, renamed to
dot-popper-results-earlier-DATE.txt, and writes a new
dot-popper-results.txt.

To play Dot Popper on its own later, open the "Dot Popper" folder and
double-click "Dot Popper.exe".
