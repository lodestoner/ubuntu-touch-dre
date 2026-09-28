#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VALIDATE="$ROOT/scripts/validate-deviceinfo.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/evidence" <<'EOF'
codename=dre
arch=aarch64
boot_partition_size=100663296
pagesize=4096
header_version=3
screen_width=1080
screen_height=2400
kernel_source=https://github.com/LineageOS/android_kernel_oneplus_sm4350.git
kernel_defconfig=vendor/holi-qgki_defconfig
EOF

write_good() {
  cat >"$1" <<'EOF'
deviceinfo_name="OnePlus Nord N200 5G"
deviceinfo_manufacturer="OnePlus"
deviceinfo_codename="dre"
deviceinfo_arch="aarch64"
deviceinfo_halium_version="12"
deviceinfo_kernel_source="https://github.com/LineageOS/android_kernel_oneplus_sm4350.git"
deviceinfo_kernel_source_branch="lineage-19.1"
deviceinfo_kernel_defconfig="vendor/holi-qgki_defconfig halium.config"
deviceinfo_kernel_cmdline="androidboot.hardware=qcom loop.max_part=7"
deviceinfo_kernel_image_name="Image"
deviceinfo_kernel_clang_compile="true"
deviceinfo_kernel_llvm_compile="true"
deviceinfo_flash_pagesize="4096"
deviceinfo_bootimg_header_version="3"
deviceinfo_bootimg_partition_size="100663296"
deviceinfo_screen_width="1080"
deviceinfo_screen_height="2400"
EOF
}

cat >"$tmp/halium.yaml" <<'EOF'
dre:
  Vendor: OnePlus
  codename: dre
  Names:
    - DE2117
    - OnePlusN200
  PrettyName: OnePlus Nord N200 5G
  DeviceType: phone
  GridUnit: 21
EOF

expect_fail() {
  if "$VALIDATE" "$1" "$tmp/evidence" "$tmp/halium.yaml" >/dev/null 2>&1; then
    printf 'FAIL: expected invalid fixture %s\n' "$1" >&2
    exit 1
  fi
}

write_good "$tmp/good"
"$VALIDATE" "$tmp/good" "$tmp/evidence" "$tmp/halium.yaml"

for case in codename arch n100 missing_size zero_page oversize; do
  write_good "$tmp/$case"
done
sed -i 's/deviceinfo_codename="dre"/deviceinfo_codename="billie2"/' "$tmp/codename"
sed -i 's/deviceinfo_arch="aarch64"/deviceinfo_arch="x86_64"/' "$tmp/arch"
sed -i 's/sm4350/sm4250/' "$tmp/n100"
sed -i '/deviceinfo_bootimg_partition_size=/d' "$tmp/missing_size"
sed -i 's/deviceinfo_flash_pagesize="4096"/deviceinfo_flash_pagesize="0"/' "$tmp/zero_page"
sed -i 's/deviceinfo_bootimg_partition_size="100663296"/deviceinfo_bootimg_partition_size="100663297"/' "$tmp/oversize"

expect_fail "$tmp/codename"
expect_fail "$tmp/arch"
expect_fail "$tmp/n100"
expect_fail "$tmp/missing_size"
expect_fail "$tmp/zero_page"
expect_fail "$tmp/oversize"

sed 's/OnePlusN200/OnePlusN100/' "$tmp/halium.yaml" >"$tmp/n100.yaml"
if "$VALIDATE" "$tmp/good" "$tmp/evidence" "$tmp/n100.yaml" >/dev/null 2>&1; then
  printf 'FAIL: N100 YAML name was accepted\n' >&2
  exit 1
fi

printf 'PASS: deviceinfo fixtures\n'
