#!/bin/bash
# checkbundle.sh FULL UPGRADE
# Checks that the two zips tools/bundle.sh made agree with each other.

set -Eeuo pipefail

files() { unzip -Z1 "$1" | grep -v '/$' | LC_ALL=C sort; }

if ! diff <(files "$1" | grep -vE '^(cfg|addons/sourcemod/configs)/') \
          <(files "$2" | grep -Fvx gokz-removed.txt); then
    echo "checkbundle.sh: the upgrade zip should hold everything in the full zip except configs" >&2
    exit 1
fi
if files "$2" | grep -Fxf <(unzip -p "$2" gokz-removed.txt); then
    echo "checkbundle.sh: the upgrade zip lists files it ships as removed" >&2
    exit 1
fi
