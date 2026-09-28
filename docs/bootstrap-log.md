# Bootstrap log

This log records the initial 2026-09-27 assessment. Its gate results are
historical, not the current phone status; see `docs/halium16-current-state.md`
for the working development boot and remaining release blockers.

## Initial gates (2026-09-27)

- Recovery: **BLOCKED** — known-good DE2117 restore artifacts and fastbootd
  behavior have not yet been verified.
- Android 12 vendor compatibility: **PASS FOR INITIAL BUILD** — the installed
  vendor fingerprint is the DE2117 OxygenOS Android 12 base required by the
  LineageOS `dre` installation instructions.
- Sources: **PASS** — pinned Halium 12 tree synced cleanly at the recorded
  device, hardware, and kernel commits.
- Kernel: **NOT STARTED**.
- First boot: **NOT STARTED**.

## 2026-09-27 device audit

- Redacted report: `evidence/device/20260927T085101Z/`
- Transport: ADB
- Identity: DE2117 / OnePlusN200 / `holi`; canonical port codename `dre`
- Active slot: A
- Partition architecture: dynamic partitions with virtual A/B
- Verified boot: orange (unlocked)
- `bootctl` is unavailable in the running LineageOS userspace; bootloader and
  fastbootd behavior still require a controlled reboot test.

Ruling: keep the recovery gate blocked after the Android-side audit because
neither a restore package nor fastbootd was actually exercised. Treating the
unlocked bootloader alone as recovery evidence would risk an unrecoverable
flash failure.

## 2026-09-27 recovery artifacts and vendor baseline

- The running build is LineageOS 23.2 dated 2026-09-25. Its official `dre`
  `boot.img` and `vendor_boot.img` were downloaded from LineageOS and match the
  SHA-256 values published by its device-build API.
- LineageOS documents Android 12 firmware as the prerequisite for `dre`. The
  installed vendor fingerprint is
  `OnePlus/OnePlusN200/OnePlusN200:12/SKQ1.210216.001/R.205d809_1-735849:user/release-keys`.
  The generic vendor release/API properties report 16/36 because the running
  LineageOS build overlays current system properties; the vendor fingerprint
  is the relevant firmware lineage evidence.
- LineageOS identifies `boot` as the recovery partition and requires the boot
  stack partitions `dtbo`, `vbmeta`, and `vendor_boot` for recovery installs.
- A complete authoritative DE2117 stock restore package with a verified Linux
  restore procedure has not been established. OnePlus Qualcomm EDL/MSM tools
  commonly used for this model are Windows-specific and may require device-
  specific authorization. The recovery gate therefore remains **BLOCKED** for
  persistent firmware or dynamic-partition writes.

Ruling: the Android 12 compatibility gate passes for source/build work, but
the recovery gate remains blocked. This permits compilation and temporary
`fastboot boot` testing; it does not authorize persistent firmware, vendor,
super, DTBO, vbmeta, or vendor-boot changes.

## 2026-09-27 source selection

- Base manifest: Halium `halium-12.0` at
  `07e1ae2cec9108932f87085f80ae581a6c819f2d`.
- Device: LineageOS `android_device_oneplus_dre` `lineage-19.1` at
  `689ab738cbdaff2c748ae9004bca59a273af2f99`.
- Device-declared dependencies: `android_hardware_oneplus` and
  `android_kernel_oneplus_sm4350`, both pinned in `metadata/sources.lock`.
- The device tree specifies boot header v3, 4096-byte kernel page size,
  `vendor/holi-qgki_defconfig`, DTB in boot, separate DTBO, recovery-as-boot,
  and 100663296-byte boot/vendor-boot partitions.
- `repo sync -c --no-tags --no-clone-bundle -j4` completed successfully.
  `repo status` reported a clean tree. The shallow checkout occupies 91 GB;
  143 GB remained free immediately after sync.

## 2026-09-27 initial device configuration

- The official 2026-09-25 Lineage boot image confirms boot header v3; its
  vendor-boot image confirms 4096-byte pages, standard Qualcomm offsets, and
  the device-tree kernel command line.
- Live and source evidence agree on 100663296-byte boot and vendor-boot
  partitions, 1080x2400 display geometry, `holi`, arm64, and
  `vendor/holi-qgki_defconfig`.
- The initial command line targets `/dev/mapper/system_a` because the audited
  development state is slot A and that mapper exists. Slot-independent rootfs
  discovery must replace this before installer/OTA packaging.

Ruling: use the build-tool field `deviceinfo_bootimg_partition_size` rather
than the plan's generic `deviceinfo_boot_partition_size`; current UBports
Android 12 ports consume the former. If wrong, boot-image size protection would
not be applied by the build tooling, so the local validator also enforces the
live partition limit.

## 2026-09-27 kernel baseline

- Generating the unmodified `vendor/holi-qgki_defconfig` succeeded after
  installing the missing host packages `flex`, `bison`, `libssl-dev`,
  `libelf-dev`, and their dependencies.
- The unmodified resolved configuration lacks `CONFIG_IPC_NS`,
  `CONFIG_USER_NS`, `CONFIG_PID_NS`, `CONFIG_DEVTMPFS`,
  `CONFIG_DEVTMPFS_MOUNT`, `CONFIG_SECURITY_APPARMOR`, and
  `CONFIG_DEFAULT_SECURITY_APPARMOR`.
- AppArmor source is already present under `security/apparmor`; the first
  adaptation is therefore a configuration fragment only. No N100 kernel,
  defconfig, DTB, or board source is used.
