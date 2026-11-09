#!/usr/bin/env bash
# Publishes doc/privacy.json to the server for the tag in $TAG (v0.9.9 etc.).
# Needs PRIVACY_DOCUMENT_TOKEN. PRIVACY_DOCUMENT_URL is for a local stub.
set -euo pipefail

tag="${TAG:?TAG is the tag being published}"
url="${PRIVACY_DOCUMENT_URL:-https://server.dot-popper.setdef.com/privacy_document}"
: "${PRIVACY_DOCUMENT_TOKEN:?PRIVACY_DOCUMENT_TOKEN is not set}"
doc=doc/privacy.json

# Regenerate, so a stale document cannot be published.
bundle exec rake privacy
if ! git diff --quiet -- "$doc"; then
  echo "::error::$doc is stale: regenerating it changed it. Commit it and re-tag."
  git diff -- "$doc"
  exit 1
fi

version="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).fetch("game_version")' "$doc")"
if [ "$version" != "${tag#v}" ]; then
  echo "::error::game_version is $version but the tag is $tag"
  exit 1
fi

body="$(mktemp)"
status="$(curl --silent --show-error --output "$body" --write-out '%{http_code}' \
  --request PUT "$url" \
  --header "Authorization: Bearer $PRIVACY_DOCUMENT_TOKEN" \
  --header 'Content-Type: application/json' \
  --data-binary "@$doc")"

case "$status" in
  201) echo "Published the privacy document for $tag (new)." ;;
  200) echo "The server already has this privacy document for $tag." ;;
  *)
    echo "::error::The server answered $status"
    cat "$body"
    echo
    exit 1
    ;;
esac
