#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK="$ROOT/scripts/check-kernel-config.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/good.config" <<'EOF'
CONFIG_64BIT=y
CONFIG_SYSVIPC=y
CONFIG_NAMESPACES=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CPUSETS=y
CONFIG_MEMCG=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_OVERLAY_FS=y
CONFIG_BLK_DEV_LOOP=y
CONFIG_UNIX98_PTYS=y
CONFIG_IPV6=y
CONFIG_SECURITY=y
CONFIG_SECURITYFS=y
CONFIG_AUDIT=y
CONFIG_SECURITY_APPARMOR=y
CONFIG_DEFAULT_SECURITY_APPARMOR=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
# CONFIG_ANDROID_BINDER_IPC_32BIT is not set
CONFIG_USB_CONFIGFS_RNDIS=y
EOF

"$CHECK" "$tmp/good.config"

for symbol in ANDROID_BINDER_IPC USB_CONFIGFS_RNDIS SYSVIPC NAMESPACES CGROUPS DEVTMPFS OVERLAY_FS BLK_DEV_LOOP UNIX98_PTYS IPV6 SECURITY SECURITY_APPARMOR; do
  sed "s/^CONFIG_${symbol}=y$/# CONFIG_${symbol} is not set/" "$tmp/good.config" >"$tmp/bad-$symbol"
  output=$("$CHECK" "$tmp/bad-$symbol" 2>&1 || true)
  if [[ "$output" != *"CONFIG_${symbol}"* ]]; then
    printf 'FAIL: missing named error for CONFIG_%s\n' "$symbol" >&2
    exit 1
  fi
done

sed 's/# CONFIG_ANDROID_BINDER_IPC_32BIT is not set/CONFIG_ANDROID_BINDER_IPC_32BIT=y/' "$tmp/good.config" >"$tmp/bad-32bit"
output=$("$CHECK" "$tmp/bad-32bit" 2>&1 || true)
[[ "$output" == *CONFIG_ANDROID_BINDER_IPC_32BIT* ]] || {
  printf 'FAIL: missing named 32-bit binder incompatibility\n' >&2
  exit 1
}

printf 'PASS: kernel config fixtures\n'
