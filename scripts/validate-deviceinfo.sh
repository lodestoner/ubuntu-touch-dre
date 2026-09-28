#!/usr/bin/env bash
set -euo pipefail

config=${1-}
evidence=${2-}
overlay=${3-overlay/system/etc/deviceinfo/devices/halium.yaml}
[[ -f "$config" ]] || { printf 'deviceinfo is missing\n' >&2; exit 1; }
[[ -f "$evidence" ]] || { printf 'partition evidence is missing\n' >&2; exit 1; }
[[ -f "$overlay" ]] || { printf 'device overlay is missing\n' >&2; exit 1; }

declare -A facts=()
while IFS='=' read -r key value; do
  [[ -n "$key" ]] || continue
  facts[$key]=$value
done <"$evidence"

read_config() {
  local name=$1
  bash --noprofile --norc -c 'set -u; source "$1"; name=$2; printf "%s" "${!name-}"' _ "$config" "$name"
}

require_equal() {
  local variable=$1 fact=$2 value
  value=$(read_config "$variable")
  [[ -n "$value" ]] || { printf '%s is missing\n' "$variable" >&2; exit 1; }
  [[ "$value" == "${facts[$fact]-}" ]] || {
    printf '%s does not match %s evidence\n' "$variable" "$fact" >&2
    exit 1
  }
}

require_equal deviceinfo_codename codename
require_equal deviceinfo_arch arch
require_equal deviceinfo_kernel_source kernel_source
require_equal deviceinfo_flash_pagesize pagesize
require_equal deviceinfo_bootimg_header_version header_version
require_equal deviceinfo_screen_width screen_width
require_equal deviceinfo_screen_height screen_height

kernel_defconfig=$(read_config deviceinfo_kernel_defconfig)
[[ "$kernel_defconfig" == "${facts[kernel_defconfig]} halium.config" ]] || {
  printf 'deviceinfo_kernel_defconfig must merge evidenced base with halium.config\n' >&2
  exit 1
}

partition_size=$(read_config deviceinfo_bootimg_partition_size)
[[ "$partition_size" =~ ^[1-9][0-9]*$ ]] || {
  printf 'deviceinfo_bootimg_partition_size must be a positive integer\n' >&2
  exit 1
}
(( partition_size <= facts[boot_partition_size] )) || {
  printf 'deviceinfo_bootimg_partition_size exceeds live evidence\n' >&2
  exit 1
}

page_size=$(read_config deviceinfo_flash_pagesize)
(( page_size > 0 )) || { printf 'deviceinfo_flash_pagesize must be positive\n' >&2; exit 1; }

if grep -Eqi 'billie2|OnePlusN100|sm4250|Nord N100' "$config" "$overlay"; then
  printf 'N100 identity or source is forbidden\n' >&2
  exit 1
fi

python3 - "$overlay" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as stream:
    data = yaml.safe_load(stream)
if not isinstance(data, dict) or "dre" not in data:
    raise SystemExit("overlay must contain dre")
record = data["dre"]
required = {
    "Vendor": "OnePlus",
    "codename": "dre",
    "PrettyName": "OnePlus Nord N200 5G",
    "DeviceType": "phone",
}
for key, expected in required.items():
    if record.get(key) != expected:
        raise SystemExit(f"overlay {key} must be {expected}")
names = record.get("Names", [])
if "DE2117" not in names or "OnePlusN200" not in names:
    raise SystemExit("overlay Names must contain DE2117 and OnePlusN200")
PY

printf 'deviceinfo validated for dre\n'
