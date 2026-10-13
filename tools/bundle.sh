#!/bin/bash
# bundle.sh BUILD STATE OUT
#
# Packs the add-on tree that build.sh made in BUILD into zips for servers that
# can't run the image, meant to be extracted into the server's csgo folder:
#   gokz-<version>.zip          everything, configs included (new servers)
#   gokz-<version>-upgrade.zip  no configs, plus gokz-removed.txt (updates)
# STATE holds files.txt (the previous bundle's upgrade files) and removed.txt
# (every file dropped since); both are updated once the zips are written.

set -Eeuo pipefail

mkdir -p "$3"
build=$(realpath "$1") state=$(realpath "$2") out=$(realpath "$3")
version=$(cut -c1-12 "$build/.version")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tree=$work/tree

cp -a "$build/csgo" "$tree"
cp "$build/server.cfg" "$tree/cfg/server.cfg"
# Accelerator uploads crash dumps, and outside the image nothing moves them out of its way.
rm "$tree/addons/sourcemod/extensions/accelerator.autoload" \
   "$tree/addons/sourcemod/extensions/accelerator.ext.so" \
   "$tree/addons/sourcemod/gamedata/accelerator.games.txt"

{
    echo "Where each bundled component comes from. GitHub entries link to the"
    echo "source at the released tag; the rest are the original downloads."
    echo
    grep -v accelerator "$build/sources.txt" |
        sed -E 's#^https://github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/(.+)$#\3  https://github.com/\1/tree/\2#'
} > "$tree/gokz-sources.txt"

# Files the upgrade zip carries; configs are the server owner's, so never included.
upgrade_files() {
    (cd "$tree" && find . -type f ! -path './cfg/*' ! -path './addons/sourcemod/configs/*' \
         ! -path './gokz-*.txt') | sed 's#^\./##' | LC_ALL=C sort
}

upgrade_files > "$work/files.txt"
# Cumulative, so skipping a version still removes everything; files that came back drop out.
LC_ALL=C comm -23 "$state/files.txt" "$work/files.txt" | cat - "$state/removed.txt" |
    LC_ALL=C sort -u | LC_ALL=C comm -23 - "$work/files.txt" > "$work/removed.txt"

cd "$tree"
rm -f "$out/gokz-$version.zip" "$out/gokz-$version-upgrade.zip"
zip -qrX "$out/gokz-$version.zip" .
cp "$work/removed.txt" gokz-removed.txt
{ upgrade_files; echo gokz-sources.txt; echo gokz-removed.txt; } |
    zip -qX "$out/gokz-$version-upgrade.zip" -@
mv "$work/files.txt" "$work/removed.txt" "$state/"
