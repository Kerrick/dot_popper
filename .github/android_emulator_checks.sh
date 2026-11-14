#!/usr/bin/env bash
# The Android job's emulator checks (.github/workflows/android.yml), one
# run of android_emulator.rb after another, each into a folder of its own
# under OUT. All of them run; the script fails if any did. Every run
# passes ALSOFT_DRIVERS=null, so OpenAL Soft opens no sound device.
# ANDROID_CHECKS, when set, names the only checks to run, such as
# "back-on-title foreground".
#
#   android_emulator_checks.sh APK OUT
set -uo pipefail
apk=$1
out=$2
here=$(cd "$(dirname "$0")" && pwd)
package=com.setdef.DotPopper
status=0
wanted() { [ -z "${ANDROID_CHECKS:-}" ] || [[ " $ANDROID_CHECKS " == *" $1 "* ]]; }

# The bot plays its first game. Back during it and at its Game Over must
# do nothing but go on: the game carries on to Home. The run ends there
# (--until-met); DOT_POPPER_QUIT_AFTER only makes sure the game ends if
# it never gets there, since a bonus dot can stretch a game.
if wanted autoplay; then
  ruby "$here/android_emulator.rb" "$apk" "$package" "$out/autoplay" \
  --env DOT_POPPER_AUTOPLAY=1 --env DOT_POPPER_SEED=7 --env DOT_POPPER_QUIT_AFTER=120 --env ALSOFT_DRIVERS=null \
  --env DOT_POPPER_SAVE_AS=ci_autoplay --env DOT_POPPER_SHOTS=3,12,25,38 --env DOT_POPPER_KIT_PROBE=1 --env DOT_POPPER_PERF=1 \
  --ready "Dot Popper: " --shot 5 --shot 20 --timeout 300 --pull "Dot Popper: screenshot (\\S+)" --until-met \
  --key-after "3:KEYCODE_BACK:kit probe: event GameStarted" \
  --key-after "1:KEYCODE_BACK:kit probe: event GameEnded" \
  --expect "Dot Popper: a dot's radius is 50 dp, about 8 mm" --expect "Dot Popper: screenshot" --expect "Dot Popper: Ed25519 verifies the server's test vector" \
  --expect-order "kit probe: keypressed :escape, :acback, false in Playing" \
  --expect-order "kit probe: event GameEnded" \
  --expect-order "kit probe: keypressed :escape, :acback, false in GameOver" \
  --expect-order "kit probe: event HomeShown" || status=1
fi

# Back on Home leaves the app: Dot Popper quits itself
# (Lota::Event.quit), with no DOT_POPPER_QUIT_AFTER to do it instead.
# DOT_POPPER_AUTOMATED keeps it off the internet, as every automated run
# is (DotPopper::Automation): reaching the real server, it was told of a
# new theme, and Back answered that card instead of leaving.
# Back waits for the setdef splash to be over, since a key during it only
# skips it: the splash lasts 3.5 s of the game's time, and on a slow
# runner that was more than the 4 s of the clock this once waited.
if wanted back-on-title; then
  ruby "$here/android_emulator.rb" "$apk" "$package" "$out/back-on-title" \
  --env ALSOFT_DRIVERS=null --env DOT_POPPER_SAVE_AS=ci_back --env DOT_POPPER_KIT_PROBE=1 --env DOT_POPPER_AUTOMATED=1 \
  --ready "kit probe: subscribed to the cabinet" --shot 2 --timeout 90 \
  --key-after "1:KEYCODE_BACK:kit probe: splash over" \
  --expect "Dot Popper: a dot's radius is 50 dp, about 8 mm" \
  --expect-order "kit probe: splash over" \
  --expect-order "kit probe: keypressed :escape, :acback, false in Home" \
  --expect-order "exited with status 0" || status=1
fi

# Leaving for the launcher and coming back reaches the game as the
# window's focus, lost and then gained, which Refresh hears as the game
# coming back (DotPopper::Refresh), so a theme released meanwhile is
# asked for. DOT_POPPER_AUTOMATED keeps it off the internet, so nothing
# is asked of a server; the check is that the game hears it. Back on
# Home then leaves the app, as after a launch.
if wanted foreground; then
  ruby "$here/android_emulator.rb" "$apk" "$package" "$out/foreground" \
  --env ALSOFT_DRIVERS=null --env DOT_POPPER_SAVE_AS=ci_foreground --env DOT_POPPER_KIT_PROBE=1 --env DOT_POPPER_AUTOMATED=1 \
  --ready "kit probe: splash over" --timeout 120 \
  --key-after "2:KEYCODE_HOME:kit probe: splash over" \
  --shell "6:am start -n PACKAGE/org.setdef.fledge.host.MainActivity" \
  --key-after "1:KEYCODE_BACK:kit probe: the game heard it came back" \
  --expect-order "kit probe: splash over" \
  --expect-order "kit probe: focus false" \
  --expect-order "kit probe: focus true" \
  --expect-order "kit probe: the game heard it came back" \
  --expect-order "kit probe: keypressed :escape, :acback, false in Home" \
  --expect-order "exited with status 0" || status=1
fi

exit $status
