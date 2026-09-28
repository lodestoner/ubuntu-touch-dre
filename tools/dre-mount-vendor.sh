#!/bin/sh
set -eu

for partition in vendor odm vendor_dlkm; do
    mapping="${partition}_a"
    device="/dev/dre-${mapping}"
    destination="/android/${partition}"
    numbers=$(dmsetup info -c --noheadings -o major,minor "$mapping") || {
        echo "DRE ${partition} mapping is missing" >&2
        exit 1
    }
    major=${numbers%:*}
    minor=${numbers#*:}
    [ -b "$device" ] || mknod "$device" b "$major" "$minor"
    if ! mountpoint -q "$destination"; then
        mount -o ro "$device" "$destination"
    fi
done
