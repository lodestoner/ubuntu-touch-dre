# Device QA tracker: converted DE2118

Status: September 28, 2026. This tracks the first phone, originally DE2118 and
converted with MSMDownloadTool to DE2117 firmware. The second phone has not
received an Ubuntu Touch installation. This is a development record, not an
installation guide or a supported-device claim.

The owner's device-local repair report records work completed without a
reboot. A later read-only check found the phone at home/lock with active
Android, hardware, Bluetooth, Wi-Fi, and display services; no failed system
units; and a single battery reading of `Charging`, 91%, 25.4 °C. Those checks
confirm the current session, not cold-boot persistence or user-facing feature
quality. The report and binary repair artifacts are not part of this repo.

**Status key:** Pass means the behavior required by that item was observed;
Partial means only part of the check or its backend passed; Fail means the
feature is known not to work in this image; Untested means no adequate result;
Blocked means a prerequisite is missing. Mark hardware-specific items N/A
only after confirming the phone lacks that hardware. A service being active
does not make its feature Pass.

This list follows the owner's UBports device checklist. The
[UBports device matrix](https://gitlab.com/ubports/infrastructure/devices.ubuntu-touch.io)
may use different feature names and support criteria; check the current
requirements before seeking a community or core listing.

## Actors

| Check | Status | Evidence or next test |
| --- | --- | --- |
| Manual brightness | Untested | Change brightness in Settings and observe the panel. |
| Notification LED | Untested | Confirm hardware applicability, then test notifications and charging. |
| Torch | Untested | Turn on the torch and inspect the rear LED. |
| Vibration in apps, notifications, keyboard | Untested | Test each trigger separately. |

## Bluetooth

| Check | Status | Evidence or next test |
| --- | --- | --- |
| Driver loaded at startup | Partial | Rebuilt module and Bluebinder work live; no post-repair cold boot. |
| Toggle and flight mode | Untested | Controller powered and discovery cycled; UI toggles/flight mode not tested. |
| Headset pairing and volume | Untested | Pair, reconnect, play audio, and adjust volume. |
| MAC stable across reboots | Untested | Compare privately after controlled boots; never publish the address. |

## Camera

| Check | Status | Evidence or next test |
| --- | --- | --- |
| Correct logical cameras | Partial | Three app-facing cameras appear; map each to the actual lens. |
| Camera flash | Untested | Capture with flash and inspect the light and saved image. |
| Photos | Partial | Preview frames arrive; capture, save, and view a photo. |
| Switch front/rear | Untested | Switch and verify the actual lens in use. |
| Video | Untested | Record, save, play back, and check audio sync. |

## Cellular

There was no SIM in the first phone during the repair pass. An online modem is
not evidence that any cellular feature works. Use the phone UI and oFono/Binder
diagnostics; this port does not use ModemManager as its telephony stack.

| Check | Status | Evidence or next test |
| --- | --- | --- |
| Carrier and signal | Untested | Insert a SIM and confirm registration and signal. |
| In-call speaker/earpiece routing | Untested | Switch routes during a real call. |
| Mobile data | Untested | Load a page with Wi-Fi disabled. |
| Mobile-data toggle and flight mode | Untested | Test both directions and recovery. |
| Incoming and outgoing calls | Untested | Test both directions on the intended carrier. |
| MMS send and receive | Untested | Test both directions with mobile data. |
| SIM PIN entry | Untested | Use a SIM with PIN enabled. |
| SMS send and receive | Untested | Test both directions. |
| Preferred network mode | Untested | Test available 2G/3G/4G choices without assuming each carrier supports them. |
| Preferred SIM for calls/SMS | Untested | First confirm whether this converted unit exposes multiple SIM slots. |
| Voice in calls | Untested | Confirm both parties can hear each other. |

## Endurance and GPU

| Check | Status | Evidence or next test |
| --- | --- | --- |
| More than 24 hours from full battery | Untested | Measure from 100% with normal radios and suspend. |
| One week without a required reboot | Untested | Record uptime and failures after other hardware fixes. |
| Spinner and Lomiri UI | Partial | Lomiri home is confirmed; spinner was not separately recorded. |
| Hardware video decoding | Untested | Test video playback and confirm the decode path. Hardware decode is disabled in the current Firefox profile. |

## Miscellaneous

| Check | Status | Evidence or next test |
| --- | --- | --- |
| Anbox kernel patches | Untested | Legacy checklist item; determine applicability before rating it. |
| AppArmor kernel support | Fail | AppArmor is disabled; Click apps use unconfined compatibility wrappers. |
| Battery percentage | Partial | Kernel reported 91%; compare with the UI and a later reading. |
| Correct date/time after offline reboot | Untested | RTC write failed earlier; test a reboot in flight mode in the agreed window. |
| Logs free of restart/error spam | Untested | No failed units live; inspect logs over a full boot and long run. |
| Charging while powered off | Untested | Requires a controlled shutdown; confirm it does not boot UT. |
| Charging while running | Partial | One `Charging` sample; verify percentage increases and charging stops at full. |
| Recovery image | Blocked | No working UBports recovery image or full stock restore drill. |
| Factory reset | Blocked | Do not test until install and restore are reproducible. |
| SD card | Untested | Confirm hardware applicability and test detection and access. |
| Shutdown and reboot | Partial | Unplugged restart passed before repairs; shutdown and post-repair boot pending. |
| Wireless charging | Untested | Confirm hardware applicability before rating. |

## Network and sensors

| Check | Status | Evidence or next test |
| --- | --- | --- |
| NFC | Untested | Confirm hardware applicability and test with a reader/tag. |
| Automatic brightness | Untested | Light sensor session opened; vary illumination and observe the screen. |
| Fingerprint reader | Untested | Confirm hardware applicability; enroll and unlock if present. |
| GPS | Untested | Obtain a real fix outdoors and record time to fix. |
| Proximity during a call | Untested | Session opened; test screen behavior during a real call. |
| Rotation in Lomiri | Untested | Accelerometer returned a reading; rotate the phone and observe UI. |
| Touch across the surface | Partial | Owner confirmed touch and edge gestures; a full-area grid test is pending. |

## Sound

| Check | Status | Evidence or next test |
| --- | --- | --- |
| Earphones and volume | Untested | Plug in earphones, verify routing, and adjust volume. |
| Loudspeaker and volume | Partial | Real output and silent playback passed; audible sound not tested. |
| Microphone recording | Partial | Real input exists; record and play back speech. |
| System effects and notifications | Untested | Trigger a screenshot, notification, and camera shutter. |

## USB and Wi-Fi

| Check | Status | Evidence or next test |
| --- | --- | --- |
| ADB on Ubuntu Touch | Fail | Current gadget exposes ACM/NCM rescue, not ADB; host `adb devices` was empty. |
| Wired external monitor | Untested | Confirm hardware capability and test if applicable. |
| MTP file transfer | Fail | `usb-moded` is masked while the custom rescue gadget owns USB. |
| Wi-Fi driver at startup | Pass | Earlier reboots reached connected Wi-Fi without manual recovery; recheck after repairs. |
| Wi-Fi toggle and flight mode | Untested | Test off/on and flight mode in the UI. |
| Hotspot and client data | Untested | Connect a second device and verify traffic. |
| Wi-Fi MAC stable across reboots | Untested | Compare privately after controlled boots; never publish the address. |

## Completion path

1. Test the user-visible items above while the first phone is running: audible
   audio, saved photos/video, Bluetooth pairing, sensors, charging trend, and
   Wi-Fi controls. Bring a headset and, for telephony, an appropriate SIM.
   Record date, build, steps, expected and actual results. Keep raw logs and
   device identifiers private.
2. Fix failures at their source. Restore AppArmor/Click confinement and provide
   a user image without unauthenticated root USB listeners. Do not remove the
   present rescue path from this development image before a recovery alternative
   is proven. Decide and document the SELinux enforcement policy. Resolve
   MTP/ADB expectations and test actual hardware behavior.
3. Agree an overnight maintenance window before disruptive tests. Then verify
   full power-off/cold boot, post-repair service startup, unplugged reboot,
   offline time and charging, and regression of all previously passing items.
4. Run the 24-hour battery test and one-week stability test only after boot,
   suspend, charging, and thermal behavior are understood.
5. Produce a pinned, reproducible build of the *current* Halium 16 setup,
   hashed install artifacts, a tested restore path, and a guarded installer.
   Install from a clean clone on the second converted DE2118 and repeat the
   checklist. The pinned Halium 12 source tree in this repo is historical and
   does not recreate the running phone.

Completing the tracker means every item has a dated result or a justified N/A,
not that every feature passes. A public installer or device listing requires
the separate recovery, reproducibility, security, and user-facing tests above.
