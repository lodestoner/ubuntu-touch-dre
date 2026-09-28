# Ubuntu Touch for OnePlus Nord N200 5G (`dre`)

> **Experimental developer port, not an installer or daily-driver release.**
> The working phone was originally **DE2118**, then converted with
> MSMDownloadTool to US **DE2117** firmware before this port was tested.
> Stock/unconverted DE2118 has not been validated. Do not flash an image from
> this repository onto a phone.

Ubuntu Touch reaches the home screen on that converted phone, boots without a
computer, and connects to Wi-Fi. Touch, edge gestures, the power and volume
buttons, and a terminal work. Codex has been run *on the phone*. This is a
substantial bring-up milestone, but it is not yet a reproducible, safe
installation path.

## Status

| Area | Observed state on the first converted DE2118 |
| --- | --- |
| Boot and home screen | Working, including a fully unplugged restart |
| Touch and physical buttons | Working |
| Native Wi-Fi | Working and reconnecting after reboot |
| Terminal and Codex CLI | Working; terminal text selection uses press-and-hold → Select |
| OpenStore | Starts, but its UI is slow and Click app launch is unreliable |
| Bluetooth | Not working; the failing Bluebinder service is disabled |
| Cellular, calls, SMS, audio, camera, suspend, charging | Not acceptance-tested |

The development boot still has **unauthenticated root rescue services on its
USB network interface**, and AppArmor/Click confinement is not working. Do not
use it as a trusted primary phone or attach it to an untrusted USB host. See
[current technical state](docs/halium16-current-state.md) for the exact boot
chain, workarounds, and remaining risks.

## Start here: check a second phone safely

The only public device workflow today is a **read-only preflight**. It needs an
Android-running phone with USB debugging enabled and authorized for your
computer. It does not unlock, reboot, back up, install, or flash anything.

```sh
git clone https://github.com/lodestoner/ubuntu-touch-dre.git
cd ubuntu-touch-dre
sudo apt install adb
./scripts/preflight-device.sh
```

The check requires the same **Android-reported DE2117** / `holi` / Android 12
vendor / LineageOS 23.2 baseline observed on the working device. It cannot
determine the original model printed on the phone. If it fails, **stop** and
record the result; do not change firmware or slots to make it pass. The full
[second-device test guide](docs/second-device-test.md) explains the gates and
the test checklist. A phone still reporting DE2118 fails this preflight.

### DE2118-to-DE2117 conversion

Both project phones were originally DE2118 carrier variants. Their owner used
MSMDownloadTool to install US DE2117 firmware before Ubuntu Touch testing;
the first phone now reports DE2117 in Android and has booted this port. The
second phone's Ubuntu Touch installation remains untested. This is **not**
evidence that an unconverted DE2118 can use DE2117 images, or that the two
variants are identical in every respect. The exact MSM package and conversion
steps used here have not been recorded or validated as a public procedure.

An [N200 community installation report](https://community.e.foundation/t/my-install-on-oneplus-nord-n200/50081)
describes an MSM/EDL route to US firmware; it is background reading, **not**
an endorsed package or instruction to flash it. Firmware conversion, bootloader
unlocking, and carrier/SIM unlocking are separate operations. Do not attempt
conversion from this repository; first establish a device-specific, verified
restore path.

## What this repository contains

- `deviceinfo`, `overlay/`, and `manifests/`: the initial device configuration
  and pinned **Halium 12** source baseline. This is historical bring-up work,
  **not** a complete recipe for the running Halium 16 development boot.
- `kernel/` and `tools/`: later kernel configuration and boot/runtime helpers.
  These are developer sources, not a tested image builder or installer.
- `scripts/` and `tests/`: device identity, source validation, artifact checks,
  and the read-only preflight.
- `docs/bootstrap-log.md` and `docs/halium16-current-state.md`: dated evidence
  and the verified state of the first phone.

Large Android/Ubuntu root filesystems, vendor blobs, downloaded packages, and
boot images are **not** distributed here. The running phone also contains
manual configuration that has not yet been captured as a reproducible build.
The stale experimental `wait-and-flash.py` helper is intentionally not part of
the published source; it must not be used as an installer.

## Before a flashable release

We need a reproducible build and packaging process, a verified stock restore
path, an installation procedure tested end-to-end on the second phone, and
working confinement. Bluetooth and the remaining hardware also need testing.
Only then should we consider a downloadable image, UBports Installer support,
or a supported-device listing. [UBports' port-finalization guide](https://docs.ubports.com/en/latest/porting/finalize/)
describes recovery and installer work after functional bring-up.

## Contributing and verification

Reports from an N200 are welcome. Include the original hardware model and the
Android-reported model separately, plus the Android/firmware baseline, steps,
expected and actual behavior, and whether the test used the development image.
**Redact serial numbers, IMEI, MAC addresses, Wi-Fi names, account details,
tokens, and any raw device logs before posting.** Never post the contents of
`evidence/private/`.

Run the offline tests with `./scripts/check.sh`. They do not require a phone.
Source verification also uses `scripts/verify-sources.sh metadata/sources.lock`
and requires network access.
