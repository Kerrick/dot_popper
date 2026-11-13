#!/usr/bin/env bash
# Builds Dot Popper's EXPERIMENTAL Android app from this checkout
# (PACKAGING.md, "The Android kit"), by the Android route of Lota's
# doc/guide/phones.md, into tmp/android/out/DotPopper-debug.apk:
#
#   MISE_ENV=android mise install    # once: the JDK, CMake and Ninja
#   script/android_build.sh          # the debug APK
#   script/android_build.sh --bundle # and the release App Bundle, for Google Play
#
# Linux on x86_64 only. The Android SDK and NDK come from
# script/android_sdk.sh. Lota is cloned at LOTA_REF (default v0.3.1) into
# the cache, unless LOTA_SOURCE names a clone already made, and its
# rake android:deps builds LÖVE's libraries and SDL3 for arm64-v8a and
# x86_64 there, once for each Lota commit. Then:
#
# 1. the files Lota's gem packages, built and unpacked from the clone,
#    become a path gem, since Fledge carries a path gem's whole folder
#    into the app;
# 2. a phone project, laid out as the guide lays it out, holds the game in
#    game/dot_popper, the kit's program (android/android_kit) as main.rb,
#    and Lota's Android host from the gem in host/android, with Dot
#    Popper's changed files (android/host) over it;
# 3. fledge build android (Fledge FLEDGE_TAG) writes the Gradle project,
#    and Gradle builds the debug APK, signed with a debug key made for
#    this build, and with --bundle the unsigned release App Bundle.
#
# The cache is ${XDG_CACHE_HOME:-~/.cache}/dot_popper; builds sharing it
# take turns. Gradle may download nothing the SDK lacks.
set -euo pipefail

LOTA_REPOSITORY=${LOTA_REPOSITORY:-https://github.com/setdef/Lota.git}
LOTA_REF=${LOTA_REF:-v0.3.1}
FLEDGE_TAG=${FLEDGE_TAG:-v0.10.0}
APP_NAME="Dot Popper"

bundle_too=false
case "${1:-}" in
  "") ;;
  --bundle) bundle_too=true ;;
  *) echo "usage: script/android_build.sh [--bundle]" >&2; exit 2 ;;
esac

repo=$(cd "$(dirname "$0")/.." && pwd)
cache=${XDG_CACHE_HOME:-$HOME/.cache}/dot_popper
work=$repo/tmp/android
out=$work/out
mkdir -p "$cache" "$work"
exec 8> "$cache/android-build.lock"
command -v flock > /dev/null && flock 8

ANDROID_HOME=$("$repo/script/android_sdk.sh" | sed -n 's/^ANDROID_HOME=//p')
export ANDROID_HOME ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/30.0.16248370
# Gradle's own downloads stay in the cache, and its debug key and Android's
# other per-user files in this build's folder, made afresh each time.
export GRADLE_USER_HOME=${GRADLE_USER_HOME:-$cache/gradle}
export ANDROID_USER_HOME=$work/android-user
rm -rf "$ANDROID_USER_HOME" "$out"
mkdir -p "$ANDROID_USER_HOME" "$out"

# Lota at LOTA_REF, with LÖVE's sources, and LÖVE's libraries built for Android.
if [ -z "${LOTA_SOURCE:-}" ]; then
  LOTA_SOURCE=$cache/lota-${LOTA_REF//[^A-Za-z0-9._-]/_}
  if [ ! -f "$LOTA_SOURCE/.cloned" ]; then
    rm -rf "$LOTA_SOURCE"
    git init --quiet "$LOTA_SOURCE"
    git -C "$LOTA_SOURCE" remote add origin "$LOTA_REPOSITORY"
    git -C "$LOTA_SOURCE" fetch --quiet --depth 1 origin "$LOTA_REF"
    git -C "$LOTA_SOURCE" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
    git -C "$LOTA_SOURCE" submodule update --quiet --init --depth 1 vendor/love
    touch "$LOTA_SOURCE/.cloned"
  fi
fi
echo "Lota $LOTA_REF: $(git -C "$LOTA_SOURCE" log --oneline -1)"
export BUNDLE_PATH=$cache/lota-bundle
(cd "$LOTA_SOURCE" && BUNDLE_GEMFILE=$LOTA_SOURCE/Gemfile bundle install --quiet)
RICE_DIR=$(cd "$LOTA_SOURCE" && BUNDLE_GEMFILE=$LOTA_SOURCE/Gemfile bundle info rice --path)
# rake android:deps skips the build when its recipe and the NDK have not changed.
(cd "$LOTA_SOURCE" && BUNDLE_GEMFILE=$LOTA_SOURCE/Gemfile bundle exec rake android:deps > "$out/deps.log" 2>&1) ||
  { tail -80 "$LOTA_SOURCE/tmp/android/deps/build.log" "$out/deps.log"; exit 1; }

# A gem named by its path carries its whole folder into the app, so the
# project names a folder of only what Lota's gem packages.
(
  cd "$LOTA_SOURCE"
  rm -rf tmp/phone && mkdir -p tmp/phone
  gem build lota.gemspec --output tmp/phone/lota.gem > /dev/null
  gem unpack tmp/phone/lota.gem --target tmp/phone > /dev/null
  gem specification tmp/phone/lota.gem --ruby > tmp/phone/lota/lota.gemspec
)
LOTA_GEM=$LOTA_SOURCE/tmp/phone/lota

# The phone project of Lota's guide: everything in it but the hosts goes
# into the app, so the game's copy leaves out what only the repository
# needs (script/android_game.sh). Dot Popper's android/host (its manifest, which traps Back, a
# MainActivity that takes the emulator checks' settings, and Play
# Billing's Gradle settings) goes over Lota's host, which brings SDL's
# Java classes.
phone=$work/phone
rm -rf "$phone"
"$repo/script/android_game.sh" "$phone"
cp -R "$LOTA_GEM/ext/lota/phone/host" "$phone/host"
rm -rf "$phone/host/ios"
cp -R "$repo/android/host/." "$phone/host/android/"
# Lota's rake android:notices writes the phone project's NOTICES.txt at its
# top, two folders above the game, where the Credits screen looks
# (Shell::NoticeFiles), and copies OpenAL Soft's source, which its LGPL
# asks the app to carry, into the project's sources folder.
(cd "$LOTA_SOURCE" && BUNDLE_GEMFILE=$LOTA_SOURCE/Gemfile bundle exec rake "android:notices[$phone]" > /dev/null)
cat > "$phone/Gemfile" <<EOF
# frozen_string_literal: true

# Written by script/android_build.sh for fledge build android.
source "https://rubygems.org"

gem "lota", path: "$LOTA_GEM"
gem "fledge", git: "https://github.com/setdef/Fledge", tag: "$FLEDGE_TAG", group: :development
EOF
APP_NAME=$APP_NAME ruby -ryaml -e '
  source = YAML.load_file(ARGV[1])
  program = source.fetch("programs").first
  config = {
    "name" => ENV.fetch("APP_NAME"),
    "identifier" => program.fetch("identifier"),
    "version" => source.fetch("version"),
    "icon" => File.join("game/dot_popper", program.fetch("icon")),
    "android" => { "host" => "host/android" }
  }
  File.write(ARGV[0], "# Written by script/android_build.sh for fledge build android, from fledge.yml.\n" + YAML.dump(config))
' "$phone/fledge.yml" "$repo/fledge.yml"

# fledge build android, then Gradle.
(
  cd "$phone"
  export BUNDLE_GEMFILE=$phone/Gemfile BUNDLE_PATH=$cache/android-app-bundle
  bundle config set --local build.lota \
    "--with-lota-source=$LOTA_SOURCE --with-lota-android-deps=$LOTA_SOURCE/tmp/android/deps --with-rice-dir=$RICE_DIR"
  bundle lock --add-platform ruby > /dev/null
  bundle install --quiet
  bundle exec fledge build android > "$out/fledge.log" 2>&1 || { tail -60 "$out/fledge.log"; exit 1; }
  cd "dist/$APP_NAME-android"
  # The SDK is script/android_sdk.sh's, pinned: Gradle may not add to it.
  gradle=(./gradlew --no-daemon --quiet -Pandroid.builder.sdkDownload=false)
  "${gradle[@]}" assembleDebug
  cp build/outputs/apk/debug/*.apk "$out/DotPopper-debug.apk"
  if $bundle_too; then
    # Google Play takes an App Bundle, not an APK. Fledge's Gradle project
    # leaves a release unsigned, for the next step to sign.
    "${gradle[@]}" bundleRelease
    cp build/outputs/bundle/release/*.aab "$out/DotPopper-release.aab"
  fi
)
ls -la "$out"
