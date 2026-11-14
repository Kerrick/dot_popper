#!/usr/bin/env bash
# The Android emulator checks (.github/android_emulator_checks.sh) on the
# app this commit builds, on any Linux x86_64 computer with KVM:
#
#   MISE_ENV=android mise install                      # once: the JDK, CMake and Ninja
#   MISE_ENV=android mise exec -- script/android_check.sh [OUT]
#
# It checks the commit at HEAD, as script/android_build.sh builds it, and
# keeps each run's logs, game lines and screenshots in OUT (default
# tmp/android/check). It exits 0 only if every check passed.
# ANDROID_CHECKS names the only checks to run, such as "back-on-title",
# and ANDROID_CHECK_TIMES runs them that many times on one emulator.
#
# It is fast after its first run on a computer, because it rebuilds and
# boots only what changed:
#
# - The app. Of all the app holds, only the game's own files
#   (script/android_game.sh) come from the game, and they sit, stored, in
#   one asset, fledge.zip. So the first build for a set of the app's other
#   inputs (the build scripts, android/host, fledge.yml and the icons,
#   the pinned tools, and LOTA_REF and FLEDGE_TAG) is a full one, kept in
#   the cache under a key made of all of them; a later commit with the
#   same inputs gets that app with its own game laid in
#   (script/android_patch_apk.rb), aligned and signed as Gradle would.
#   ANDROID_CHECK_FULL_BUILD=1 always builds in full, and
#   ANDROID_CHECK_VERIFY=1 builds in full and also patches, and fails
#   unless the two apps hold the same files.
# - The emulator. An x86_64 API 33 emulator is booted cold once for each
#   set of pinned emulator pieces and settings, left to settle, and saved
#   as a snapshot in the cache. Each run boots read-only from that
#   snapshot, so it writes nothing there, and its own changes go to its
#   own folder, which is deleted when it ends.
#
# The emulator and its adb server run on ports of the run's own, so
# several runs can share a computer, and both end with the script, as
# does everything else it starts. The cache is
# ${XDG_CACHE_HOME:-~/.cache}/dot_popper.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"
out=$(realpath -m "${1:-$repo/tmp/android/check}")
cache=${XDG_CACHE_HOME:-$HOME/.cache}/dot_popper
keep=$cache/android-check
mkdir -p "$keep" "$repo/tmp/android"
run=$(mktemp -d "$repo/tmp/android/check-run.XXXXXX")
started=$(date +%s.%N)
say() { awk -v t="$started" -v now="$(date +%s.%N)" -v m="$*" 'BEGIN { printf "android check: %s (%.0f s)\n", m, now - t }'; }

export LOTA_REPOSITORY=${LOTA_REPOSITORY:-https://github.com/setdef/Lota.git}
export LOTA_REF=${LOTA_REF:-v0.3.1} FLEDGE_TAG=${FLEDGE_TAG:-v0.10.0}

emulator_pid=
cleanup() {
  status=$?
  if [ -n "$emulator_pid" ]; then
    adb emu kill > /dev/null 2>&1 || true
    for _ in $(seq 20); do kill -0 "$emulator_pid" 2> /dev/null || break; sleep 0.5; done
    kill -- -"$emulator_pid" 2> /dev/null || true
    sleep 1
    kill -9 -- -"$emulator_pid" 2> /dev/null || true
  fi
  [ -n "${ANDROID_ADB_SERVER_PORT:-}" ] && adb kill-server > /dev/null 2>&1 || true
  rm -rf "$run"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

ANDROID_HOME=$(script/android_sdk.sh --emulator | sed -n 's/^ANDROID_HOME=//p')
[ -n "$ANDROID_HOME" ] || { echo "script/android_sdk.sh gave no SDK" >&2; exit 1; }
export ANDROID_HOME ANDROID_SDK_ROOT=$ANDROID_HOME
tools=$ANDROID_HOME/build-tools/36.0.0
export PATH=$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
say "the SDK and the emulator's pieces are in place"

# What a full build of the app is made from, other than the game's own
# files, as of HEAD.
app_key() {
  {
    echo "$LOTA_REPOSITORY $LOTA_REF $FLEDGE_TAG ${LOTA_SOURCE:-}"
    git rev-parse HEAD:script/android_build.sh HEAD:script/android_sdk.sh HEAD:script/android_game.sh \
      HEAD:mise.android.toml HEAD:.ruby-version HEAD:android/host HEAD:fledge.yml HEAD:icons
    java -version 2>&1 | head -1
  } | sha256sum | cut -c1-16
}

apk=$run/DotPopper-debug.apk
base=$keep/app-$(app_key).apk
full_build() {
  script/android_build.sh > "$run/build.log" 2>&1 || { tail -60 "$run/build.log"; exit 1; }
  cp tmp/android/out/DotPopper-debug.apk "$1"
}
patch_app() {
  local project=$run/project
  script/android_game.sh "$project"
  ruby script/android_patch_apk.rb "$base" "$project" "$run/unaligned.apk"
  "$tools/zipalign" -P 16 -f 4 "$run/unaligned.apk" "$run/aligned.apk"
  local key=$keep/debug.keystore
  if [ ! -f "$key" ]; then
    keytool -genkeypair -keystore "$key.$$" -storepass android -keypass android -alias androiddebugkey \
      -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" > /dev/null 2>&1
    mv "$key.$$" "$key"
  fi
  "$tools/apksigner" sign --ks "$key" --ks-pass pass:android --key-pass pass:android --out "$1" "$run/aligned.apk"
  rm -f "$run/unaligned.apk" "$run/aligned.apk"
}
if [ "${ANDROID_CHECK_VERIFY:-}" = 1 ]; then
  full_build "$apk"
  [ -f "$base" ] || cp "$apk" "$base"
  patch_app "$run/patched.apk"
  ruby script/android_patch_apk.rb --same "$apk" "$run/patched.apk"
  say "the patched app holds the same files as the full build"
elif [ -f "$base" ] && [ "${ANDROID_CHECK_FULL_BUILD:-}" != 1 ] && [ -z "${LOTA_SOURCE:-}" ]; then
  patch_app "$apk"
  say "the app: this commit's game laid into $(basename "$base")"
else
  full_build "$apk"
  if [ -z "${LOTA_SOURCE:-}" ]; then cp "$apk" "$base.$$" && mv "$base.$$" "$base"; fi
  say "the app: built in full"
fi
ls -t "$keep"/app-*.apk 2> /dev/null | tail -n +4 | xargs -r rm -f # the last three sets of inputs

# The emulator, from a snapshot saved after a cold boot, keyed by the
# pinned pieces (script/android_sdk.sh) and the settings below.
SYSTEM_IMAGE="system-images;android-33;google_apis;x86_64"
EMULATOR_FLAGS=(-no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -memory 4096 -cores 4)
avd_key=$({ git rev-parse HEAD:script/android_sdk.sh; echo "$SYSTEM_IMAGE ${EMULATOR_FLAGS[*]} settled-1"; } | sha256sum | cut -c1-16)
avd_home=$keep/avd-$avd_key
pick_ports() {
  export ANDROID_ADB_SERVER_PORT=$((7100 + RANDOM % 800))
  port=$((5600 + 2 * (RANDOM % 150)))
  export ANDROID_SERIAL=emulator-$port
}
start_emulator() { # LOG FLAGS...
  local log=$1; shift
  ANDROID_AVD_HOME=$avd_home setsid emulator -avd checks -port "$port" "${EMULATOR_FLAGS[@]}" "$@" > "$log" 2>&1 &
  emulator_pid=$!
  timeout 300 adb wait-for-device || { tail -30 "$log"; exit 1; }
  local waited=0
  until [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = 1 ]; do
    [ $waited -lt 600 ] || { echo "not booted in 300 s"; tail -30 "$log"; exit 1; }
    sleep 0.5; waited=$((waited + 1))
  done
}
stop_emulator() {
  adb emu kill > /dev/null 2>&1 || true
  wait "$emulator_pid" 2> /dev/null || true
  emulator_pid=
  adb kill-server > /dev/null 2>&1 || true
}
export ANDROID_USER_HOME=$run/android-user ANDROID_EMULATOR_HOME=$run/android-user TMPDIR=$run
mkdir -p "$ANDROID_USER_HOME"
exec 7> "$keep/avd.lock"
flock 7
if [ ! -f "$avd_home/.complete" ]; then
  say "making the emulator's snapshot"
  rm -rf "$avd_home"
  mkdir -p "$avd_home"
  echo no | ANDROID_AVD_HOME=$avd_home avdmanager create avd --force -n checks -k "$SYSTEM_IMAGE" > "$run/avd.log" 2>&1 ||
    { tail -20 "$run/avd.log"; exit 1; }
  pick_ports
  start_emulator "$run/emulator-cold.log" -no-snapshot-load
  say "booted cold"
  # Android's one-time notice for an app that hides the system bars would
  # take the first tap (Fledge's ADR 025, section 6).
  adb shell settings put secure immersive_mode_confirmations confirmed
  for scale in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb shell settings put global "$scale" 0
  done
  # A just-booted Android compiles and updates for minutes; a snapshot
  # taken then would bring that work into every run.
  for _ in $(seq 60); do
    load=$(adb shell cat /proc/loadavg | cut -d' ' -f1)
    awk -v l="$load" 'BEGIN { exit !(l < 1.5) }' && break
    sleep 5
  done
  say "settled, load $load"
  adb emu avd snapshot save checks > /dev/null
  stop_emulator
  touch "$avd_home/.complete"
fi
flock -u 7
say "the emulator's snapshot is ready"

pick_ports
start_emulator "$run/emulator.log" -read-only -snapshot checks -no-snapshot-save
say "booted from the snapshot"

rm -rf "$out"
mkdir -p "$out"
# ANDROID_CHECK_TIMES runs the checks that many times on this emulator,
# each into a folder of its own, to find a check that fails only now
# and then.
times=${ANDROID_CHECK_TIMES:-1}
failed=0
for time in $(seq "$times"); do
  into=$out
  [ "$times" = 1 ] || into=$out/$time
  mkdir -p "$into"
  passed=true
  bash .github/android_emulator_checks.sh "$apk" "$into" > "$into/checks.log" 2>&1 || passed=false
  grep -E "^\S+ (missing|never sent|the kit probe failed|timed out|the app's process is gone|every expectation met|exited)" \
    "$into/checks.log" || true
  for check in "$into"/*/; do
    echo "== $(basename "$check"): $(tail -1 "$check/app.txt" 2> /dev/null)"
  done
  if ! $passed; then
    failed=$((failed + 1))
    tail -60 "$into/checks.log"
  fi
  [ "$times" = 1 ] || say "time $time: $($passed && echo passed || echo FAILED)"
done
if [ $failed = 0 ]; then
  say "every check passed$([ "$times" = 1 ] || echo ", $times times out of $times")"
else
  say "a check failed$([ "$times" = 1 ] || echo " $failed times out of $times") (logs in $out)"
  exit 1
fi
