#!/bin/sh

set -xeuo pipefail

cd /data/csgo
curl -fL http://csgo-kz-maps.badservers.net/downloads/raw-maps.aria2.txt | \
    aria2c --continue=true --check-integrity=true --auto-file-renaming=false \
           --max-concurrent-downloads=4 --split=1 --file-allocation=falloc \
           --show-console-readout=false --enable-color=false \
           --conditional-get=true --input-file=-
