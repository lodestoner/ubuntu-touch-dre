# Halium 16 development boot: DE2117

Status on 2026-09-28: the slot-A development boot reaches Ubuntu 24.04.3,
starts the Android LXC container, loads the cached SELinux policy, prepares
GPU and touch, and starts LightDM and Lomiri without manual commands. The
user reached home and confirmed touch, edge gestures, short-press screen lock,
and volume buttons. Native Wi-Fi connects and synchronizes the clock. Two
plugged-in reboots reached `wlan0:connected` without manual phone recovery;
the second had boot ID `88efd6d7-791d-4170-9882-efa0aa20ec10`. The user
also confirmed a fully unplugged restart reached home with Wi-Fi connected;
after USB reconnection its boot ID was
`2c060e4f-15ca-47cf-bf6b-64d91ca858eb`.

The flashed development boot image is `out/boot-ubuntu-systemd-halium16-v2.img`.
The Ubuntu rootfs and Android rootfs image live on userdata. This is a
development bring-up, not an installer, OTA-ready port, or verified stock
restore path. Do not infer that flashing firmware, vendor, super, DTBO,
vbmeta, or vendor_boot is safe from this result.

## Boot chain

- `dre-map-super.service` maps the slot-A logical partitions. Its script
  locates `super` through `/sys/block/*/*/uevent` rather than assuming a
  `/dev/sdX` letter, which changed between boots. It calls `dmsetup mknodes`,
  but udev's `/dev/mapper/*` links can still lag.
- `mount-android-partitions.service` has the DRE drop-in
  `tools/mount-android-partitions-dre.conf`. Its pre-start helper
  `tools/dre-mount-vendor.sh` creates temporary block nodes directly from
  `dmsetup info`, then mounts vendor, ODM, and vendor_dlkm. This avoids the
  early-udev race and lets the stock mount service read `/vendor/etc/fstab.qcom`
  to mount modem, DSP, Bluetooth firmware, and persist before Android LXC.
  The stock service also creates binderfs.
- `dre-android.service` waits for the partition, overlay, and APEX mounts,
  clears stale Android property files, then starts Android LXC. The cached
  compiled policy at `/android/dre-sepolicy` is loaded by
  `dre-selinux-policy.service`; reading `/sys/fs/selinux/policy` verifies it.
  `stat` reports zero for that virtual file, so verification uses `wc -c`.
- `dre-boot-hardware.service` sets `/dev/kgsl-3d0` and `/dev/ion` to
  `root:android_graphics 0660`, creates `/tmp/.X11-unix` as `root:root 1777`,
  and corrects the touchscreen's zero-range width and pressure axes through
  `EVIOCSABS`. LightDM requires this service and is enabled under the phone's
  `multi-user.target`.
- `/etc/machine-info` contains `CHASSIS=handset`. Lomiri uses that classification
  to distinguish a short power-key press from the desktop power-menu action.
- `dre-wifi.service` waits for the ICNSS firmware-ready message, loads the
  matching `/usr/local/lib/modules/wlan-dre.ko`, then writes `ON` to `/dev/wlan`.
  The stock vendor `wlan.ko` has an incompatible `module_layout` CRC despite
  matching vermagic. The rebuilt module SHA-256 is
  `8dc95517d66ea05818b052bbc763aab58830d415526d063d0bea7ad665556c92`.
  Do not unload the WLAN module live: a prior `rmmod wlan` hung the phone.

## Live checks

After the latest plugged-in reboot, all seven services below were `active`,
`wlan0` connected to the user's Wi-Fi, and the clock synchronized via NTP.
Earlier checks also showed Android LXC `RUNNING`, the Adreno 619 at 1080x2400,
and a 1,398,892-byte SELinux policy.

```sh
systemctl is-active dre-map-super.service mount-android-partitions.service \
    dre-android.service dre-selinux-policy.service dre-boot-hardware.service \
    dre-wifi.service lightdm.service
lxc-info -n android
wc -c /sys/fs/selinux/policy
hostnamectl status
nmcli device status
```

The USB rescue gadget exposes an unauthenticated root telnet service on port
23 and a root command server on port 5555 at `192.168.2.15`. Persistent
systemd drop-ins bind both services only to that USB address; a connection
to port 5555 from Wi-Fi was refused after the change. These services are
still development-only and must be removed or authenticated before ordinary
use. The initrd's base service files still contain wildcard binds, so the
drop-ins must remain installed until the boot image is updated. The
host uses `192.168.2.20/24`; the USB NCM interface name changes after each
reboot, so that host address must be assigned to the new interface.

## Remaining work

- The clock starts wrong because writing the Qualcomm RTC returns
  `RTC_SET_TIME: Permission denied`, but NTP corrects it after Wi-Fi connects.
- Bluetooth is not working: Bluebinder cannot open `/dev/vhci`; the running
  kernel lacks `CONFIG_BT_HCIVHCI`. A matching `hci_vhci.ko` was built on the
  host, but the attempted USB HTTP transfer timed out. The zero-byte phone
  file was removed, and the module was not loaded or tested. Bluebinder was
  disabled and stopped after 1,331 unsuccessful restarts to avoid wasting CPU
  during a day-long test. Re-enable it with
  `systemctl enable --now bluebinder.service` only after a working `/dev/vhci`
  is available.
- Claude Code 2.1.274, Codex 0.158.0, and Antigravity CLI 1.2.12 are installed
  under `/home/phablet/.local/bin`. The user reports running Codex on the
  phone; Claude and Antigravity authentication are not verified. The
  native `DRE Terminal` launcher runs via X11 because Click confinement and
  Mir launch fail on this development kernel. The user confirmed its own
  keyboard, buttons, and press-and-hold text selection work. `DRE OpenStore`
  also starts, but its UI is laggy; ordinary Click app launches are not yet
  reliable.
- Cellular, calls, SMS, audio, camera, suspend, and charging behavior are not
  yet acceptance-tested. There is no SIM installed.
- Build a safe installer and document a verified restore path before treating
  this as a redistributable Ubuntu Touch port.
