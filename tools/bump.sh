#!/bin/bash
# tools/bump.sh URL
# tools/bump.sh OWNER/REPO TAG
# Points build.sh's download from the same GitHub repo at URL (a release asset,
# copied from the release page) or at TAG's asset of the same name with the
# version swapped, updates its sha256, and shows how the archive's file list
# changed.

set -Eeuo pipefail
cd "$(dirname "$0")/.."

if [[ $# == 1 && $1 =~ ^https://github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/[^/]+$ ]]; then
    new=$1 repo=${BASH_REMATCH[1]} newtag=${BASH_REMATCH[2]}
elif [[ $# == 2 && $1 =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ && $2 =~ ^[A-Za-z0-9._+-]+$ ]]; then
    new='' repo=$1 newtag=$2
else
    echo "usage: tools/bump.sh https://github.com/OWNER/REPO/releases/download/TAG/FILE" >&2
    echo "       tools/bump.sh OWNER/REPO TAG" >&2
    exit 1
fi

matches=$(grep -nF "https://github.com/$repo/releases/download/" build.sh || true)
case $matches in
    '')      echo "bump.sh: no $repo download in build.sh" >&2; exit 1 ;;
    *$'\n'*) echo "bump.sh: several $repo downloads in build.sh" >&2; exit 1 ;;
esac
lineno=${matches%%:*}
old=$(grep -oE "https://github\.com/[^ \"'}]+" <<<"$matches")
oldtag=$(sed -E 's#.*/releases/download/([^/]+)/.*#\1#' <<<"$old")
oldsha=$(sed -n "$((lineno + 1))p" build.sh | grep -oE '[0-9a-f]{64}')
if [[ -z $new ]]; then
    oldver=${oldtag#v} newver=${newtag#v} file=${old##*/}
    file=${file//"$oldver"/"$newver"}
    # Metamod and SourceMod name their 1.12.0.7255 build 1.12.0-git7255.
    file=${file//"${oldver%.*}-git${oldver##*.}"/"${newver%.*}-git${newver##*.}"}
    new=https://github.com/$repo/releases/download/$newtag/$file
fi
[[ $old != "$new" ]] || { echo "bump.sh: build.sh already uses $new" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/old" "$old"
curl -fsSL -o "$tmp/new" "$new" || {
    echo "bump.sh: copy the asset's URL from https://github.com/$repo/releases/tag/$newtag" >&2
    exit 1
}
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
