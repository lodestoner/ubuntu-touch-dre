#!/usr/bin/env bash

normalize_slot() {
  case "${1-}" in
    _a|a) printf 'a\n' ;;
    _b|b) printf 'b\n' ;;
    *) printf 'invalid slot: %s\n' "${1-<empty>}" >&2; return 1 ;;
  esac
}

selected_properties_command() {
  printf '%s\n' 'getprop ro.product.model; getprop ro.product.device; getprop ro.product.board; getprop ro.product.manufacturer; getprop ro.build.version.release; getprop ro.build.version.sdk; getprop ro.build.display.id; getprop ro.lineage.version; getprop ro.board.platform; getprop ro.boot.slot_suffix; getprop ro.boot.dynamic_partitions; getprop ro.virtual_ab.enabled; getprop ro.treble.enabled; getprop ro.boot.verifiedbootstate'
}

assert_dre_values() {
  local model=${1-} device=${2-} board=${3-}
  [[ "$model" == "DE2117" ]] || { printf 'wrong model: %s\n' "$model" >&2; return 1; }
  [[ "$device" == "OnePlusN200" || "$device" == "dre" ]] || {
    printf 'wrong device: %s\n' "$device" >&2
    return 1
  }
  [[ "$board" == "holi" ]] || { printf 'wrong board: %s\n' "$board" >&2; return 1; }
}

transport_from_vars() {
  local adb_present=${1-no} fastboot_present=${2-no} userspace=${3-no}
  if [[ "$adb_present" == yes ]]; then
    printf 'adb\n'
  elif [[ "$fastboot_present" == yes && "$userspace" == yes ]]; then
    printf 'fastbootd\n'
  elif [[ "$fastboot_present" == yes ]]; then
    printf 'fastboot\n'
  else
    printf 'none\n'
  fi
}

detect_transport() {
  local adb_present=no fastboot_present=no userspace=no
  if adb get-state 2>/dev/null | grep -qx device; then
    adb_present=yes
  fi
  if fastboot devices 2>/dev/null | grep -q '[^[:space:]]'; then
    fastboot_present=yes
    if fastboot getvar is-userspace 2>&1 | grep -Eq 'is-userspace:[[:space:]]*yes'; then
      userspace=yes
    fi
  fi
  transport_from_vars "$adb_present" "$fastboot_present" "$userspace"
}

assert_dre_identity() {
  local transport
  transport=$(detect_transport)
  case "$transport" in
    adb)
      assert_dre_values \
        "$(adb shell getprop ro.product.model | tr -d '\r')" \
        "$(adb shell getprop ro.product.device | tr -d '\r')" \
        "$(adb shell getprop ro.product.board | tr -d '\r')"
      ;;
    fastboot|fastbootd)
      local product
      product=$(fastboot getvar product 2>&1 | sed -n 's/.*product:[[:space:]]*//p' | head -1 | tr -d '\r')
      [[ "$product" == "dre" || "$product" == "OnePlusN200" ]] || {
        printf 'wrong fastboot product: %s\n' "$product" >&2
        return 1
      }
      ;;
    *) printf 'N200 is not reachable through adb or fastboot\n' >&2; return 1 ;;
  esac
}
