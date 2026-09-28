#!/bin/busybox sh
# OnePlus Nord N200 early userspace: ACM + NCM rescue, then Ubuntu systemd.

export PATH=/bin:/sbin:/usr/bin:/usr/sbin
G=/config/usb_gadget/g1

log() {
    echo "dre-switch: $*" >/dev/kmsg 2>/dev/null || true
    echo "dre-switch: $*" >/dev/console 2>/dev/null || true
}

rescue_forever() {
    log "RESCUE: $*"
    while true; do sleep 60; done
}

setup_usb() {
    mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409"
    echo 0x18d1 > "$G/idVendor"
    echo 0xd002 > "$G/idProduct"
    echo dre-ubuntu > "$G/strings/0x409/serialnumber"
    echo "Ubuntu Touch bring-up" > "$G/strings/0x409/manufacturer"
    echo "DRE ACM+NCM" > "$G/strings/0x409/product"

    mkdir -p "$G/functions/acm.GS0" "$G/functions/ncm.usb0"
    echo acm+ncm > "$G/configs/c.1/strings/0x409/configuration"
    ln -sf "$G/functions/acm.GS0" "$G/configs/c.1/acm.GS0"
    ln -sf "$G/functions/ncm.usb0" "$G/configs/c.1/ncm.usb0"

    udc=""
    while [ -z "$udc" ]; do
        udc="$(ls /sys/class/udc 2>/dev/null | grep -v dummy | head -1)"
        [ -n "$udc" ] || sleep 1
    done
    echo "$udc" > "$G/UDC" || rescue_forever "failed to bind $udc"

    ncm=""
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        for iface in usb0 ncm0; do
            [ -d "/sys/class/net/$iface" ] && ncm="$iface"
        done
        [ -n "$ncm" ] && break
        sleep 1
    done
    [ -n "$ncm" ] || rescue_forever "NCM interface did not appear"

    ip link set "$ncm" up
    ip addr add 192.168.2.15/24 dev "$ncm"
    ip route add default via 192.168.2.20
    log "USB ready: ACM ttyGS0, NCM $ncm"
}

setup_usb

# Disarm Qualcomm SoC / hardware watchdog via sysfs
for wdt in /sys/devices/platform/soc/*wdt*/disable /sys/bus/platform/devices/*watchdog*/disable; do
    if [ -f "$wdt" ]; then
        echo 1 > "$wdt" 2>/dev/null && log "Disarmed Qualcomm watchdog at $wdt" || true
    fi
done

mount -t tmpfs -o mode=0755,nosuid,nodev tmpfs /run || rescue_forever "cannot mount /run"
mkdir -p /data /newroot

userdata=""
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    for uevent in /sys/class/block/*/uevent; do
        if grep -q '^PARTNAME=userdata$' "$uevent" 2>/dev/null; then
            userdata="/dev/$(basename "$(dirname "$uevent")")"
            break
        fi
    done
    [ -n "$userdata" ] && break
    sleep 1
done
[ -n "$userdata" ] || rescue_forever "userdata partition not found"

mount -t ext4 -o rw "$userdata" /data || rescue_forever "cannot mount $userdata"
[ -x /data/ubuntu-rootfs/sbin/init ] || rescue_forever "Ubuntu /sbin/init missing"

# Save previous crash / ramoops logs if present
mkdir -p /sys/fs/pstore
mount -t pstore pstore /sys/fs/pstore 2>/dev/null || true
if [ -d /sys/fs/pstore ] && ls /sys/fs/pstore/* >/dev/null 2>&1; then
    mkdir -p /data/crash-logs
    cp -a /sys/fs/pstore/* /data/crash-logs/ 2>/dev/null || true
    log "Saved pstore crash logs to /data/crash-logs"
fi

# Ensure systemd pets watchdog
if [ -f /data/ubuntu-rootfs/etc/systemd/system.conf ]; then
    sed -i 's/^#*RuntimeWatchdogSec=.*/RuntimeWatchdogSec=10s/' /data/ubuntu-rootfs/etc/systemd/system.conf 2>/dev/null || true
fi

# Clean up any bad early-shell service
rm -f /data/ubuntu-rootfs/etc/systemd/system/early-shell.service 2>/dev/null || true
rm -f /data/ubuntu-rootfs/etc/systemd/system/sysinit.target.wants/early-shell.service 2>/dev/null || true

# 1. Configure serial-getty on ttyGS0 with autologin and infinite restart
mkdir -p /data/ubuntu-rootfs/etc/systemd/system/serial-getty@ttyGS0.service.d
mkdir -p /data/ubuntu-rootfs/etc/systemd/system/getty.target.wants
cat <<'GETTY_EOF' > /data/ubuntu-rootfs/etc/systemd/system/serial-getty@ttyGS0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 115200 linux
Type=idle
Restart=always
RestartSec=1
GETTY_EOF
ln -sf /usr/lib/systemd/system/serial-getty@.service /data/ubuntu-rootfs/etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service

# 2. Configure unbreakable TCP Remote Execution server on port 5555
mkdir -p /data/ubuntu-rootfs/usr/local/bin
cat <<'PY_EOF' > /data/ubuntu-rootfs/usr/local/bin/dre-remote-exec
#!/usr/bin/env python3
import socket
import subprocess
import sys

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('192.168.2.15', 5555))
server.listen(10)

while True:
    try:
        conn, _ = server.accept()
        data = conn.recv(65536)
        if data:
            cmd = data.decode('utf-8', 'replace').strip()
            if cmd:
                proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)
                out = (proc.stdout + proc.stderr).encode('utf-8', 'replace')
                conn.sendall(out)
        conn.close()
    except Exception as e:
        try:
            conn.sendall(f"ERR: {e}\n".encode())
            conn.close()
        except:
            pass
PY_EOF
chmod 755 /data/ubuntu-rootfs/usr/local/bin/dre-remote-exec

mkdir -p /data/ubuntu-rootfs/etc/systemd/system/sysinit.target.wants /data/ubuntu-rootfs/etc/systemd/system/multi-user.target.wants
cat <<'SVC_EOF' > /data/ubuntu-rootfs/etc/systemd/system/dre-remote-exec.service
[Unit]
Description=DRE Remote Command Execution Server on port 5555
DefaultDependencies=no
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/dre-remote-exec
Restart=always
RestartSec=1

[Install]
WantedBy=sysinit.target multi-user.target
SVC_EOF
ln -sf /etc/systemd/system/dre-remote-exec.service /data/ubuntu-rootfs/etc/systemd/system/sysinit.target.wants/dre-remote-exec.service
ln -sf /etc/systemd/system/dre-remote-exec.service /data/ubuntu-rootfs/etc/systemd/system/multi-user.target.wants/dre-remote-exec.service

# 3. Configure early telnet rescue service on port 23
cp /bin/busybox /data/ubuntu-rootfs/bin/busybox 2>/dev/null || true
chmod 755 /data/ubuntu-rootfs/bin/busybox 2>/dev/null || true
cat <<'TEL_EOF' > /data/ubuntu-rootfs/etc/systemd/system/early-telnet.service
[Unit]
Description=Early Telnet Rescue
DefaultDependencies=no
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/bin/busybox telnetd -F -b 192.168.2.15:23 -l /bin/bash
Restart=always
RestartSec=2

[Install]
WantedBy=sysinit.target multi-user.target
TEL_EOF
ln -sf /etc/systemd/system/early-telnet.service /data/ubuntu-rootfs/etc/systemd/system/sysinit.target.wants/early-telnet.service
ln -sf /etc/systemd/system/early-telnet.service /data/ubuntu-rootfs/etc/systemd/system/multi-user.target.wants/early-telnet.service

# 4. Disable bracketed paste mode for serial
echo "set enable-bracketed-paste off" >> /data/ubuntu-rootfs/root/.inputrc 2>/dev/null || true
echo "set enable-bracketed-paste off" >> /data/ubuntu-rootfs/etc/inputrc 2>/dev/null || true

# 5. Continuous watchdog disarm service
cat <<'WDT_EOF' > /data/ubuntu-rootfs/etc/systemd/system/disarm-wdt.service
[Unit]
Description=Ensure Qualcomm Watchdog is Disarmed
DefaultDependencies=no
Before=sysinit.target
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for w in /sys/devices/platform/soc/*wdt*/disable /sys/bus/platform/devices/*watchdog*/disable; do [ -f "$w" ] && echo 1 > "$w" || true; done'
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
WDT_EOF
ln -sf /etc/systemd/system/disarm-wdt.service /data/ubuntu-rootfs/etc/systemd/system/sysinit.target.wants/disarm-wdt.service

# 6. Write dre-map-super with --noudevsync so dmsetup never hangs on udev
mkdir -p /data/ubuntu-rootfs/usr/local/sbin
cat <<'DMS_EOF' > /data/ubuntu-rootfs/usr/local/sbin/dre-map-super
#!/bin/sh
set -eu

create_map() {
    name=$1
    length=$2
    offset=$3
    dmsetup info "$name" >/dev/null 2>&1 ||
        dmsetup create --noudevsync "$name" --table "0 $length linear /dev/sda9 $offset"
}

create_map odm_a          642312  2048
create_map product_a      4950032 644608
create_map system_a       2244912 5594880
create_map system_ext_a   1108536 7840000
create_map vendor_a       555504  8948736
create_map vendor_dlkm_a  17944   9504256
DMS_EOF
chmod 755 /data/ubuntu-rootfs/usr/local/sbin/dre-map-super

cat <<'DM_EOF' > /data/ubuntu-rootfs/etc/systemd/system/dre-map-super.service
[Unit]
Description=Create DRE slot-A logical partition mappings
DefaultDependencies=no
Before=mount-android-partitions.service lxc-android-config.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dre-map-super
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
DM_EOF
ln -sf /etc/systemd/system/dre-map-super.service /data/ubuntu-rootfs/etc/systemd/system/sysinit.target.wants/dre-map-super.service

# 7. Preserve the lxc-android-config package's Android container configuration.
# The previous bootstrap rewrote these files on every boot with a Halium 11
# experiment.  The installed compatibility image is Halium 16, so its package
# configuration and any deliberate device overlay must remain authoritative.
mkdir -p /data/ubuntu-rootfs/var/lib/lxc/android

# 9. Standalone Display HAL runner (Fable 5 blueprint)
cat <<'HAL_EOF' > /data/ubuntu-rootfs/usr/local/bin/start-display-hals.sh
#!/bin/bash
set -x

export ANDROID_ROOT=/android/system
export ANDROID_DATA=/android/data
export ANDROID_VENDOR=/android/vendor
export LD_LIBRARY_PATH=/android/vendor/lib64:/android/system/system_ext/lib64:/android/system/lib64

# Start Binder Managers
/android/system/bin/servicemanager &
/android/system/bin/hwservicemanager &
/android/vendor/bin/vndservicemanager &
sleep 2

# Start Allocator (Gralloc)
if [ -x /android/vendor/bin/hw/vendor.qti.hardware.display.allocator-service ]; then
    /android/vendor/bin/hw/vendor.qti.hardware.display.allocator-service &
elif [ -x /android/vendor/bin/hw/android.hardware.graphics.allocator@4.0-service ]; then
    /android/vendor/bin/hw/android.hardware.graphics.allocator@4.0-service &
fi

# Start Composer (Hwcomposer)
if [ -x /android/vendor/bin/hw/vendor.qti.hardware.display.composer-service ]; then
    /android/vendor/bin/hw/vendor.qti.hardware.display.composer-service &
elif [ -x /android/vendor/bin/hw/android.hardware.graphics.composer@2.4-service ]; then
    /android/vendor/bin/hw/android.hardware.graphics.composer@2.4-service &
fi

echo "Display HALs launched."
HAL_EOF
chmod 755 /data/ubuntu-rootfs/usr/local/bin/start-display-hals.sh

# 10. Display test script
cat <<'TEST_EOF' > /data/ubuntu-rootfs/usr/local/bin/test-display.sh
#!/bin/bash
export HYBRIS_LD_LIBRARY_PATH=/android/vendor/lib64:/android/system/lib64:/android/system/system_ext/lib64
export EGL_PLATFORM=hwcomposer
export QT_QPA_PLATFORM=hwcomposer
/usr/bin/test_hwcomposer
TEST_EOF
chmod 755 /data/ubuntu-rootfs/usr/local/bin/test-display.sh

# 11. Write DRE deviceinfo YAML for Lomiri / Mir
mkdir -p /data/ubuntu-rootfs/etc/deviceinfo/devices
cat <<'YML_EOF' > /data/ubuntu-rootfs/etc/deviceinfo/devices/dre.yaml
deviceinfo:
  name: "OnePlus Nord N200 5G"
  grid_unit: 18
  primary_orientation: "portrait"
  supported_orientations:
    - "portrait"
    - "inverted-portrait"
    - "landscape"
    - "inverted-landscape"
YML_EOF

# Mask conflicting USB services that attempt to reconfigure gadget
for svc in usb-tethering.service hybris-usb.service usb-moded.service; do
    rm -f /data/ubuntu-rootfs/etc/systemd/system/multi-user.target.wants/$svc 2>/dev/null || true
    ln -sf /dev/null /data/ubuntu-rootfs/etc/systemd/system/$svc 2>/dev/null || true
done

# switch_root requires the target itself to be a mount point.
mount --bind /data/ubuntu-rootfs /newroot || rescue_forever "cannot bind Ubuntu root"
mkdir -p /newroot/dev /newroot/proc /newroot/sys /newroot/run /newroot/sys/kernel/config

log "moving virtual filesystems and starting Ubuntu systemd"
mount --move /dev /newroot/dev || rescue_forever "cannot move /dev"
mount --move /proc /newroot/proc || rescue_forever "cannot move /proc"
mount --move /sys /newroot/sys || rescue_forever "cannot move /sys"
mount --move /run /newroot/run || rescue_forever "cannot move /run"
mount --move /config /newroot/sys/kernel/config || true

exec /bin/busybox switch_root /newroot /sbin/init

rescue_forever "switch_root returned"
