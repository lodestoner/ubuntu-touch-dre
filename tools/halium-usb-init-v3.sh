#!/bin/busybox sh
# Halium USB debug init v3 for OnePlus Nord N200 5G (dre)
# ACM serial + NCM networking + telnetd backup shell on NCM.

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

GADGET_DIR=/config/usb_gadget

tell_kmsg() {
    echo "initrd: $1" >/dev/kmsg 2>/dev/null || true
}

tell_kmsg "=== halium-usb-init-v3.sh starting ==="

kick_watchdog() {
    if [ -c /dev/watchdog ]; then
        echo -n "V" > /dev/watchdog 2>/dev/null || true
    fi
    if [ -d /sys/class/watchdog/watchdog0 ]; then
        echo 0 > /sys/class/watchdog/watchdog0/nowayout 2>/dev/null || true
    fi
}

kick_watchdog

usb_setup() {
    tell_kmsg "Setting up USB ACM+NCM gadget..."

    mkdir -p $GADGET_DIR/g1
    echo "0x18D1" > $GADGET_DIR/g1/idVendor
    echo "0xD002" > $GADGET_DIR/g1/idProduct

    mkdir -p $GADGET_DIR/g1/strings/0x409
    echo "dre-halium-debug" > $GADGET_DIR/g1/strings/0x409/serialnumber
    echo "Halium initrd" > $GADGET_DIR/g1/strings/0x409/manufacturer
    echo "DRE Debug Shell" > $GADGET_DIR/g1/strings/0x409/product

    # ACM function (serial port)
    mkdir -p $GADGET_DIR/g1/functions/acm.GS0

    # NCM function (network)
    mkdir -p $GADGET_DIR/g1/functions/ncm.usb0

    # Configuration — both functions in c.1
    mkdir -p $GADGET_DIR/g1/configs/c.1/strings/0x409
    echo "acm+ncm" > $GADGET_DIR/g1/configs/c.1/strings/0x409/configuration

    ln -sf $GADGET_DIR/g1/functions/acm.GS0 $GADGET_DIR/g1/configs/c.1/
    ln -sf $GADGET_DIR/g1/functions/ncm.usb0 $GADGET_DIR/g1/configs/c.1/

    UDC=$(ls /sys/class/udc 2>/dev/null | grep -v dummy | head -1)
    if [ -z "$UDC" ]; then
        tell_kmsg "ERROR: No UDC found"
        return 1
    fi

    tell_kmsg "Binding to UDC: $UDC"
    echo "$UDC" > $GADGET_DIR/g1/UDC 2>/dev/null
    RET=$?
    tell_kmsg "UDC bind returned: $RET"

    if [ $RET -ne 0 ]; then
        tell_kmsg "UDC bind failed"
        return 1
    fi

    sleep 2
    kick_watchdog

    # Configure NCM network interface
    NCM_IF=""
    for iface in usb0 ncm0; do
        if [ -d "/sys/class/net/$iface" ]; then
            NCM_IF="$iface"
            break
        fi
    done

    if [ -n "$NCM_IF" ]; then
        tell_kmsg "Configuring NCM interface: $NCM_IF"
        ip link set "$NCM_IF" up
        ip addr add 192.168.2.15/24 dev "$NCM_IF"
        ip route add default via 192.168.2.20
        tell_kmsg "NCM IP: 192.168.2.15/24"
    else
        tell_kmsg "WARNING: No NCM interface found"
    fi

    return 0
}

usb_setup
kick_watchdog

# Start telnetd on the NCM interface as backup shell
if command -v telnetd >/dev/null 2>&1; then
    tell_kmsg "Starting telnetd on 192.168.2.15:23"
    telnetd -l /bin/sh -b 192.168.2.15:23 2>/dev/null &
    tell_kmsg "telnetd started"
else
    tell_kmsg "No telnetd, starting nc listener on port 9999"
    while true; do
        nc -l -p 9999 -e /bin/sh 2>/dev/null
        sleep 1
    done &
fi

# Also start a nc listener on port 5555 as a second backup
(while true; do nc -l -p 5555 -e /bin/sh 2>/dev/null; sleep 1; done) &
tell_kmsg "nc shell listener on port 5555"

kick_watchdog

# ACM serial shell
ACM_DEV=""
for dev in /dev/ttyGS0 /dev/ttyGS1; do
    if [ -c "$dev" ]; then
        ACM_DEV="$dev"
        break
    fi
done

if [ -n "$ACM_DEV" ]; then
    tell_kmsg "ACM serial: $ACM_DEV (connect via /dev/ttyACM0 on host)"

    while true; do
        kick_watchdog
        tell_kmsg "Starting shell on $ACM_DEV"
        setsid sh -c "exec /bin/sh <$ACM_DEV >$ACM_DEV 2>&1" &
        SHELL_PID=$!

        while kill -0 $SHELL_PID 2>/dev/null; do
            kick_watchdog
            sleep 5
        done

        tell_kmsg "Shell exited, restarting..."
        sleep 1
    done
else
    tell_kmsg "No ACM device — using telnet/nc only"
    while true; do
        kick_watchdog
        sleep 5
    done
fi
