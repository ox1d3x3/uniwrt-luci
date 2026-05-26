#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n scripts/build-sdk.sh
bash -n scripts/install.sh
bash -n scripts/uninstall.sh
sh -n root/etc/uci-defaults/30_luci-theme-uniwrt
node --check htdocs/luci-static/uniwrt/uniwrt.js >/dev/null
python3 - <<'PY'
from pathlib import Path
from xml.etree import ElementTree as ET
for name in ['logo.svg', 'favicon.svg']:
    ET.parse(Path('htdocs/luci-static/uniwrt') / name)
print('svg-ok')
PY

mock="/tmp/uniwrt-sdk-mock-$$"
rm -rf "$mock"
mkdir -p "$mock/openwrt-sdk-test/bin" "$mock/openwrt-sdk-test/package"
printf 'ok\n' > "$mock/openwrt-sdk-test/README"
tar -C "$mock" -caf "$mock/openwrt-sdk-test.Linux-x86_64.tar.zst" openwrt-sdk-test
rm -rf "$mock/openwrt-sdk-test" "$mock/sdk"
tar -tf "$mock/openwrt-sdk-test.Linux-x86_64.tar.zst" > "$mock/sdk-tar-list.txt"
SDK_TOPDIR="$(awk -F/ 'NF { print $1; exit }' "$mock/sdk-tar-list.txt")"
tar -xf "$mock/openwrt-sdk-test.Linux-x86_64.tar.zst" -C "$mock"
mv "$mock/$SDK_TOPDIR" "$mock/sdk"
test -f "$mock/sdk/README"
rm -rf "$mock"
echo 'self-test-ok'
