#!/bin/sh
set -eu

# LineageOS 23.2 dre super metadata, slot A, captured 2026-09-27.
# dmsetup lengths and offsets are expressed in 512-byte sectors.
super_device=
for event in /sys/block/*/*/uevent; do
    if grep -qx 'PARTNAME=super' "$event"; then
        if [ -n "$super_device" ]; then
            echo 'Multiple super partitions found' >&2
            exit 1
        fi
        super_device="/dev/$(sed -n 's/^DEVNAME=//p' "$event")"
    fi
done

if [ -z "$super_device" ] || [ ! -b "$super_device" ]; then
    echo 'Super partition is unavailable' >&2
    exit 1
fi

create_map() {
    name=$1
    length=$2
    offset=$3
    dmsetup info "$name" >/dev/null 2>&1 ||
        dmsetup create --noudevsync "$name" --table "0 $length linear $super_device $offset"
}

create_map odm_a          642312  2048
create_map product_a      4950032 644608
create_map system_a       2244912 5594880
create_map system_ext_a   1108536 7840000
create_map vendor_a       555504  8948736
create_map vendor_dlkm_a  17944   9504256

dmsetup mknodes
udevadm settle
