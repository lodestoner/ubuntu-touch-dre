# OnePlus N200 Ubuntu Touch Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a reproducible Halium 12 build for the OnePlus Nord N200 5G (`dre`) and boot it far enough to reach an Ubuntu USB shell or Lomiri without using N100 images.

**Architecture:** A small git repository owns safety tooling, pinned source metadata, device configuration, and evidence. Large LineageOS/Halium sources and generated images live in ignored directories. Device work advances through hard gates: recovery facts, Android 12 compatibility, source sync, kernel validation, image validation, and finally a single-slot boot test.

**Tech Stack:** Bash, ADB, Android platform-tools (`adb`, `fastboot`), Git/Repo, LineageOS 19.1, Halium 12, UBports `halium-generic-adaptation-build-tools`, Linux 5.4/arm64, Python 3 for deterministic metadata validation.

**Spec:** `docs/superpowers/specs/2026-09-27-ubuntu-touch-dre-design.md`

## Global Constraints

- The sole hardware target is OnePlus Nord N200 5G DE2117, codename `dre`, Qualcomm SM4350/`holi`.
- The OnePlus Nord N100 `billie2` port is reference material only; never flash its images, DTB, DTBO, vendor, firmware, or partition data.
- Ubuntu Touch and Lomiri are the native userspace; LineageOS is not a host OS.
- Use Halium 12 with LineageOS 19.1 device sources and the matching OnePlus SM4350 kernel.
- Preserve exact upstream URLs, branches, commits, firmware identity, image hashes, flash target, and rollback commands.
- Do not commit proprietary blobs, firmware packages, Android source trees, or generated images.
- Resolve every partition and slot literally before flashing; no wildcard or unresolved variable may appear in a flash command.
- Do not cross a verification gate when its evidence is absent or ambiguous.

## File Map

- `README.md` — project purpose, phase status, and safe operator entry point.
- `scripts/lib/device.sh` — shared ADB/fastboot identity and slot checks.
- `scripts/capture-device-state.sh` — read-only device inventory captured before changes.
- `scripts/verify_artifact.py` — checksum and target-metadata validation for restore/build artifacts.
- `scripts/flash-boot-test.sh` — guarded temporary-boot or explicit-slot boot-image operation.
- `tests/test-device-lib.sh` — fixture tests for identity, slot, and mode parsing.
- `tests/test-verify-artifact.py` — unit tests for artifact validation failures.
- `tests/test-flash-guard.sh` — fake-fastboot tests proving unsafe flash requests stop.
- `evidence/README.md` — evidence layout and redaction rules.
- `evidence/device/` — captured non-secret hardware and partition reports.
- `metadata/sources.lock` — upstream URL, branch, and resolved commit records.
- `metadata/artifacts.json` — expected image/restore hashes and target identity.
- `manifests/dre.xml` — pinned local Repo manifest entries for device and kernel trees.
- `deviceinfo` — UBports device build and partition configuration for `dre`.
- `overlay/system/etc/deviceinfo/devices/halium.yaml` — Lomiri-facing N200 properties.
- `kernel/patches/series` — ordered, documented Halium/Ubuntu Touch kernel patches.
- `docs/bootstrap-log.md` — build IDs, gate results, boot observations, and rollback outcomes.

## Review Focus

- A connected N100 or another OnePlus model must be rejected before any persistent command; Task 1 fixture-tests mismatched product and codename.
- A phone in fastbootd instead of bootloader fastboot must be reported distinctly; Task 1 fixture-tests both modes.
- An empty, malformed, or ambiguous slot must stop flashing; Tasks 1 and 5 test `_a`, `a`, empty, and unexpected values.
- An artifact with the correct filename but wrong hash or target must be rejected; Task 2 tests both failure modes.
- A boot image that exceeds the reported boot partition or lacks expected Android boot metadata must not be used; Task 5 tests size and `unpack_bootimg` validation.

---

### Task 1: Device identity and recovery-state audit

**Files:**
- Create: `README.md`
- Create: `scripts/lib/device.sh`
- Create: `scripts/capture-device-state.sh`
- Create: `tests/test-device-lib.sh`
- Create: `evidence/README.md`
- Create: `docs/bootstrap-log.md`

**Interfaces:**
- Produces: `detect_transport() -> adb|fastboot|fastbootd|none`, `assert_dre_identity()`, `normalize_slot(raw) -> a|b`, and timestamped reports under `evidence/device/`.
- Consumes: `adb`, `fastboot`, `getprop`, `/proc/partitions`, and `/dev/block/by-name` exposed by the connected phone.

- [ ] **Step 1: Write fixture tests for identity, transport, and slot parsing**

Create a shell test that sources `scripts/lib/device.sh`, replaces `adb` and
`fastboot` with fixture functions, and asserts:

```bash
assert_eq "$(normalize_slot _a)" "a"
assert_eq "$(normalize_slot b)" "b"
assert_fail normalize_slot ""
assert_fail normalize_slot "slot_a"
assert_dre_values "DE2117" "OnePlusN200" "holi"
assert_fail assert_dre_values "BE2015" "OnePlusN100" "bengal"
assert_eq "$(transport_from_vars yes no no)" "adb"
assert_eq "$(transport_from_vars no yes no)" "fastboot"
assert_eq "$(transport_from_vars no yes yes)" "fastbootd"
```

- [ ] **Step 2: Run the fixture test and confirm it fails**

Run: `bash tests/test-device-lib.sh`

Expected: non-zero with `scripts/lib/device.sh: No such file or directory`.

- [ ] **Step 3: Implement the shared device guard**

Implement strict Bash functions (`set -euo pipefail`) which accept injectable
fixture values, require `DE2117`, accept the observed Android device name
`OnePlusN200` while recording canonical codename `dre`, require board `holi`,
and normalize only `_a`, `_b`, `a`, or `b`. `detect_transport` must use
`fastboot getvar is-userspace` to distinguish fastbootd.

- [ ] **Step 4: Implement the read-only capture script**

The script must assert identity, create `evidence/device/<UTC timestamp>/`, and
capture separate text files for:

```text
adb devices -l
selected getprop values
uname and /proc/cmdline
ls -l /dev/block/by-name
/proc/partitions
bootctl status (when available)
fastboot getvar all (only when already in fastboot)
host adb/fastboot versions
```

It must not reboot the phone. Filter serial numbers from committed evidence,
write the unredacted report only to an ignored `evidence/private/` directory,
and atomically update `evidence/device/current` to point at the newest redacted
report directory.

- [ ] **Step 5: Run syntax, fixture, and live read-only checks**

Run:

```bash
bash -n scripts/lib/device.sh scripts/capture-device-state.sh
bash tests/test-device-lib.sh
scripts/capture-device-state.sh
```

Expected: syntax and fixtures pass; the live report identifies DE2117,
OnePlusN200, `holi`, active slot `a`, dynamic partitions, and virtual A/B.

- [ ] **Step 6: Record the recovery gate result and commit**

In `docs/bootstrap-log.md`, record the report directory and mark the recovery
gate `BLOCKED` until known-good DE2117 restore artifacts and fastbootd behavior
are verified.

```bash
git add README.md scripts tests evidence/README.md evidence/device docs/bootstrap-log.md
git commit -m "feat: add guarded N200 device-state audit"
```

### Task 2: Restore-artifact and Android 12 baseline gate

**Files:**
- Create: `scripts/verify_artifact.py`
- Create: `tests/test-verify-artifact.py`
- Create: `metadata/artifacts.json`
- Modify: `docs/bootstrap-log.md`

**Interfaces:**
- Consumes: JSON records `{name, path, sha256, device, role, source_url}`.
- Produces: exit 0 only when every local artifact exists, hashes correctly, targets `dre`/DE2117, and has an allowed role (`boot`, `vendor_boot`, `recovery`, `firmware`, `rom`).

- [ ] **Step 1: Write artifact-verifier unit tests**

Use `unittest` and temporary files to test a valid SHA-256, wrong SHA-256,
missing file, `billie2` target rejection, absent source URL, and unknown role.

- [ ] **Step 2: Run tests and confirm they fail**

Run: `python3 -m unittest -v tests/test-verify-artifact.py`

Expected: import failure for `scripts.verify_artifact`.

- [ ] **Step 3: Implement deterministic artifact validation**

Implement `validate_record(record, project_root) -> list[str]` and a CLI taking
the JSON path. It must stream hashes in 1 MiB blocks, refuse paths outside the
project root, and print only artifact names and errors—not sensitive paths or
contents.

- [ ] **Step 4: Inventory authoritative recovery inputs**

Record source URLs and hashes for the exact DE2117 restore path and matching
Lineage recovery/boot material in `metadata/artifacts.json`. Downloaded files
belong under ignored `firmware/` or `downloads/`. If no Linux-capable complete
restore path exists, document the exact Windows/EDL dependency and keep the
gate blocked rather than claiming recovery readiness.

- [ ] **Step 5: Determine the installed vendor/firmware baseline**

Capture these read-only properties and partition build fingerprints:

```bash
adb shell getprop ro.vendor.build.version.release
adb shell getprop ro.vendor.build.version.sdk
adb shell getprop ro.vendor.build.fingerprint
adb shell getprop ro.bootimage.build.fingerprint
adb shell getprop ro.product.first_api_level
```

Compare them with the LineageOS 19.1 `dre` requirements. Record one explicit
decision: current vendor is compatible, or restore DE2117 Android 12 before
the first Halium rootfs test.

- [ ] **Step 6: Run validation and commit the gate evidence**

Run:

```bash
python3 -m unittest -v tests/test-verify-artifact.py
python3 scripts/verify_artifact.py metadata/artifacts.json
```

Expected: tests pass; live validation either passes completely or exits nonzero
and `docs/bootstrap-log.md` clearly retains a blocked recovery gate.

```bash
git add scripts/verify_artifact.py tests/test-verify-artifact.py metadata/artifacts.json docs/bootstrap-log.md
git commit -m "feat: gate porting on verified N200 recovery artifacts"
```

### Task 3: Pin the Halium 12 source graph

**Files:**
- Create: `metadata/sources.lock`
- Create: `manifests/dre.xml`
- Create: `scripts/verify-sources.sh`
- Create: `tests/test-source-lock.sh`
- Modify: `docs/bootstrap-log.md`

**Interfaces:**
- Produces: a Repo local manifest and lock entries formatted as `path<TAB>url<TAB>branch<TAB>commit`.
- Consumes: LineageOS 19.1/Android 12 base manifest, `android_device_oneplus_dre`, `android_kernel_oneplus_sm4350`, and every dependency discovered from their manifests/build files.

- [ ] **Step 1: Write source-lock fixture validation**

Test rejection of a symbolic-only revision, missing URL, duplicate path, commit
not present on the declared remote, and any path or URL containing `billie2` or
`sm4250`. Test acceptance of a 40-hex commit reachable from its remote.

- [ ] **Step 2: Implement and run the lock validator**

`scripts/verify-sources.sh` must parse tab-delimited lines, enforce unique safe
relative paths, require HTTPS upstream URLs, require 40 lowercase hex commits,
and verify each with `git ls-remote` without cloning.

Run: `bash tests/test-source-lock.sh`

Expected: all fixture cases pass.

- [ ] **Step 3: Resolve the complete source graph**

Initialize the official Halium 12/LineageOS 19.1 manifest in ignored `halium/`,
add `manifests/dre.xml` as the local manifest, and resolve device/kernel/common
dependencies. Record immutable commits in `metadata/sources.lock`; do not use a
floating branch as the build record.

- [ ] **Step 4: Sync and verify sources**

Run:

```bash
bash scripts/verify-sources.sh metadata/sources.lock
cd halium && repo sync -c --no-tags --no-clone-bundle -j4
cd halium && repo status
```

Expected: validator succeeds, sync completes, and `repo status` has no local
source edits before port patches are applied.

- [ ] **Step 5: Commit source metadata**

```bash
git add metadata/sources.lock manifests/dre.xml scripts/verify-sources.sh tests/test-source-lock.sh docs/bootstrap-log.md
git commit -m "build: pin Halium 12 source graph for dre"
```

### Task 4: Create and validate the N200 port configuration

**Files:**
- Create: `deviceinfo`
- Create: `overlay/system/etc/deviceinfo/devices/halium.yaml`
- Create: `scripts/validate-deviceinfo.sh`
- Create: `tests/test-deviceinfo.sh`
- Modify: `docs/bootstrap-log.md`

**Interfaces:**
- Produces: build-tool-compatible `deviceinfo` for arm64 `dre` and a Lomiri device record keyed by `dre`.
- Consumes: captured N200 partition sizes, boot image header details, kernel defconfig, DTB/DTBO arrangement, and display geometry.

- [ ] **Step 1: Write configuration rejection tests**

Fixtures must reject codename other than `dre`, architecture other than arm64,
kernel source containing `sm4250`, missing boot partition size, missing or zero
page size, N100 model names, and partition sizes larger than live evidence.

- [ ] **Step 2: Implement the configuration validator**

The validator must source `deviceinfo` in a clean Bash process, compare its
values to an explicit captured-evidence file, parse YAML with Ruby or Python's
available YAML parser, and fail if required `dre` identity fields are absent.

- [ ] **Step 3: Create minimal N200 configuration**

Populate exact values from Task 1 and source-tree build configuration. Include
only initial-boot settings: architecture, kernel source/defconfig, boot image
format, cmdline, partition sizing, DTB/DTBO handling, display geometry, and
USB debugging. Do not guess telephony, camera, notch, or sensor values from the
N100 overlay.

- [ ] **Step 4: Validate against live evidence**

Run:

```bash
bash tests/test-deviceinfo.sh
bash scripts/validate-deviceinfo.sh deviceinfo evidence/device/current/partition-facts.txt
```

Expected: fixtures and N200 configuration pass; any value not evidenced by the
device or source tree fails with a named field.

- [ ] **Step 5: Commit configuration**

```bash
git add deviceinfo overlay scripts/validate-deviceinfo.sh tests/test-deviceinfo.sh docs/bootstrap-log.md
git commit -m "feat: add minimal Ubuntu Touch device configuration for dre"
```

### Task 5: Adapt and build the Halium-compatible kernel

**Files:**
- Create: `kernel/patches/series`
- Create: `kernel/patches/*.patch`
- Create: `scripts/check-kernel-config.sh`
- Create: `tests/test-kernel-config.sh`
- Modify: `metadata/sources.lock`
- Modify: `docs/bootstrap-log.md`

**Interfaces:**
- Produces: a patched, pinned SM4350 source commit and a validated arm64 kernel/boot image.
- Consumes: the Task 3 source checkout and Task 4 device configuration.

- [ ] **Step 1: Write kernel-config fixture tests**

Create minimal good/bad `.config` fixtures. Assert required binder devices,
namespaces, cgroups, devtmpfs, overlayfs, loop, pseudo terminals, IPv6, security,
and AppArmor values. Assert explicitly incompatible options produce named
errors rather than a generic failure.

- [ ] **Step 2: Implement the config checker and establish baseline failures**

Run the checker against the unmodified `dre` defconfig and record every failure
in `docs/bootstrap-log.md`. This is the evidence for each patch/config change.

- [ ] **Step 3: Apply the minimum ordered patch series**

Port only changes required by the checker or a reproduced compile/boot error.
For every patch, record origin URL/commit when adapted from UBports, Halium, or
the N100 kernel. Never apply an SM4250 DTB, defconfig, or board file.

- [ ] **Step 4: Build and validate the kernel**

Use the Halium build environment and conservative parallelism (`-j4`) on this
16 GB host. Run the official UBports kernel configuration check plus the local
checker, then build the boot image. Save compiler version, commands, duration,
commit, image sizes, and SHA-256 in `docs/bootstrap-log.md`.

- [ ] **Step 5: Rebuild from a clean output directory**

Remove only the explicit ignored kernel output directory, rebuild at the same
commits, and compare the kernel/boot image structure. If byte reproducibility is
prevented by embedded timestamps, record the differing metadata and verify the
uncompressed kernel and DTB hashes separately.

- [ ] **Step 6: Commit the adaptation**

```bash
git add kernel scripts/check-kernel-config.sh tests/test-kernel-config.sh metadata/sources.lock docs/bootstrap-log.md
git commit -m "feat: adapt SM4350 kernel for Halium 12"
```

### Task 6: Build Ubuntu Touch images and cross the first boot gate

**Files:**
- Create: `scripts/flash-boot-test.sh`
- Create: `tests/test-flash-guard.sh`
- Modify: `metadata/artifacts.json`
- Modify: `docs/bootstrap-log.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: validated `boot.img`, UBports rootfs/system image, live DE2117 identity, explicit operation `boot` or `flash`, and explicit target slot for `flash`.
- Produces: a temporary boot or one explicit `boot_a`/`boot_b` write after printing and logging the rollback command.

- [ ] **Step 1: Write fake-fastboot guard tests**

Tests must prove rejection of wrong identity, fastbootd when bootloader fastboot
is required, blank slot, active-slot flash, image larger than partition, bad
hash, absent `unpack_bootimg`, unexpected boot header, and any requested
partition except `boot_a` or `boot_b`. Test that `boot` never invokes `flash`.

- [ ] **Step 2: Implement the guarded boot script**

The script must default to a dry run. Live operation requires `--execute`, an
artifact record that validates through Task 2, re-read fastboot identity, and:

```text
temporary path: fastboot boot <absolute validated boot.img>
persistent path: fastboot flash boot_b <absolute validated boot.img>
```

The persistent example is valid only when live evidence says slot A is active;
otherwise it must resolve literally to `boot_a`. Print the original-image
restore command and slot-switch command before prompting for a typed device
model plus target partition. Do not automate rootfs installation in this step.

- [ ] **Step 3: Build the UBports images**

Use the pinned port build tools to prepare the current supported Ubuntu Touch
rootfs and convert it into images. Record source channel/revision and SHA-256.
Run `unpack_bootimg` and compare header version, page size, cmdline, DTB/DTBO,
ramdisk compression, and total size with the stock/Lineage boot image.

- [ ] **Step 4: Run all offline safety tests and a dry run**

Run:

```bash
bash tests/test-flash-guard.sh
python3 scripts/verify_artifact.py metadata/artifacts.json
scripts/flash-boot-test.sh --operation boot --image out/boot.img
```

Expected: tests and artifact checks pass; dry run prints one temporary boot
command and no persistent command.

- [ ] **Step 5: Execute the least-persistent supported boot test**

With the phone already in verified bootloader fastboot, try temporary boot. If
the bootloader rejects it without modifying state, capture the exact error. Only
then consider the inactive-slot path, after revalidating the recovery gate and
capturing the inactive slot's original boot image where the bootloader permits.

- [ ] **Step 6: Capture first-boot evidence**

Capture USB enumeration changes, kernel/initramfs logs, and available debug
transport. Classify the result precisely:

```text
BOOTLOADER_REJECTED
KERNEL_NO_USB
INITRAMFS_USB
UBUNTU_SHELL
LOMIRI_NO_TOUCH
LOMIRI_TOUCH
```

Do not install the rootfs persistently until `INITRAMFS_USB` is repeatable.

- [ ] **Step 7: Commit the bootstrap result**

```bash
git add scripts/flash-boot-test.sh tests/test-flash-guard.sh metadata/artifacts.json docs/bootstrap-log.md README.md
git commit -m "test: record first Ubuntu Touch boot on dre"
```

## Completion Boundary

This plan is complete when the exact source/image set is reproducible and the
phone reaches `UBUNTU_SHELL` or `LOMIRI_TOUCH`, with a demonstrated rollback.
If it stops earlier, completion means the earliest failing stage is isolated
with logs and a minimal next hypothesis; it does not mean the port is complete.

Display/GPU/touch stabilization, phone hardware enablement, and community
installer/OTA packaging are intentionally separate follow-on plans.
