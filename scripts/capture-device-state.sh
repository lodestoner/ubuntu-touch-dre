#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/scripts/lib/device.sh"

assert_dre_identity
transport=$(detect_transport)
stamp=$(date -u +%Y%m%dT%H%M%SZ)
private_dir="$ROOT/evidence/private/$stamp"
public_dir="$ROOT/evidence/device/$stamp"
mkdir -p "$private_dir" "$public_dir"

capture() {
  local output=$1
  shift
  { "$@"; } >"$private_dir/$output" 2>&1 || true
}

capture host-tools.txt bash -c 'adb version; fastboot --version'

if [[ "$transport" == adb ]]; then
  serial=$(adb get-serialno 2>/dev/null | tr -d '\r')
  capture adb-devices.txt adb devices -l
  capture properties.txt adb shell "$(selected_properties_command)"
  capture kernel.txt adb shell 'uname -a; cat /proc/cmdline'
  capture partitions-by-name.txt adb shell ls -l /dev/block/by-name
  capture partitions.txt adb shell cat /proc/partitions
  capture bootctl.txt adb shell bootctl status
  slot=$(normalize_slot "$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')")
else
  serial=$(fastboot devices 2>/dev/null | awk 'NR==1 {print $1}')
  capture fastboot-devices.txt fastboot devices -l
  capture fastboot-vars.txt fastboot getvar all
  raw_slot=$(fastboot getvar current-slot 2>&1 | sed -n 's/.*current-slot:[[:space:]]*//p' | head -1 | tr -d '\r')
  slot=$(normalize_slot "$raw_slot")
fi

for input in "$private_dir"/*.txt; do
  output="$public_dir/$(basename "$input")"
  if [[ -n "$serial" && "$serial" != unknown ]]; then
    sed -E "s/${serial//\//\\/}/<redacted-serial>/g; s/androidboot\.serialno=[^[:space:]]+/androidboot.serialno=<redacted-serial>/g" "$input" >"$output"
  else
    sed -E 's/androidboot\.serialno=[^[:space:]]+/androidboot.serialno=<redacted-serial>/g' "$input" >"$output"
  fi
done

cat >"$public_dir/summary.txt" <<EOF
captured_utc=$stamp
transport=$transport
canonical_device=dre
model=DE2117
platform=holi
active_slot=$slot
EOF

ln -sfn "$stamp" "$ROOT/evidence/device/.current-new"
mv -Tf "$ROOT/evidence/device/.current-new" "$ROOT/evidence/device/current"
printf '%s\n' "$public_dir"
