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
root = Path('.')
version = root.joinpath('VERSION').read_text().strip()
assert version == '0.1.8', f'Unexpected VERSION: {version}'
makefile = root.joinpath('Makefile').read_text()
assert 'PKG_VERSION:=0.1.8' in makefile
assert 'include $(INCLUDE_DIR)/package.mk' in makefile
assert '$(eval $(call BuildPackage,luci-theme-uniwrt))' in makefile
assert 'PKGARCH:=all' in makefile
assert 'LUCI_MK' not in makefile
build = root.joinpath('scripts/build-sdk.sh').read_text()
assert 'package/$PKG_NAME' in build
assert 'package/feeds/luci/$PKG_NAME/compile' not in build
assert './scripts/feeds install -a' not in build
workflow = root.joinpath('.github/workflows/build-prerelease.yml').read_text()
assert '25.12.4' in workflow and '24.10.6' in workflow
assert 'mediatek' in workflow and 'mt7622' in workflow
for name in ['logo.svg', 'favicon.svg']:
    ET.parse(root / 'htdocs/luci-static/uniwrt' / name)
print('static-ok')
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
