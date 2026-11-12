#!/usr/bin/env bash
# Installs the Android SDK the Android build needs (script/android_build.sh),
# from pinned downloads, and prints its folder as its last line:
#
#   ANDROID_HOME=/home/you/.cache/dot_popper/android-sdk-<pins>
#
#   script/android_sdk.sh             the platform, build tools and NDK
#   script/android_sdk.sh --emulator  also adb, the emulator and an API 33 image
#
# Linux on x86_64 only, with a JDK on PATH (MISE_ENV=android mise install
# gives one). Google's command-line tools come from their zip at a pinned
# version, checked against the SHA-256 below; sdkmanager then installs the
# packages below, checking each against Google's repository, and this
# script checks that each is the revision pinned here, so a package Google
# replaced fails the setup rather than changing the build. Running it
# again does nothing once the SDK is there. Several builds may run it at
# once: it holds a lock while it installs, and moves a finished SDK into
# place in one rename.
#
# Installing accepts the Android SDK's licenses, as Android Studio and
# GitHub's runners do.
set -euo pipefail

TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip # cmdline-tools 20.0
TOOLS_SHA256=04453066b540409d975c676d781da1477479dde3761310f1a7eb92a1dfb15af7
# Each package and the revision its source.properties must name. The NDK is
# the one Lota's rake android:deps and Fledge's runtime are built with.
PACKAGES=(
  "platforms;android-36=2"
  "build-tools;36.0.0=36.0.0"
  "ndk;30.0.16248370=30.0.16248370"
)
EMULATOR_PACKAGES=(
  "platform-tools=37.0.3"
  "emulator=37.3.9"
  "system-images;android-33;google_apis;x86_64="
)

emulator=false
case "${1:-}" in
  "") ;;
  --emulator) emulator=true ;;
  *) echo "usage: script/android_sdk.sh [--emulator]" >&2; exit 2 ;;
esac

if [ "$(uname -s)-$(uname -m)" != Linux-x86_64 ]; then
  echo "script/android_sdk.sh pins Linux's command-line tools, and this is $(uname -s) on $(uname -m)." >&2
  echo "Install the packages it lists with Android Studio's SDK Manager, and set ANDROID_HOME." >&2
  exit 1
fi
command -v java > /dev/null || { echo "script/android_sdk.sh needs a JDK: MISE_ENV=android mise install" >&2; exit 1; }

key=$(printf '%s\n' "$TOOLS_SHA256" "${PACKAGES[@]}" | sha256sum | cut -c1-12)
cache=${XDG_CACHE_HOME:-$HOME/.cache}/dot_popper
sdk=$cache/android-sdk-$key
mkdir -p "$cache"

# The revision of an installed package, from its source.properties.
revision() {
  local folder=$1/${2//;//}
  sed -n 's/^Pkg.Revision=//p' "$folder/source.properties" 2> /dev/null | tr -d '\r'
}

# Installs PACKAGE=REVISION... into the SDK at $1 with its sdkmanager, and
# checks each revision (an empty one is not checked).
install_packages() {
  local root=$1; shift
  local names=() entry
  for entry in "$@"; do names+=("${entry%%=*}"); done
  # yes ends on a broken pipe once sdkmanager stops reading.
  (yes 2> /dev/null || true) | "$root/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$root" --licenses > /dev/null
  "$root/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$root" --install "${names[@]}" > "$root/sdkmanager.log" 2>&1 ||
    { tail -20 "$root/sdkmanager.log" >&2; return 1; }
  for entry in "$@"; do
    local want=${entry#*=} got
    got=$(revision "$root" "${entry%%=*}")
    [ -n "$got" ] || { echo "sdkmanager installed no ${entry%%=*}" >&2; return 1; }
    if [ -n "$want" ] && [ "$got" != "$want" ]; then
      echo "${entry%%=*} is revision $got, not the pinned $want: Google replaced it; pin the new one" >&2
      return 1
    fi
  done
}

{
  command -v flock > /dev/null && flock 9
  if [ ! -f "$sdk/.complete" ]; then
    work=$(mktemp -d "$cache/android-sdk-$key.XXXXXX")
    trap 'rm -rf "$work"' EXIT
    curl -fsSL --retry 3 -o "$work/tools.zip" "$TOOLS_URL"
    echo "$TOOLS_SHA256  $work/tools.zip" | sha256sum --check --quiet
    mkdir -p "$work/sdk/cmdline-tools"
    unzip -q "$work/tools.zip" -d "$work/unzip"
    mv "$work/unzip/cmdline-tools" "$work/sdk/cmdline-tools/latest"
    install_packages "$work/sdk" "${PACKAGES[@]}"
    touch "$work/sdk/.complete"
    rm -rf "$sdk"
    mv "$work/sdk" "$sdk"
    rm -rf "$work"
    trap - EXIT
  fi
  if $emulator && [ ! -f "$sdk/.emulator" ]; then
    install_packages "$sdk" "${EMULATOR_PACKAGES[@]}"
    touch "$sdk/.emulator"
  fi
} 9> "$cache/android-sdk-$key.lock"

echo "ANDROID_HOME=$sdk"
