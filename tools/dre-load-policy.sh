#!/bin/sh
set -eu

policy=/android/dre-sepolicy
[ -s "$policy" ] || { echo "DRE SELinux policy cache is missing" >&2; exit 1; }

/usr/bin/lxc-attach -n android -- /system/bin/load_policy /dre-sepolicy

[ "$(wc -c < /sys/fs/selinux/policy)" -gt 1000000 ] || {
    echo "DRE SELinux policy did not load" >&2
    exit 1
}
