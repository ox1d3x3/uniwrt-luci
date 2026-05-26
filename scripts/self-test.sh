#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n scripts/build-sdk.sh
bash -n scripts/install.sh
bash -n scripts/uninstall.sh
sh -n root/etc/uci-defaults/30_luci-theme-uniwrt
node --check htdocs/luci-static/uniwrt/uniwrt.js >/dev/null
python3 - <<'PYINNER'
from pathlib import Path
from xml.etree import ElementTree as ET
root = Path('.')
version = root.joinpath('VERSION').read_text().strip()
assert version == '0.2.0', f'Unexpected VERSION: {version}'
makefile = root.joinpath('Makefile').read_text()
assert 'PKG_VERSION:=0.2.0' in makefile
assert 'UNIWRT_PKG_DIR' in makefile
assert 'include $(INCLUDE_DIR)/package.mk' in makefile
assert '$(eval $(call BuildPackage,luci-theme-uniwrt))' in makefile
assert 'DEPENDS:=+luci-base' in makefile
assert 'luci-theme-bootstrap' not in makefile
build = root.joinpath('scripts/build-sdk.sh').read_text()
assert 'package/custom/$PKG_NAME/compile' in build
assert './scripts/feeds install luci-base' in build
assert './scripts/feeds install -a' not in build
workflow = root.joinpath('.github/workflows/build-prerelease.yml').read_text()
assert '25.12.4' in workflow and '24.10.6' in workflow
assert 'target: x86' not in workflow
assert 'mediatek' in workflow and 'mt7622' in workflow
assert 'package/custom/${PACKAGE_NAME}/compile' in workflow
assert './scripts/feeds install -a' not in workflow
assert 'luci-theme-uniwrt.apk' in workflow and 'luci-theme-uniwrt.ipk' in workflow
for name in ['logo.svg', 'favicon.svg']:
    ET.parse(root / 'htdocs/luci-static/uniwrt' / name)
print('static-ok')
PYINNER

mock="/tmp/uniwrt-sdk-mock-$$"
rm -rf "$mock"
mkdir -p "$mock/openwrt-sdk-test/bin" "$mock/openwrt-sdk-test/package/custom"
printf 'ok
' > "$mock/openwrt-sdk-test/README"
tar -C "$mock" -caf "$mock/openwrt-sdk-test.Linux-x86_64.tar.zst" openwrt-sdk-test
rm -rf "$mock/openwrt-sdk-test" "$mock/sdk"
tar --zstd -xf "$mock/openwrt-sdk-test.Linux-x86_64.tar.zst" -C "$mock"
SDK_TOPDIR="$(find "$mock" -maxdepth 1 -type d -name 'openwrt-sdk-*' | sort -V | tail -n1)"
mv "$SDK_TOPDIR" "$mock/sdk"
test -f "$mock/sdk/README"
rm -rf "$mock"

echo 'self-test-ok'
