#!/bin/bash
# tools/bump.sh URL
# Points build.sh's download from the same GitHub repo at URL (a release asset,
# copied from the release page), updates its sha256, and shows how the
# archive's file list changed.

set -Eeuo pipefail
cd "$(dirname "$0")/.."

new=${1:-}
[[ $new =~ ^https://github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/[^/]+$ ]] || {
    echo "usage: tools/bump.sh https://github.com/OWNER/REPO/releases/download/TAG/FILE" >&2
    exit 1
}
repo=${BASH_REMATCH[1]} newtag=${BASH_REMATCH[2]}

matches=$(grep -nF "https://github.com/$repo/releases/download/" build.sh || true)
case $matches in
    '')      echo "bump.sh: no $repo download in build.sh" >&2; exit 1 ;;
    *$'\n'*) echo "bump.sh: several $repo downloads in build.sh" >&2; exit 1 ;;
esac
lineno=${matches%%:*}
old=$(grep -oE "https://github\.com/[^ \"'}]+" <<<"$matches")
oldtag=$(sed -E 's#.*/releases/download/([^/]+)/.*#\1#' <<<"$old")
oldsha=$(sed -n "$((lineno + 1))p" build.sh | grep -oE '[0-9a-f]{64}')
[[ $old != "$new" ]] || { echo "bump.sh: build.sh already uses $new" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/old" "$old"
curl -fsSL -o "$tmp/new" "$new"
echo "$oldsha  $tmp/old" | sha256sum -c --quiet - 2>/dev/null ||
    echo "bump.sh: warning: $old no longer matches its pinned hash" >&2
newsha=$(sha256sum "$tmp/new" | cut -d' ' -f1)

# File names with the version masked, so only real layout changes show up.
list() {
    if [[ $(head -c2 "$1") == PK ]]; then unzip -Z1 "$1"; else tar tf "$1"; fi |
        sed "s/${2//./\\.}/VERSION/g" | LC_ALL=C sort
}

sed -i "${lineno}s#$old#$new#; $((lineno + 1))s#$oldsha#$newsha#" build.sh
echo "build.sh:$lineno $repo $oldtag -> $newtag"
if diff <(list "$tmp/old" "$oldtag") <(list "$tmp/new" "$newtag") > "$tmp/diff"; then
    echo "Archive layout unchanged."
else
    echo "Archive layout changed (< old, > new). Check the extract paths and any -s folder:"
    cat "$tmp/diff"
fi
echo "Changes: https://github.com/$repo/compare/$oldtag...$newtag"
echo "Then: make lint && make build"
