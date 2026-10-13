#!/bin/sh
# Lists the base images pinned in the Dockerfiles and the GitHub releases pinned
# in build.sh that have a newer tag of the same shape (e.g. 3.24.2 is only
# compared with other x.y.z tags). Needs skopeo and git.
set -eu
cd "$(dirname "$0")/.."

# report LABEL TAG [PREFIX]: prints LABEL -> NEWER if the newest tag on stdin
# that has TAG's shape and starts with PREFIX isn't TAG.
report() {
    shape=$(printf '%s' "$2" | sed -E 's/[0-9]+/N/g')
    latest=$(awk -v shape="$shape" -v prefix="${3:-}" '
        { s = $0; gsub(/[0-9]+/, "N", s) }
        s == shape && substr($0, 1, length(prefix)) == prefix' | sort -V | tail -n 1)
    [ -n "$latest" ] || { echo "outdated.sh: no $shape tags for $1" >&2; exit 1; }
    [ "$latest" = "$2" ] || printf '%s -> %s\n' "$1" "$latest"
}

images=$(sed -nE 's/^FROM ([^:@ ]+):([^@ ]+)@.*/\1 \2/p' Dockerfile maps/Dockerfile bundle/Dockerfile | sort -u |
while read -r image tag; do
    # Its own step so set -e catches a failure, which a pipeline would hide.
    tags=$(skopeo list-tags "docker://$image")
    printf '%s\n' "$tags" | sed -nE 's/^ *"([^"]+)",?$/\1/p' | report "$image:$tag" "$tag"
done)
[ -z "$images" ] || printf '%s\n' "$images"

# GitHub answers a missing repo with a login prompt otherwise.
export GIT_TERMINAL_PROMPT=0
releases=$(grep -oE 'https://github\.com/[^/]+/[^/]+/releases/download/[^/]+/' build.sh |
    sed -E 's#^https://github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/$#\1 \2#' | sort -u |
while read -r repo tag; do
    # Moving to Metamod 2.0 or SourceMod 1.13 is out of scope.
    case $repo in
        alliedmodders/metamod-source|alliedmodders/sourcemod) prefix=${tag%.*.*}. ;;
        *) prefix= ;;
    esac
    tags=$(git ls-remote --tags --refs "https://github.com/$repo")
    printf '%s\n' "$tags" | sed 's#.*refs/tags/##' | report "$repo $tag" "$tag" "$prefix"
done)
[ -z "$releases" ] || printf '%s\n' "$releases"
[ -n "$images$releases" ] || echo "Everything checked is current."
grep -oE "https://[^\"'} ]+" build.sh |
    grep -vE '^https://github\.com/[^/]+/[^/]+/releases/download/' | sed 's/^/not checked: /'
case $releases in
    *' -> '*) printf '\nTo update one, copy the new download link from its release page and run\ntools/bump.sh URL\n' ;;
esac
