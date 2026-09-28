#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERIFY="$ROOT/scripts/verify-sources.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
url=https://github.com/LineageOS/android_device_oneplus_dre.git
commit=689ab738cbdaff2c748ae9004bca59a273af2f99
mkdir -p "$tmp/bin"
cat >"$tmp/bin/git" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == 'ls-remote --heads --tags $url' ]]; then
  printf '%s\trefs/heads/lineage-19.1\n' '$commit'
else
  exit 1
fi
EOF
chmod +x "$tmp/bin/git"
export PATH="$tmp/bin:$PATH"

expect_pass() {
  if ! "$VERIFY" "$1" >/dev/null 2>&1; then
    printf 'FAIL: expected pass for %s\n' "$1" >&2
    exit 1
  fi
}

expect_fail() {
  if "$VERIFY" "$1" >/dev/null 2>&1; then
    printf 'FAIL: expected rejection for %s\n' "$1" >&2
    exit 1
  fi
}

printf 'device/oneplus/dre\t%s\tlineage-19.1\t%s\n' "$url" "$commit" >"$tmp/good"
expect_pass "$tmp/good"

printf 'device/oneplus/dre\t%s\tlineage-19.1\tlineage-19.1\n' "$url" >"$tmp/symbolic"
expect_fail "$tmp/symbolic"

printf 'device/oneplus/dre\t\tlineage-19.1\t%s\n' "$commit" >"$tmp/no-url"
expect_fail "$tmp/no-url"

{ cat "$tmp/good"; cat "$tmp/good"; } >"$tmp/duplicate"
expect_fail "$tmp/duplicate"

printf 'device/oneplus/dre\t%s\tlineage-19.1\t%s\n' "$url" "0000000000000000000000000000000000000000" >"$tmp/missing-commit"
expect_fail "$tmp/missing-commit"

printf 'device/oneplus/billie2\thttps://github.com/example/sm4250.git\tlineage-19.1\t%s\n' "$commit" >"$tmp/n100"
expect_fail "$tmp/n100"

printf 'PASS: source lock fixtures\n'
