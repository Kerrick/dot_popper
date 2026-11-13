#!/usr/bin/env bash
# Runs a command on an X display with Openbox managing its windows, as
# the GUI workflow runs rake test:gui under xvfb-run: Openbox starts
# first, and the command once Openbox has taken the screen, which it says
# by running its --startup command. Without a window manager no window
# goes fullscreen, and the fullscreen scenarios would fail as if the game
# were at fault, so this fails instead, with Openbox's own words, if
# Openbox has not taken the screen within WAIT seconds. How long it takes
# is the system's, not the game's: a fraction of a second when idle.
set -euo pipefail

WAIT=60
folder=$(mktemp -d)
trap 'rm -rf "$folder"' EXIT

openbox --startup "touch '$folder/ready'" > "$folder/openbox.log" 2>&1 &
openbox=$!
for _ in $(seq $((WAIT * 10))); do
  [ -e "$folder/ready" ] && break
  kill -0 "$openbox" 2> /dev/null || break
  sleep 0.1
done
if [ ! -e "$folder/ready" ]; then
  echo "with-openbox.sh: Openbox ended, or did not take the screen within $WAIT seconds:" >&2
  cat "$folder/openbox.log" >&2
  kill "$openbox" 2> /dev/null || true
  exit 1
fi

status=0
"$@" || status=$?
if ! kill -0 "$openbox" 2> /dev/null; then
  echo "with-openbox.sh: Openbox ended while the command ran:" >&2
  cat "$folder/openbox.log" >&2
fi
kill "$openbox" 2> /dev/null || true
exit "$status"
