#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

bash tests/test-device-lib.sh
bash tests/test-preflight-device.sh
bash tests/test-deviceinfo.sh
bash tests/test-source-lock.sh
bash tests/test-kernel-config.sh
PYTHONPATH=. python3 tests/test-verify-artifact.py
python3 tests/test-dre-boot-hardware.py

printf 'PASS: repository checks\n'
