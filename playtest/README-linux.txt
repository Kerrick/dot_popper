Dot Popper playtest kit for Linux
=================================

@BUILD@

Thank you for playtesting Dot Popper! This takes about 15 minutes.

The game is built for x86-64 Linux with glibc 2.39 or newer (Ubuntu 24.04,
Pop!_OS 24.04, Debian 13, Fedora 40, or newer).

1. Unpack the whole kit: right-click dot-popper-linux-kit.tar.gz and choose
   "Extract Here" (or run: tar -xzf dot-popper-linux-kit.tar.gz). Open the
   dot-popper-linux-kit folder it makes.

2. Right-click inside the folder, choose "Open in Terminal", and type:

       ./playtest.sh

   then press Enter.

3. The script starts Dot Popper by itself. Keep the terminal beside the
   game. For each check it says what to try, then asks one question.
   Answer with y (yes), n (no), or just press Enter to skip, then add a
   note if you like. One check asks you to quit the game; the script then
   starts it again by itself.

4. At the end, quit Dot Popper. The script then tells you where its one
   results file is: dot-popper-results.txt, in this folder. Please send
   that file back to Kerrick, attached to an email or a message.

What the script records: your answers; your Linux version, desktop and
session (Wayland or X11), graphics card, OpenGL driver, displays and their
refresh rates and scale, sound server, and any controllers; what Dot
Popper printed while it ran; and the files Dot Popper saves in
~/.local/share/dot_popper (your scores and a line for each round). It
changes no setting, needs no root, and sends nothing anywhere. You send
the file yourself.

If something goes wrong
-----------------------

- "Permission denied": run it as   bash playtest.sh   instead.
- Some facts say "could not read it": a tool such as glxinfo (in the
  mesa-utils package) or xrandr isn't installed. That's fine.
- The game freezes: press Enter in the terminal and it closes the game for
  you, then carries on.
- The terminal closes by itself: send dot-popper-results.txt anyway. It is
  written as you go, so it holds everything up to there.

Running the script again keeps the earlier results, renamed to
dot-popper-results-earlier-DATE.txt, and writes a new
dot-popper-results.txt.

To play Dot Popper on its own later, open the "Dot Popper" folder and run
"Dot Popper" in it.
