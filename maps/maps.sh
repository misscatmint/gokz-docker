#!/bin/sh
# maps.sh          download the maps that are missing
# maps.sh verify   delete maps that fail their checksum; the next sync re-fetches them
set -eu

[ -n "${LOCKED:-}" ] || exec env LOCKED=1 nice -n 19 ionice -c 3 "$0" "$@"
exec 9>/tmp/maps.lock
flock 9

cd /data/csgo
list=$(mktemp)
todo=$(mktemp)
have=$(mktemp)
trap 'rm -f "$list" "$todo" "$have"' EXIT
curl -fsSL -o "$list" "$ARIA2URL"

case ${1:-sync} in
sync)
    # A .part with no control file can't be resumed, and aria2 refuses to touch it.
    find ./maps -name '*.part' ! -exec sh -c 'test -e "$1.aria2"' _ {} \; -delete
    find ./maps -type f > "$have"
    # Only missing maps go to aria2, saved as *.part, which srcds ignores.
    # publish.sh renames each one once aria2 has downloaded and checksummed it.
    awk 'FILENAME == ARGV[1] { have[$0]; next }
         /^http/ { url = $0; next }
         /^ *dir=/ { dir = substr($0, index($0, "=") + 1); next }
         /^ *out=/ { out = substr($0, index($0, "=") + 1); next }
         /^ *checksum=/ && !((dir "/" out) in have) {
             print url; print "  dir=" dir; print "  out=" out ".part"; print }' \
        "$have" "$list" > "$todo"
    [ -s "$todo" ] || exit 0
    aria2c --continue=true --check-integrity=true --auto-file-renaming=false \
           --max-concurrent-downloads=4 --split=1 --file-allocation=falloc \
           --show-console-readout=false --enable-color=false \
           --on-download-complete=/publish.sh --input-file="$todo"
    ;;
verify)
    awk '/^ *dir=/ { dir = substr($0, index($0, "=") + 1) }
         /^ *out=/ { out = substr($0, index($0, "=") + 1) }
         /^ *checksum=sha-256=/ { print substr($0, index($0, "sha-256=") + 8) "  " dir "/" out }' "$list" |
        sha256sum -c 2>/dev/null | sed -n 's/: FAILED$//p' | xargs -r rm -v --
    ;;
esac
