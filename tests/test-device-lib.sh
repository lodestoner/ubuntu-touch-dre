#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/scripts/lib/device.sh"

failures=0

assert_eq() {
  local actual=$1 expected=$2
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: expected <%s>, got <%s>\n' "$expected" "$actual" >&2
    failures=$((failures + 1))
  fi
}

assert_fail() {
  if "$@" >/dev/null 2>&1; then
    printf 'FAIL: command unexpectedly succeeded: %q ' "$@" >&2
    printf '\n' >&2
    failures=$((failures + 1))
  fi
}

assert_eq "$(normalize_slot _a)" "a"
assert_eq "$(normalize_slot b)" "b"
assert_fail normalize_slot ""
assert_fail normalize_slot "slot_a"
assert_dre_values "DE2117" "OnePlusN200" "holi"
assert_fail assert_dre_values "BE2015" "OnePlusN100" "bengal"
assert_eq "$(transport_from_vars yes no no)" "adb"
assert_eq "$(transport_from_vars no yes no)" "fastboot"
assert_eq "$(transport_from_vars no yes yes)" "fastbootd"
assert_eq "$(transport_from_vars no no no)" "none"
assert_eq "$(selected_properties_command)" "getprop ro.product.model; getprop ro.product.device; getprop ro.product.board; getprop ro.product.manufacturer; getprop ro.build.version.release; getprop ro.build.version.sdk; getprop ro.build.display.id; getprop ro.lineage.version; getprop ro.board.platform; getprop ro.boot.slot_suffix; getprop ro.boot.dynamic_partitions; getprop ro.virtual_ab.enabled; getprop ro.treble.enabled; getprop ro.boot.verifiedbootstate"

if (( failures )); then
  exit 1
fi
printf 'PASS: device library fixtures\n'
