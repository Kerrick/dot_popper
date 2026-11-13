#!/usr/bin/env bash
# Dot Popper's Linux playtest (PACKAGING.md, "Playtest kits").
#
# Run it from a terminal in the kit's folder: ./playtest.sh
#
# It records a few facts about this computer, starts Dot Popper with
# DOT_POPPER_PERF=1 (it then prints how smoothly it runs), asks the hand
# checks one at a time while you play, collects the game's saved files
# from ~/.local/share/dot_popper, and writes everything into one file,
# dot-popper-results.txt, beside this script. It changes no setting, needs
# no root, and writes only that file (keeping an earlier one under another
# name) and a temporary folder it removes, besides the save folder the
# game itself writes.
#
# script/playtest_kit.rb writes this file from playtest/playtest.sh and
# playtest/checks.yml, which holds the checks' words. For CI only:
# answers may come on redirected standard input, one line each.

set -u

KIT_BUILD=$(cat <<'BUILD'
@BUILD@
BUILD
)

# @CHECKS@

KIT=$(cd "$(dirname "$0")" && pwd)
RESULTS="$KIT/dot-popper-results.txt"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dot-popper-playtest.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
SESSIONS=0
GAME_PID=""
INPUT_ENDED=0

# ---------------------------------------------------------------- results

stamp() { date '+%Y-%m-%d %H:%M:%S %z'; }

# Each line goes into the results file at once, so whatever happens, what
# was recorded so far is in it.
add() { printf '%s\n' "$*" >> "$RESULTS"; }
heading() { add ""; add "== $*"; }
say() { printf '%s\n' "$*"; }

# Runs a fact-finding command; one that is missing or fails is noted.
fact() {
  local label=$1; shift
  local output
  if output=$("$@" 2>/dev/null) && [ -n "$output" ]; then
    while IFS= read -r line; do add "$label: $line"; done <<< "$output"
  else
    add "$label: could not read it ($1)"
  fi
}

# ------------------------------------------------------------------ input

# One line the player types into REPLY, or false once input has ended.
# Input redirected from a file (CI) is echoed, as if typed.
read_answer() {
  REPLY=""
  [ "$INPUT_ENDED" = 1 ] && return 1
  printf '%s ' "$1"
  if ! IFS= read -r REPLY; then INPUT_ENDED=1; say "(no more input)"; return 1; fi
  REPLY=${REPLY%$'\r'}
  [ -t 0 ] || say "$REPLY"
  return 0
}

# Asks until the answer is one that the function named $2 accepts, three
# times at most; then keeps what was typed. The value is left in VALUE.
read_choice() {
  local prompt=$1 accept=$2 try
  for try in 1 2 3; do
    if ! read_answer "$prompt"; then VALUE="not answered"; return; fi
    local typed
    typed=$(printf '%s' "$REPLY" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//; s/ *$//')
    if VALUE=$("$accept" "$typed"); then return; fi
    say "  Sorry, I did not understand that. Please try again."
  done
  VALUE="unclear: $REPLY"
}

accept_yes_no() {
  case $1 in y|yes) echo yes ;; n|no) echo no ;; ""|s|skip) echo skipped ;; *) return 1 ;; esac
}
accept_yes_no_not_shown() {
  case $1 in ns|"not shown") echo "not shown" ;; *) accept_yes_no "$1" ;; esac
}
accept_rating() {
  case $1 in [1-5]) echo "$1" ;; ""|s|skip) echo skipped ;; *) return 1 ;; esac
}
OPTIONS=()
accept_option() {
  case $1 in ""|s|skip) echo skipped; return ;; esac
  local i
  for i in "${!OPTIONS[@]}"; do
    if [ "$1" = "$((i + 1))" ] || [ "$1" = "${OPTIONS[$i]}" ]; then echo "${OPTIONS[$i]}"; return; fi
  done
  return 1
}

# Lines typed or pasted until an empty one, into LINES.
read_lines() {
  say "$1"
  LINES=()
  local i
  for i in $(seq 40); do
    read_answer "  >" || break
    [ -z "${REPLY// /}" ] && break
    LINES+=("$REPLY")
  done
}

# ------------------------------------------------------------- the game

# Starts Dot Popper with DOT_POPPER_PERF=1, its output into the work folder.
start_game() {
  SESSIONS=$((SESSIONS + 1))
  echo "$1" > "$WORK/why.$SESSIONS"
  stamp > "$WORK/started.$SESSIONS"
  (cd "$(dirname "$GAME")" && exec env DOT_POPPER_PERF=1 "$GAME" > "$WORK/out.$SESSIONS" 2> "$WORK/err.$SESSIONS" < /dev/null) &
  GAME_PID=$!
  echo "$GAME_PID" > "$WORK/pid.$SESSIONS"
  add "Dot Popper started ($1) at $(cat "$WORK/started.$SESSIONS"), session $SESSIONS"
}

game_running() { [ -n "$GAME_PID" ] && kill -0 "$GAME_PID" 2>/dev/null; }

# Starts the game again if it has closed by itself since the last check.
confirm_game_running() {
  game_running && return
  wait "$GAME_PID" 2>/dev/null
  add "Dot Popper had closed before $1 (exit code $?); the kit started it again."
  say ""
  say "Dot Popper had closed, so I am starting it again."
  start_game "again, before $1"
}

# Waits for the player to quit the game. Enter, typed here, closes it.
wait_game_exit() {
  game_running || return
  say "  Waiting for Dot Popper to close. If it is stuck, press Enter here and I will close it."
  while game_running; do
    if [ -t 0 ]; then
      if IFS= read -r -t 1 _; then
        add "The kit closed Dot Popper ($1), when asked to."
        kill "$GAME_PID" 2>/dev/null; sleep 2; kill -9 "$GAME_PID" 2>/dev/null
        break
      fi
    else
      sleep 1
    fi
  done
}

# ----------------------------------------------------------------- checks

CURRENT_ID=""
begin_check() {
  CURRENT_ID=$1
  confirm_game_running "check $1"
  say ""
  say "---- Check $1 of $LAST_ID ----"
  [ -n "$3" ] && say "Try this: $3"
  if [ "$4" = true ]; then
    wait_game_exit "for check $1"
    start_game "again, for check $1"
    say "  Dot Popper is starting again."
  fi
  say "$2"
  add ""
  add "[$1] $2"
}

# One answer: its kind, its label ("answer", or a part's words), the
# scale of a rating, and a choice's options, separated by |.
answer() {
  local kind=$1 label=$2 scale=$3
  [ "$label" != answer ] && say "  $label"
  label=${label%:}
  case $kind in
    yes_no) read_choice "  y / n / skip:" accept_yes_no ;;
    yes_no_not_shown) read_choice "  y / n / ns (not shown) / skip:" accept_yes_no_not_shown ;;
    rating) say "  $scale"; read_choice "  1 to 5 / skip:" accept_rating ;;
    choice)
      IFS='|' read -r -a OPTIONS <<< "$4"
      local i
      for i in "${!OPTIONS[@]}"; do say "  $((i + 1)). ${OPTIONS[$i]}"; done
      read_choice "  number / skip:" accept_option ;;
    paste)
      read_choice "  y / n / skip:" accept_yes_no
      read_lines "  Now paste the result here (Ctrl+Shift+V in most terminals), then press Enter on an empty line:"
      add "    $label: $VALUE"
      add "    pasted:"
      local line
      for line in "${LINES[@]}"; do add "      $line"; done
      return ;;
    *)
      read_lines "  Type your answer, then press Enter on an empty line:"
      VALUE=$(IFS='/'; printf '%s' "${LINES[*]}")
      [ -z "$VALUE" ] && VALUE="(nothing)" ;;
  esac
  add "    $label: $VALUE"
}

end_check() {
  if read_answer "  Note (optional, Enter for none):" && [ -n "${REPLY// /}" ]; then add "    note: $REPLY"; fi
  [ -n "$1" ] && say "  $1"
  return 0
}

# ------------------------------------------------------------ this computer

computer_facts() {
  heading "This computer"
  fact system sh -c '. /etc/os-release && echo "$PRETTY_NAME"'
  fact kernel uname -srm
  add "desktop: ${XDG_CURRENT_DESKTOP:-unknown}, session ${XDG_SESSION_TYPE:-unknown}, display ${WAYLAND_DISPLAY:-}${DISPLAY:+ X$DISPLAY}"
  fact processor sh -c "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //'"
  fact memory sh -c "awk '/MemTotal/ { printf \"%.1f GB\", \$2 / 1048576 }' /proc/meminfo"
  fact graphics sh -c "lspci -nnk | grep -A3 -E 'VGA|3D|Display' | grep -v -E 'Subsystem|modules'"
  fact opengl sh -c "glxinfo -B | grep -E 'OpenGL (vendor|renderer|version|core profile version)|Video memory'"
  fact nvidia cat /proc/driver/nvidia/version
  fact displays sh -c "xrandr --current | grep -E ' connected|\\*'"
  fact scale sh -c "printf 'GNOME scaling-factor %s, text-scaling-factor %s' \"\$(gsettings get org.gnome.desktop.interface scaling-factor)\" \"\$(gsettings get org.gnome.desktop.interface text-scaling-factor)\""
  fact "scale (GDK_SCALE)" printenv GDK_SCALE
  fact sound sh -c "pactl info | grep -E 'Server Name|Default Sink'"
  fact controllers sh -c "grep -E '^N: Name=' /proc/bus/input/devices | grep -i -E 'controller|gamepad|joystick|xbox|dualsense|dualshock|8bitdo|pad' | sed 's/^N: Name=//'"
  add "kit folder: $KIT"
}

# ----------------------------------------------------------- what it left

game_output() {
  local n
  for n in $(seq "$SESSIONS"); do
    local pid
    pid=$(cat "$WORK/pid.$n")
    if kill -0 "$pid" 2>/dev/null; then
      add "Dot Popper session $n was still open; the kit closed it."
      kill "$pid" 2>/dev/null; sleep 2; kill -9 "$pid" 2>/dev/null
    fi
    wait "$pid" 2>/dev/null
    local code=$?
    heading "Dot Popper's output, session $n (started $(cat "$WORK/why.$n"), at $(cat "$WORK/started.$n"))"
    add "exit code: $code"
    add "-- standard output"
    cat "$WORK/out.$n" >> "$RESULTS"
    add "-- standard error"
    cat "$WORK/err.$n" >> "$RESULTS"
  done
}

save_folder() {
  local save="${XDG_DATA_HOME:-$HOME/.local/share}/dot_popper"
  heading "The game's save folder, $save"
  if [ ! -d "$save" ]; then add "It does not exist."; return; fi
  ls -l "$save" | tail -n +2 >> "$RESULTS"
  local file
  for file in "$save"/*.csv "$save"/*.txt; do
    [ -f "$file" ] || continue
    add ""
    add "-- $(basename "$file")"
    if [ "$(wc -c < "$file")" -gt 512000 ]; then add "(too big to copy here)"; else cat "$file" >> "$RESULTS"; fi
  done
}

# ------------------------------------------------------------------ start

if [ -e "$RESULTS" ]; then mv "$RESULTS" "$KIT/dot-popper-results-earlier-$(date +%Y%m%d-%H%M%S).txt"; fi
: > "$RESULTS"

say "Dot Popper playtest"
say "==================="
say "Thank you for trying Dot Popper! This takes about 15 minutes."
say "I will start the game, then ask about one thing at a time here."
say "Answer each with y (yes), n (no), or just Enter to skip, and add a note if you like."
say "Keep this terminal beside the game, and click back into it to answer."
say ""

add "Dot Popper playtest results (Linux)"
add "started: $(stamp)"
add ""
add "The kit:"
while IFS= read -r line; do add "  $line"; done <<< "$KIT_BUILD"

say "First, a few facts about this computer (graphics, display, controllers)..."
computer_facts

GAME=$(find "$KIT" -maxdepth 3 -type f -name 'Dot Popper' -perm -u+x 2>/dev/null | head -1)
if [ -z "$GAME" ]; then
  add ""
  add "Dot Popper is not in the kit folder, $KIT."
  say "I can't find Dot Popper in this folder. Please unpack the whole kit and try again."
else
  add "game: $GAME"
  HAS_PAD=no
  if [ -n "${CONTROLLER_IDS// /}" ]; then
    say ""
    say "Do you have a game controller (Xbox, PlayStation, or similar) connected to this computer?"
    read_choice "  y / n:" accept_yes_no
    HAS_PAD=$VALUE
    add "controller to play with (the player's answer): $HAS_PAD"
  fi
  ASKED=()
  for id in "${CHECK_IDS[@]}"; do
    case $CONTROLLER_IDS in *" $id "*) [ "$HAS_PAD" = yes ] || continue ;; esac
    ASKED+=("$id")
  done
  LAST_ID=${ASKED[${#ASKED[@]} - 1]}

  say ""
  say "Starting Dot Popper now. Its window opens in a moment."
  heading "Hand checks"
  start_game "for the hand checks"
  for id in "${ASKED[@]}"; do "check_$id"; done
  if [ "$HAS_PAD" != yes ]; then
    for id in $CONTROLLER_IDS; do add ""; add "[$id] (a controller check)"; add "    answer: not asked (no controller)"; done
  fi

  say ""
  say "That was the last question. Now please quit Dot Popper (Escape on Home, or close its window)."
  wait_game_exit "after the checks"
  say "Collecting what the game printed and saved..."
  game_output
  save_folder
fi

add ""
add "finished: $(stamp)"

say ""
say "=================================================================="
say "All done. Thank you!"
say ""
say "Your answers, and everything the kit recorded, are in this one file:"
say ""
say "    $RESULTS"
say ""
say "Please send that file back to Kerrick: attach it to an email or a message."
say "=================================================================="
if [ -t 0 ] && command -v xdg-open > /dev/null; then xdg-open "$KIT" > /dev/null 2>&1 & fi
exit 0
