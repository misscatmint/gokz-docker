#!/bin/sh
# Lists the base images pinned in the Dockerfiles and the GitHub releases pinned
# in build.sh that have a newer tag of the same shape (e.g. 3.24.2 is only
# compared with other x.y.z tags). Needs skopeo, git and curl.
set -eu
cd "$(dirname "$0")/.."

# report LABEL TAG [PREFIX]: prints LABEL NEWER (was TAG) if the newest tag on
# stdin that has TAG's shape and starts with PREFIX isn't TAG.
report() {
    shape=$(printf '%s' "$2" | sed -E 's/[0-9]+/N/g')
    latest=$(awk -v shape="$shape" -v prefix="${3:-}" '
        { s = $0; gsub(/[0-9]+/, "N", s) }
        s == shape && substr($0, 1, length(prefix)) == prefix' | sort -V | tail -n 1)
    [ -n "$latest" ] || { echo "outdated.sh: no $shape tags for $1" >&2; exit 1; }
    [ "$latest" = "$2" ] || printf '%s %s (was %s)\n' "$1" "$latest" "$2"
}

images=$(sed -nE 's/^FROM ([^:@ ]+):([^@ ]+)@.*/\1 \2/p' Dockerfile maps/Dockerfile bundle/Dockerfile | sort -u |
while read -r image tag; do
    case $image in
        # The registry has beta tags too, and nothing there says which are stable.
        registry.gitlab.steamos.cloud/steamrt/sniper/platform)
            tags=$(curl -fsSL https://repo.steampowered.com/steamrt-images-sniper/snapshots/latest-public-stable.txt) ;;
        *)
            # Its own step so set -e catches a failure, which a pipeline would hide.
            tags=$(skopeo list-tags "docker://$image")
            tags=$(printf '%s\n' "$tags" | sed -nE 's/^ *"([^"]+)",?$/\1/p') ;;
    esac
    printf '%s\n' "$tags" | report "$image" "$tag"
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
    printf '%s\n' "$tags" | sed 's#.*refs/tags/##' | report "$repo" "$tag" "$prefix"
done)
[ -z "$releases" ] || printf '%s\n' "$releases"
[ -n "$images$releases" ] || echo "Everything checked is current."
grep -oE "https://[^\"'} ]+" build.sh |
    grep -vE '^https://github\.com/[^/]+/[^/]+/releases/download/' | sed 's/^/not checked: /'
