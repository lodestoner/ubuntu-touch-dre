# Ubuntu Touch Port for OnePlus Nord N200 5G (`dre`)

## Outcome

Create a native Ubuntu Touch port for the OnePlus Nord N200 5G, model DE2117,
codename `dre`. Ubuntu Touch and Lomiri will be the primary operating system.
LineageOS will not host Ubuntu Touch; Android-derived components will exist only
as the Halium hardware-compatibility layer required by proprietary device
drivers and services.

The first useful milestone is a booted Ubuntu userspace reachable through USB.
The first visual milestone is Lomiri with working display and touch. Hardware
enablement and distribution packaging follow only after those milestones.

## Verified Target

The connected development unit reported:

- Product/model: OnePlus Nord N200 5G, DE2117
- Device codename: `dre` (the installed Lineage build uses `OnePlusN200`)
- Platform: Qualcomm SM4350 (`holi`), Snapdragon 480, arm64
- Kernel currently installed: Linux 5.4
- Partition scheme: A/B, dynamic partitions, virtual A/B
- Boot state: bootloader unlocked; verified boot state `orange`
- Current system: LineageOS 23.2 / Android 16, active slot A

The OnePlus Nord N100 (`billie2`) is a reference port, not the target. It uses
the related but different SM4250 platform, Android 10/Halium 10 base, kernel,
partition layout, and device configuration. Its UBports project is useful for
OnePlus-specific conventions, Lomiri device settings, telephony integration,
installer structure, and known kernel patch patterns. No N100 boot, DTB, DTBO,
vendor, or partition image may be flashed to the N200.

## Selected Architecture

Use the current UBports standalone-kernel porting method with:

- Ubuntu Touch root filesystem and Lomiri as the native userspace
- Halium 12 generic system image
- LineageOS 19.1 device sources for `dre`, the oldest published `dre` branch
- The matching OnePlus SM4350 Linux 5.4 kernel source
- Android 12 vendor firmware and proprietary interfaces from the N200
- A device-specific UBports port repository containing `deviceinfo`, overlays,
  hooks, build metadata, and CI configuration

Halium 12 is selected because UBports maps Android 12 ports to LineageOS 19.1,
and LineageOS publishes a `dre` branch at that version. Halium 13 adds change
without a device-specific advantage. A generic Android or Linux GSI used alone
would be a diagnostic experiment, not the intended finished architecture.

## Workspaces and Reproducibility

The project root is `~/src/ubuntu-touch-dre`. Keep the small port repository
separate from large, reproducible source checkouts and build outputs. Record:

- Upstream URLs, branches, and immutable commit IDs
- Firmware/vendor baseline and its checksums
- Host packages and tool versions
- Every generated image and its checksum
- Every flash operation, target slot, result, and rollback command
- Bring-up observations in a concise milestone log

Large Android/Halium trees, extracted proprietary files, firmware packages,
and build artifacts must be gitignored. Do not commit proprietary blobs unless
their redistribution is explicitly permitted.

## Bring-up Sequence

### 1. Establish recovery facts

Before flashing, collect the bootloader variables, partition table, active
slot, and current image metadata. Identify a tested recovery path and obtain
known-good, model-specific boot/recovery images or a complete factory restore
package. Verify checksums and confirm that fastboot and fastbootd are both
reachable. Userdata preservation is not required.

Do not assume that slot switching alone is a rollback: virtual A/B devices can
share dynamic-partition state, and firmware compatibility spans both slots.

### 2. Establish the Android 12 baseline

Ubuntu Touch must use a vendor/firmware baseline compatible with the selected
Halium version. Determine whether the currently installed Android 16 system
retained a suitable Android 12 vendor/firmware base. If not, restore the exact
supported N200 Android 12 firmware before Halium testing.

The DE2117 variant must remain explicit. Firmware or modem images for another
regional N200 model require separate validation.

### 3. Create the source manifest

Build a minimal Halium 12 manifest using the LineageOS 19.1 `dre` device tree,
matching kernel, required Qualcomm/OnePlus common trees, and vendor extraction
configuration. Pin revisions once the first reproducible build succeeds.

### 4. Make the kernel Halium-compatible

Start from the matching SM4350 kernel configuration. Apply only required
Ubuntu Touch/Halium changes, including binder, namespaces, cgroups, AppArmor,
security, and initramfs requirements. Prefer adapting proven patches from
current UBports ports, including `billie2` where the kernel lineage genuinely
matches, rather than copying its complete kernel configuration.

Validate the kernel configuration before creating a boot image. Preserve the
N200 command line, DTB/DTBO handling, header version, ramdisk compression, and
boot image layout.

### 5. Boot with increasing risk

Use the least persistent supported test first:

1. `fastboot boot` a test image, if the N200 bootloader accepts it.
2. If temporary boot is unavailable, flash only the explicitly chosen inactive
   boot slot and retain the original active boot path.
3. Reach the Halium/Ubuntu initramfs and obtain USB networking or ADB/telnet.
4. Install or flash the Ubuntu Touch rootfs only after initramfs access works.
5. Boot Lomiri, then validate display and touch.

Before each persistent command, record the resolved partition and slot plus an
exact rollback command. Never use an unresolved shell variable or wildcard in
a flash command.

### 6. Enable hardware in dependency order

After Lomiri boots, work through:

1. Display, GPU acceleration, and touch
2. USB, charging, buttons, vibration, and battery reporting
3. Wi-Fi and Bluetooth
4. Audio playback/recording and routing
5. Cellular registration, SMS, calls, data, and call audio
6. Suspend/resume, sensors, GPS, fingerprint, and camera
7. Encryption, offline charging, recovery, reset, and update behavior

Track each function as working, partial, broken, or untested, with the exact
build used. A booting UI is not evidence that telephony or suspend is safe.

### 7. Package only after bring-up

Once the port is reproducible and core hardware is stable, add community-port
CI, recovery/update images, installer configuration, documented firmware
prerequisites, and OTA channels. Upstream reusable kernel and Halium fixes.

## Failure Handling

- A failed connectivity check means device state is unknown, not safe.
- Capture serial/USB logs and the last boot stage before changing another
  variable.
- Change one boot-critical input at a time.
- If the device enters crashdump or cannot reach bootloader/fastbootd, stop
  normal flashing and use the documented model-specific recovery path.
- Do not use N100 images to test whether the hardware is "close enough."
- Treat EDL restoration as a last-resort recovery method; prepare required
  authorized tooling before relying on it.

## Verification Gates

Each stage must meet its gate before the next:

- **Recovery ready:** known-good restore material exists and both normal
  bootloader and userspace fastboot behavior are documented.
- **Sources ready:** all repositories sync at recorded commits; proprietary
  extraction completes without missing required files.
- **Kernel ready:** configuration checks pass and the build is reproducible.
- **Initramfs ready:** the phone boots the test kernel and exposes a debug path.
- **Userspace ready:** Ubuntu rootfs reaches a stable shell across reboots.
- **Visual ready:** Lomiri renders with working touch and hardware acceleration.
- **Core phone ready:** Wi-Fi, audio, suspend, cellular, SMS, calls, and mobile
  data pass repeatable tests.
- **Distribution ready:** a clean documented install and rollback work from the
  required stock firmware baseline, followed by an OTA update test.

## Explicit Non-goals for Initial Bring-up

- Preserving current userdata
- Dual-boot as a finished feature
- Running Ubuntu Touch inside LineageOS or Waydroid
- Supporting the N100 or other N200 regional variants
- Publishing an installer before the manual process is reproducible
- Claiming daily-driver status from a successful UI boot

## Primary References

- UBports porting introduction:
  <https://docs.ubports.com/en/latest/porting/introduction/Intro.html>
- UBports standalone-kernel installation flow:
  <https://docs.ubports.com/en/latest/porting/build_and_boot/standalone_kernel_install.html>
- LineageOS `dre` device tree:
  <https://github.com/LineageOS/android_device_oneplus_dre>
- UBports N100 (`billie2`) reference port:
  <https://gitlab.com/ubports/porting/community-ports/android10/oneplus-nord-n100/oneplus-billie2>
- UBports N100 kernel reference:
  <https://gitlab.com/ubports/porting/community-ports/android10/oneplus-nord-n100/kernel-oneplus-sm4250>

