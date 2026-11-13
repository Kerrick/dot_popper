Dot Popper playtest kit for iPhone and iPad (experimental)
=========================================================

@BUILD@

This kit is EXPERIMENTAL. Lota 0.1.3 builds for iOS only as an
experiment (its CHANGELOG: "Experimental: under Fledge's fledge build
ios ..."). Finding
out whether it signs, installs, runs, and sounds right there is the point
of this playtest.

What is in the kit
------------------

- DotPopper-ios/: the Xcode project that `fledge build ios` (the Fledge version
  BUILD-INFO.txt names) generated, with Lota 0.1.3's iOS engine and SDL3 compiled into
  FledgeExtensions.xcframework, the Ruby runtime in FledgeRuby.xcframework,
  and the game in fledge/app. It opens in Xcode as it is.
- ios-results.txt: the questions (called ipad-results.txt in older
  kits). Fill it in as you play and send it back. It is the one file to
  return (with any screenshots).
- BUILD-INFO.txt: which commits, tools and Xcode built it.

What the Mac needs
------------------

- Xcode, the version BUILD-INFO.txt names or newer. The libraries inside
  were compiled by that Xcode, and an older one may fail to link them.
- An Apple ID. A free one works.
- Nothing else: no Ruby, Lota, Fledge or XcodeGen.

1. Unpack
---------

Double-click dot-popper-ipad-kit.zip in Finder. Finder's Archive Utility
keeps the symbolic links the frameworks inside rely on; tools that turn
links into copies, or drop them, break the build. (From the Terminal,
`ditto -x -k dot-popper-ipad-kit.zip .` does the same.) Then open
DotPopper-ios/DotPopper.xcodeproj.

2. Sign it with your Personal Team
----------------------------------

1. Xcode > Settings > Apple Accounts (Accounts in older Xcode), press +,
   and add your Apple ID. Xcode lists a team named "YOUR NAME (Personal
   Team)".
2. In the project navigator select DotPopper (the blue icon), then the
   DotPopper target, then Signing & Capabilities. Turn on "Automatically
   manage signing" and choose your Personal Team.
3. The Bundle Identifier is com.setdef.DotPopper. If Xcode says it is
   not available, change it to one of your own, such as
   com.setdef.DotPopper.playtest. Nothing else depends on it.

A free Personal Team signs for 7 days at a time, for at most 3 apps on the
device (Apple, "Choosing a membership").

3. Get the iPhone or iPad ready
-------------------------------

1. Plug the iPhone or iPad into the Mac, unlock it, tap Trust, and enter its
   passcode.
2. On the device: Settings > Privacy & Security > Developer Mode (at the
   bottom, under Security). It appears only once the device has been paired
   with a Mac running Xcode. Turn it on, restart the device, then tap Turn On
   and enter the passcode.

4. Check the scheme
-------------------

Product > Scheme > Edit Scheme, then Run > Arguments. Under Environment
Variables there should be no OS_ACTIVITY_DT_MODE, with any value. If Xcode
added it, select it and press the minus button. (Fledge 0.5.0 and later
cope with it, but the game's log lines then reach only Xcode's console.)
Leave DOT_POPPER_AUTOPLAY out too: it makes a bot play.

5. Run
------

Choose the iPhone or iPad as the run destination in the toolbar and press Run
(Command-R). Xcode builds, signs, installs and starts Dot Popper.

If the device says "Untrusted Developer": on it, open Settings > General
> VPN & Device Management, tap your Apple ID under Developer App, tap
Trust, and press Run again.

Once installed, Dot Popper is on the Home Screen and runs without the Mac
for 7 days. After that, plug the device in and press Run again; installing
over the app keeps its scores.

6. Play, and fill in ios-results.txt
------------------------------------

Open ios-results.txt on the Mac (TextEdit is fine), play on the device, and
write each answer after its arrow. The game starts on Home:
tap Play, and tap the bright dots.

If something goes wrong, send these with the results file:

- The build or signing fails: the red messages in Xcode's Issue navigator
  (Command-5), selected and copied as text.
- The app closes or freezes: Window > Devices and Simulators, select the
  device, Open Recent Logs, and the newest DotPopper entry. Or, on the device,
  Settings > Privacy & Security > Analytics & Improvements > Analytics
  Data, the newest DotPopper file, sent with its Share button.
- It looks or sounds wrong: a screenshot (the top button and a volume
  button together), and which way the device was turned.

The game's log: while Xcode runs the app, its console (Shift-Command-C)
shows lines that start with "Dot Popper:". A healthy start says "a dot's
radius is 50 points, about 8 mm". Lines that start "Dot Popper: could
not", "Dot Popper: drawing without" or "Dot Popper: playing without" mean
something failed and the game carried on: paste those into the last
question.

The game's saved files (scores, and games.csv, a line for each game):
Window > Devices and Simulators, select the device, select Dot Popper under
Installed Apps, click the ... (gear) button, and Download Container.
