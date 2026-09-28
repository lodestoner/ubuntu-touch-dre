#!/bin/sh
set -eu

if [ -d /sys/class/net/wlan0 ]; then
    exit 0
fi

ready=0
for attempt in $(seq 1 90); do
    if dmesg | grep -q 'icnss2: WLAN FW is ready'; then
        ready=1
        break
    fi
    sleep 1
done

if [ "$ready" -ne 1 ]; then
    echo 'DRE Wi-Fi firmware did not become ready' >&2
    exit 1
fi

if [ ! -d /sys/module/wlan ]; then
    insmod /usr/local/lib/modules/wlan-dre.ko
fi

for attempt in $(seq 1 10); do
    if [ -c /dev/wlan ]; then
        break
    fi
    sleep 1
done

printf 'ON\n' > /dev/wlan

for attempt in $(seq 1 30); do
    if [ -d /sys/class/net/wlan0 ]; then
        exit 0
    fi
    sleep 1
done

echo 'DRE Wi-Fi driver did not create wlan0' >&2
exit 1
