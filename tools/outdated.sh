#!/bin/sh
# Lists each base image pinned in the Dockerfiles next to its newest tag of the
# same shape (e.g. 3.24.2 is only compared with other x.y.z tags). Needs skopeo.
set -eu
cd "$(dirname "$0")/.."

sed -nE 's/^FROM ([^:@ ]+):([^@ ]+)@.*/\1 \2/p' Dockerfile maps/Dockerfile | sort -u |
while read -r image tag; do
    shape=$(printf '%s' "$tag" | sed -E 's/[0-9]+/N/g')
    latest=$(skopeo list-tags "docker://$image" |
        sed -nE 's/^ *"([^"]+)",?$/\1/p' |
        awk -v shape="$shape" '{ s = $0; gsub(/[0-9]+/, "N", s) } s == shape' |
        sort -V | tail -n 1)
    if [ "$latest" = "$tag" ]; then
        printf '%s:%s is current\n' "$image" "$tag"
    else
        printf '%s:%s -> %s\n' "$image" "$tag" "$latest"
    fi
done
