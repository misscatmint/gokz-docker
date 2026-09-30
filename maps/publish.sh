#!/bin/sh
# aria2 --on-download-complete hook: $1=gid $2=file count $3=path of the first file
mv "$3" "${3%.part}"
