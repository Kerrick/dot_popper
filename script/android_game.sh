#!/usr/bin/env bash
# Lays out the Ruby the Android app runs, as the phone project of Lota's
# doc/guide/phones.md holds it, in PROJECT: the game's files in
# PROJECT/game/dot_popper, less what only the repository needs, and the
# kit's program, android/android_kit, as PROJECT/main.rb.
#
#   script/android_game.sh PROJECT             the commit at HEAD (script/android_build.sh)
#   script/android_game.sh --worktree PROJECT  the files as they are now, committed or
#                                              not, that git does not ignore (test/android)
#
# This is the one place that says which of the game's files the app
# carries, so the build and the tests that load the app's game agree.
set -euo pipefail

worktree=false
if [ "${1:-}" = --worktree ]; then
  worktree=true
  shift
fi
[ $# = 1 ] || { echo "usage: script/android_game.sh [--worktree] PROJECT" >&2; exit 2; }
repo=$(cd "$(dirname "$0")/.." && pwd)
project=$1
game=$project/game/dot_popper

rm -rf "$game"
mkdir -p "$game"
if $worktree; then
  (
    cd "$repo"
    git ls-files -z --cached --others --exclude-standard |
      while IFS= read -r -d '' file; do [ -e "$file" ] && printf '%s\0' "$file"; done |
      tar --null -T - -cf -
  ) | tar -x -C "$game"
else
  git -C "$repo" archive HEAD | tar -x -C "$game"
fi
(cd "$game" && rm -rf .github vendor android ios macos windows test doc playtest script sig server Steepfile Rakefile \
  Gemfile Gemfile.lock mise.toml mise.android.toml .ruby-version AGENTS.md GLOSSARY.md INSIPIRATION.md PACKAGING.md README.md)
if $worktree; then
  cp "$repo/android/android_kit" "$project/main.rb"
else
  git -C "$repo" show HEAD:android/android_kit > "$project/main.rb"
fi
