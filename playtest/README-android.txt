Dot Popper playtest kit for Android (EXPERIMENTAL)
==================================================

@BUILD@

This kit is EXPERIMENTAL. No released Lota builds for Android. This APK
is built from Lota's unreleased commit 84c0eda (its experiment/android-spike
branch), copied into Dot Popper's CI at our own risk. CI has run it only
on an x86_64 emulator. Its arm64-v8a code, the code your phone runs, has
never run anywhere: your phone is its first run. It may fail. If it does,
that is still useful: send the log (see "If it closes at launch").

What is in the kit
------------------

- DotPopper-debug.apk: the game, for arm64-v8a phones and x86_64
  emulators, signed with a debug key made fresh for each CI run. It needs
  Android 8 (API 26) or newer; CI ran it on an Android 13 emulator.
- android-results.txt: the questions. Fill it in as you play and send it
  back. It is the one file to return (with any screenshots or log).
- README.txt: this file.

The first launch takes a few seconds longer: the app unpacks its Ruby and
the game into its own storage once per installed version.

Way 1: install with adb from a computer (recommended: it gives you a log)
--------------------------------------------------------------------------

1. On the phone: Settings > About device > Version, tap "Build number"
   seven times, and enter your PIN. "You are now a developer" appears.
2. Settings > System settings > Developer options: turn on "USB debugging".
3. On the computer, install Android's platform tools, which hold adb:
   https://developer.android.com/tools/releases/platform-tools
   (On a Mac with Homebrew: brew install android-platform-tools.)
4. Plug the phone in by USB. On the phone, allow USB debugging for this
   computer when it asks (tick "Always allow").
5. Check that adb sees it:   adb devices
   It should list one device as "device", not "unauthorized".
6. If an earlier kit's Dot Popper is installed, remove it first. Each CI
   run signs with a new debug key, so Android refuses to install over it
   (INSTALL_FAILED_UPDATE_INCOMPATIBLE):
     adb uninstall com.kerricklong.DotPopper
   This also deletes the old build's scores.
7. Install:   adb install DotPopper-debug.apk
   If Play Protect asks about an app from an unknown developer, choose
   "Install anyway" (or "More details" > "Install anyway").
8. Open "Dot Popper" from the app drawer, and play.

Way 2: copy the APK to the phone and open it
--------------------------------------------

1. Copy DotPopper-debug.apk to the phone (USB file transfer, or a cloud
   drive), and uninstall any earlier Dot Popper (long-press its icon >
   App info > Uninstall).
2. Open the APK in the Files app. Android asks to allow installs from
   that app: Settings opens; turn on "Allow from this source" ("install
   unknown apps"), go back, and tap Install.
3. If Play Protect warns, choose "Install anyway".
This way gives no log unless you also connect adb as in Way 1.

What to expect
--------------

The title screen, with dots drifting; tap Play, and tap the
bright dots. A healthy start writes "Dot Popper: a dot's radius is 50 dp,
about 8 mm" to the log. The phone buzzes briefly on a pop. Sound comes
through the media volume, and should not stop music another app plays.

Back is the game's own: on "Your records" it goes back to the title; on
the title it leaves the app; during a round and at Game Over it does
nothing, so a stray swipe never throws a round away.

To watch the game's own lines while it runs (Way 1):
  adb logcat -s com.kerricklong.DotPopper:V SDL:V

If it closes at launch
----------------------

If Dot Popper closes at once, or Android says "Dot Popper keeps stopping",
plug the phone in (Way 1) and, straight after it closes, run:
  adb logcat -d > dot-popper-logcat.txt
Send dot-popper-logcat.txt with android-results.txt. A screenshot of
anything that looks wrong helps too (power and volume down together, or
adb exec-out screencap -p > dot-popper-1.png).

To remove the app:  adb uninstall com.kerricklong.DotPopper
or long-press its icon > App info > Uninstall.
