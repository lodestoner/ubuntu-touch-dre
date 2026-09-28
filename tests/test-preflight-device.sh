#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/bin"

cat >"$temporary/bin/adb" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  devices)
    printf 'List of devices attached\n'
    printf 'hidden-serial\t%s\n' "${FAKE_ADB_STATE:-device}"
    if [[ "${FAKE_EXTRA_DEVICE:-no}" == yes ]]; then
      printf 'second-hidden-serial\tdevice\n'
    fi
    ;;
  'shell getprop ro.product.model') printf '%s\n' "${FAKE_MODEL:-DE2117}" ;;
  'shell getprop ro.product.device') printf 'OnePlusN200\n' ;;
  'shell getprop ro.product.board') printf 'holi\n' ;;
  'shell getprop ro.boot.slot_suffix') printf '_a\n' ;;
  'shell getprop ro.boot.verifiedbootstate') printf '%s\n' "${FAKE_VERIFIED_BOOT:-orange}" ;;
  'shell getprop ro.boot.dynamic_partitions') printf 'true\n' ;;
  'shell getprop ro.virtual_ab.enabled') printf 'true\n' ;;
  'shell getprop ro.vendor.build.fingerprint')
    printf '%s\n' "${FAKE_FINGERPRINT:-OnePlus/OnePlusN200/OnePlusN200:12/test/release-keys}" ;;
  'shell getprop ro.lineage.version') printf '%s\n' "${FAKE_LINEAGE:-23.2-test-dre}" ;;
  *) printf 'unexpected adb call: %s\n' "$*" >&2; exit 1 ;;
esac
EOF
chmod +x "$temporary/bin/adb"

run_preflight() {
  PATH="$temporary/bin:$PATH" "$ROOT/scripts/preflight-device.sh"
}

run_preflight >"$temporary/output"
grep -q 'PASS: DE2117 development baseline' "$temporary/output"
if grep -q 'hidden-serial' "$temporary/output"; then
  printf 'FAIL: serial leaked in preflight output\n' >&2
  exit 1
fi

for scenario in wrong_model locked wrong_firmware wrong_lineage multiple unauthorized; do
  if case "$scenario" in
    wrong_model) FAKE_MODEL=DE2118 run_preflight ;;
    locked) FAKE_VERIFIED_BOOT=green run_preflight ;;
    wrong_firmware) FAKE_FINGERPRINT='OnePlus/OnePlusN200/OnePlusN200:11/test/release-keys' run_preflight ;;
    wrong_lineage) FAKE_LINEAGE='22.2-test-dre' run_preflight ;;
    multiple) FAKE_EXTRA_DEVICE=yes run_preflight ;;
    unauthorized) FAKE_ADB_STATE=unauthorized run_preflight ;;
  esac >"$temporary/output" 2>&1; then
    printf 'FAIL: accepted %s\n' "$scenario" >&2
    exit 1
  fi
done

printf 'PASS: read-only device preflight fixtures\n'
