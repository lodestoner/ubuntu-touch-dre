# Second-device test plan (converted DE2118)

This is a staged test plan for a spare OnePlus Nord N200. **It is not an
installation guide yet.** The first phone proves the development boot can work;
it does not prove another phone can be installed or restored safely. Both
project phones were originally DE2118 and converted to US DE2117 firmware
with MSMDownloadTool; only the first has booted this port. This plan does not
cover an unconverted DE2118.

## 1. Prepare without modifying the phone

1. Record the original model on the device label and the model Android
   currently reports as separate facts. The test target is a converted DE2118
   reporting **DE2117** in Android. A DE2118 label alone is not a mismatch;
   stop if Android still reports DE2118 or another model.
2. Save personal data elsewhere. Unlocking a bootloader or installing another
   OS can erase the phone. Keep a charged battery and a known-good USB cable.
3. On the phone's existing Android installation, enable USB debugging and
   authorize the test computer. Connect **only one** Android device.
4. From a clone of this repository, run `./scripts/preflight-device.sh`.
   This reads properties through ADB and does not reboot or write to the phone.
5. Save the pass/fail result without sharing device identifiers. If it fails,
   stop and investigate the mismatch rather than changing partitions blindly.

The preflight checks the reported DE2117, `holi`, unlocked bootloader, A/B
dynamic partition layout, Android 12 OnePlus vendor fingerprint, and LineageOS
23.2 `dre` baseline. A pass means **only** that these properties resemble the
first phone. It cannot infer the factory model, verify the boot partition
contents, or prove recovery.

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
as working. The [device QA tracker](device-qa.md) records the fuller feature
list and distinguishes a working service from a user-visible result.

| Check | First-phone baseline | Second-phone result |
| --- | --- | --- |
| Cold boot to setup and home, unplugged | Pass before September 28 repairs; post-repair test pending | Not tested |
| Reboot without USB and return to home | Pass before September 28 repairs; post-repair test pending | Not tested |
| Touch edges, keyboard, power lock, volume | Pass | Not tested |
| Wi-Fi scan, connect, and reconnect after reboot | Pass | Not tested |
| Terminal opens; select/copy text; Codex starts | Pass | Not tested |
| OpenStore launches and an app opens | Partial; Click apps launch through an unconfined workaround | Not tested |
| Bluetooth scan and pair | Partial; discovery passed, pairing untested | Not tested |
| Mobile data, voice calls, SMS with SIM | Not tested | Not tested |
| Speaker, microphone, headset | Audio devices and silent playback passed; audible/recorded sound untested | Not tested |
| Front and rear cameras | Preview frames passed; photo/video capture untested | Not tested |
| Rotation, proximity, ambient light | Accelerometer sample passed; physical behavior untested | Not tested |
| Suspend/wake, battery drain, charging | Single charging-status sample; endurance untested | Not tested |
| Stock restore and re-install | Not tested | Not tested |

Note both the factory and Android-reported models, active slot,
firmware/LineageOS baseline, artifact hashes, test date, and any reproduction
steps. Review logs for personal information before sharing them. See
`evidence/README.md` for the repository's redaction convention.
