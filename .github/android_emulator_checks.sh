#!/usr/bin/env bash
# The Android job's emulator checks (.github/workflows/android.yml), one
# run of android_emulator.rb after another, each into a folder of its own
# under OUT. All of them run; the script fails if any did. Every run
# passes ALSOFT_DRIVERS=null, so OpenAL Soft opens no sound device.
#
#   android_emulator_checks.sh APK OUT
set -uo pipefail
apk=$1
out=$2
here=$(cd "$(dirname "$0")" && pwd)
package=com.setdef.DotPopper
status=0

# The bot plays for 90 seconds, for a bonus dot can stretch its first round. Back during its first round and at its
# first Game Over must do nothing: the game carries on to the title and
# quits only when DOT_POPPER_QUIT_AFTER says.
ruby "$here/android_emulator.rb" "$apk" "$package" "$out/autoplay" \
  --env DOT_POPPER_AUTOPLAY=1 --env DOT_POPPER_SEED=7 --env DOT_POPPER_QUIT_AFTER=90 --env ALSOFT_DRIVERS=null \
  --env DOT_POPPER_SAVE_AS=ci_autoplay --env DOT_POPPER_SHOTS=3,12,25,38 --env DOT_POPPER_KIT_PROBE=1 \
  --ready "Dot Popper: " --shot 5 --shot 20 --timeout 300 --pull "Dot Popper: screenshot (\\S+)" \
  --key-after "3:KEYCODE_BACK:kit probe: event RoundStarted" \
  --key-after "1:KEYCODE_BACK:kit probe: event RoundEnded" \
  --expect "Dot Popper: a dot's radius is 50 dp, about 8 mm" --expect "Dot Popper: screenshot" \
  --expect-order "kit probe: keypressed :escape, :acback, false in Playing" \
  --expect-order "kit probe: event RoundEnded" \
  --expect-order "kit probe: keypressed :escape, :acback, false in GameOver" \
  --expect-order "kit probe: event TitleShown" \
  --expect-order "exited with status 0" || status=1

# Back on the title leaves the app: Dot Popper quits itself
# (Lota::Event.quit), with no DOT_POPPER_QUIT_AFTER to do it instead.
# Back waits for the setdef splash to be over, since a key during it only
# skips it: the splash lasts 3.5 s of the game's time, and on a slow
# runner that was more than the 4 s of the clock this once waited.
ruby "$here/android_emulator.rb" "$apk" "$package" "$out/back-on-title" \
  --env ALSOFT_DRIVERS=null --env DOT_POPPER_SAVE_AS=ci_back --env DOT_POPPER_KIT_PROBE=1 \
  --ready "kit probe: subscribed" --shot 2 --timeout 90 \
  --key-after "1:KEYCODE_BACK:kit probe: splash over" \
  --expect "Dot Popper: a dot's radius is 50 dp, about 8 mm" \
  --expect-order "kit probe: splash over" \
  --expect-order "kit probe: keypressed :escape, :acback, false in Title" \
  --expect-order "exited with status 0" || status=1

exit $status
