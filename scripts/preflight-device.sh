#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/scripts/lib/device.sh"

if ! command -v adb >/dev/null 2>&1; then
  printf 'ADB is missing. On Ubuntu, install the adb package.\n' >&2
  exit 1
fi

devices=$(adb devices) || {
  printf 'ADB failed. Check the USB cable and restart the ADB server.\n' >&2
  exit 1
}
device_count=$(awk 'NR > 1 && NF >= 2 { count++ } END { print count+0 }' <<<"$devices")
if [[ "$device_count" != 1 ]]; then
  printf 'Connect exactly one Android phone with USB debugging enabled; found %s.\n' "$device_count" >&2
  exit 1
fi
device_state=$(awk 'NR > 1 && NF >= 2 { print $2 }' <<<"$devices")
if [[ "$device_state" != device ]]; then
  printf 'ADB state is %s. Unlock the phone and authorize this computer.\n' "$device_state" >&2
  exit 1
fi

property() {
  adb shell getprop "$1" | tr -d '\r\n'
}

model=$(property ro.product.model)
device=$(property ro.product.device)
board=$(property ro.product.board)
slot=$(property ro.boot.slot_suffix)
verified_boot=$(property ro.boot.verifiedbootstate)
dynamic_partitions=$(property ro.boot.dynamic_partitions)
virtual_ab=$(property ro.virtual_ab.enabled)
vendor_fingerprint=$(property ro.vendor.build.fingerprint)
lineage_version=$(property ro.lineage.version)

printf 'Android-reported model: %s\nDevice: %s\nBoard: %s\n' "$model" "$device" "$board"
printf 'Slot: %s\nVerified boot: %s\n' "$slot" "$verified_boot"
printf 'LineageOS: %s\n' "${lineage_version:-not detected}"

assert_dre_values "$model" "$device" "$board" || exit 1
normalize_slot "$slot" >/dev/null || exit 1
if [[ "$verified_boot" != orange ]]; then
  printf 'Bootloader is not confirmed unlocked; stop before any boot-image test.\n' >&2
  exit 1
fi
if [[ "$dynamic_partitions" != true || "$virtual_ab" != true ]]; then
  printf 'Dynamic partitions or virtual A/B differ from the tested device.\n' >&2
  exit 1
fi
if [[ "$vendor_fingerprint" != OnePlus/OnePlusN200/OnePlusN200:12/* ]]; then
  printf 'Android 12 OnePlus vendor firmware was not confirmed.\n' >&2
  exit 1
fi
if [[ "$lineage_version" != 23.2-*-dre ]]; then
  printf 'The tested LineageOS 23.2 dre baseline was not confirmed.\n' >&2
  exit 1
fi

printf 'PASS: Android-reported DE2117 baseline matches the first test phone.\n'
printf 'This check cannot determine the original hardware model after conversion.\n'
printf 'This read-only check does not authorize flashing or installation.\n'
