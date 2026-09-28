#!/usr/bin/env bash
set -euo pipefail

config=${1-}
[[ -f "$config" ]] || { printf 'kernel config is missing\n' >&2; exit 1; }

required_y=(
  64BIT SYSVIPC NAMESPACES UTS_NS IPC_NS USER_NS PID_NS NET_NS
  CGROUPS CGROUP_FREEZER CPUSETS MEMCG
  DEVTMPFS DEVTMPFS_MOUNT OVERLAY_FS BLK_DEV_LOOP UNIX98_PTYS IPV6
  SECURITY SECURITYFS AUDIT SECURITY_APPARMOR DEFAULT_SECURITY_APPARMOR
  ANDROID_BINDER_IPC USB_CONFIGFS_RNDIS
)

failures=0
for symbol in "${required_y[@]}"; do
  if ! grep -qx "CONFIG_${symbol}=y" "$config"; then
    printf 'required: CONFIG_%s=y\n' "$symbol" >&2
    failures=$((failures + 1))
  fi
done

if ! grep -qx 'CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"' "$config"; then
  printf 'required: CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"\n' >&2
  failures=$((failures + 1))
fi

if grep -qx 'CONFIG_ANDROID_BINDER_IPC_32BIT=y' "$config"; then
  printf 'incompatible: CONFIG_ANDROID_BINDER_IPC_32BIT=y on arm64\n' >&2
  failures=$((failures + 1))
fi

(( failures == 0 )) || exit 1
printf 'kernel config satisfies bootstrap requirements\n'
