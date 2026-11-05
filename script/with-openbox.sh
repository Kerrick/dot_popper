#!/usr/bin/env bash
# Runs a command on an X display with Openbox managing its windows, as
# the GUI workflow runs rake test:gui under xvfb-run: Openbox starts
# first, and the command once Openbox has taken the screen.
set -euo pipefail

openbox &
for _ in $(seq 100); do
  xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q window && break
  sleep 0.1
done
exec "$@"
