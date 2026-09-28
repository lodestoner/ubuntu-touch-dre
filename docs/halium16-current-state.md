# Halium 16 development boot: converted DE2118

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

The handset was originally DE2118. Its owner converted it with
MSMDownloadTool to US DE2117 firmware before this bring-up; Android reports
DE2117. The boot result does not validate stock DE2118 firmware.

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

## September 28 repair update (not cold-boot verified)

A device-local repair pass rebuilt kernel-matched Bluetooth, audio, and camera
modules and installed them under the running kernel's `updates/dre/` module
directory. It also changed udev permissions, hardware-service ordering,
device-info/oFono configuration, Click launch compatibility, media-hub context
handling, and X11 launchers for Settings and Firefox. The work and its backups
remain on the phone; this repository does not yet reproduce them from a clean
build. The repair pass did not reboot or flash a boot partition.

- Bluebinder is now active. `/dev/vhci` exists, the Bluetooth controller
  powers on, and discovery start/stop passed. Pairing and headset audio were
  not tested.
- The audio DSP is online, a real output and input are present, and silent
  playback completed. Audible output, microphone recording, and call routing
  were not tested.
- The camera backend supplied preview frames and the app opened. Saved photos,
  video, camera switching, and image quality were not tested. An accelerometer
  reading was recorded; other sensor sessions opened without physical tests.
- oFono reported the modem online with no SIM. No cellular service was tested.
- OpenStore, Chromium, and Camera launch through wrappers because AppArmor is
  disabled in the running kernel. This improves app launch but provides no
  Click confinement. SELinux remains permissive. Firefox and Settings use X11
  launchers. MTP remains unavailable because the custom rescue gadget owns USB.
- The owner's terminal remained active through screen lock after a Lomiri
  lifecycle exemption. Its persistence after reboot is not verified.

At a subsequent live check, the phone was at home/lock after roughly nine hours
of uptime. No systemd units were failed; Bluebinder, the Android container,
hardware setup, Wi-Fi setup, and LightDM were active. The battery reported
`Charging`, 91%, and 25.4 °C in one sample. This does not establish charging
rate, thermal safety over time, or post-repair cold-boot reliability.

## Remaining work

- The clock starts wrong because writing the Qualcomm RTC returns
  `RTC_SET_TIME: Permission denied`, but NTP corrects it after Wi-Fi connects.
- The earlier Bluebinder failure was resolved in the running session by the
  module and permission repairs above. Its startup after a cold boot and
  pairing behavior remain unverified.
- Claude Code 2.1.274, Codex 0.158.0, and Antigravity CLI 1.2.12 are installed
  under `/home/phablet/.local/bin`. The user reports running Codex on the
  phone; Claude and Antigravity authentication are not verified. The
  native `DRE Terminal` launcher runs via X11 because Click confinement and
  Mir launch fail on this development kernel. The user confirmed its own
  keyboard, buttons, and press-and-hold text selection work. Ordinary Click
  apps now launch through an unconfined workaround; broader app behavior and
  confinement remain unresolved.
- Cellular, calls, SMS, audible sound, saved camera output, suspend, and
  charging over time are not yet acceptance-tested. There is no SIM installed.
- Validate the post-repair boot in an agreed maintenance window. Recheck the
  repaired services and user-facing hardware afterward; do not infer boot
  persistence from a warm running session.
- Build a safe installer and document a verified restore path before treating
  this as a redistributable Ubuntu Touch port.
