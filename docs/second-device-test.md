# Second-device test plan (DE2117)

This is a staged test plan for a spare OnePlus Nord N200. **It is not an
installation guide yet.** The first phone proves the development boot can work;
it does not prove another phone can be installed or restored safely. DE2118
must be identified and validated separately before using DE2117 artifacts.

## 1. Prepare without modifying the phone

1. Record the model printed in Settings or on the device label. The supported
   test target is **DE2117**; stop for DE2118 or any other model.
2. Save personal data elsewhere. Unlocking a bootloader or installing another
   OS can erase the phone. Keep a charged battery and a known-good USB cable.
3. On the phone's existing Android installation, enable USB debugging and
   authorize the test computer. Connect **only one** Android device.
4. From a clone of this repository, run `./scripts/preflight-device.sh`.
   This reads properties through ADB and does not reboot or write to the phone.
5. Save the pass/fail result without sharing device identifiers. If it fails,
   stop and investigate the mismatch rather than changing partitions blindly.

The preflight checks the known DE2117, `holi`, unlocked bootloader, A/B dynamic
partition layout, Android 12 OnePlus vendor fingerprint, and LineageOS 23.2
`dre` baseline. A pass means **only** that these properties resemble the first
phone. It does not verify the boot partition contents or prove recovery.

## 2. Recovery gate — currently blocked

Before flashing even a boot partition, verify a restore procedure for this
exact phone and baseline, including the correct slot and matching boot stack.
The first-phone audit found matching LineageOS boot artifacts but **not** a
complete, tested stock restore path. See `docs/bootstrap-log.md`.

**Do not run `fastboot flash`, erase userdata, change active slots, flash
firmware/vendor/super/DTBO/vbmeta/vendor_boot, or execute an unattended flash
helper based on this repository.** There is no public installation bundle or
rollback instruction that has passed a second-device test.

## 3. Development installation — not yet published

The working first phone uses a development boot image plus Ubuntu and Android
root filesystems on userdata, with some manual post-install changes. The repo
does not yet recreate that state from a clean clone. This stage stays blocked
until a build produces hashed artifacts, a guarded installer reproduces the
first phone, and a restore rehearsal succeeds. Do not substitute a boot image
from another slot or model.

## 4. Acceptance checklist after an independently verified install

Record pass, fail, or not tested for each item. Do not treat an untested item
as working.

| Check | First-phone baseline | Second-phone result |
| --- | --- | --- |
| Cold boot to setup and home, unplugged | Pass | Not tested |
| Reboot without USB and return to home | Pass | Not tested |
| Touch edges, keyboard, power lock, volume | Pass | Not tested |
| Wi-Fi scan, connect, and reconnect after reboot | Pass | Not tested |
| Terminal opens; select/copy text; Codex starts | Pass | Not tested |
| OpenStore launches and an app opens | Partial | Not tested |
| Bluetooth scan and pair | Fail | Not tested |
| Mobile data, voice calls, SMS with SIM | Not tested | Not tested |
| Speaker, microphone, headset | Not tested | Not tested |
| Front and rear cameras | Not tested | Not tested |
| Suspend/wake, battery drain, charging | Not tested | Not tested |
| Stock restore and re-install | Not tested | Not tested |

Note the model, active slot, firmware/LineageOS baseline, artifact hashes,
test date, and any reproduction steps. Review logs for personal information
before sharing them. See `evidence/README.md` for the repository's redaction
convention.
