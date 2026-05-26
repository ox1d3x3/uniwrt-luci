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
assert version == '0.2.8', f'Unexpected VERSION: {version}'
makefile = root.joinpath('Makefile').read_text()
workflow = root.joinpath('.github/workflows/build-prerelease.yml').read_text()
assert ('C' + 'leanX') not in makefile
assert ('c' + 'leanx') not in makefile
assert ('luci-theme-' + 'old-legacy-name') not in makefile
assert 'include $(INCLUDE_DIR)/package.mk' in makefile
assert 'luci.mk' not in makefile
assert 'DEPENDS:=+luci-base' not in makefile
assert 'PKG_NAME:=luci-theme-uniwrt' in makefile
assert 'PKG_VERSION:=0.2.8' in makefile
assert 'PKGARCH:=all' in makefile
assert '$(eval $(call BuildPackage,luci-theme-uniwrt))' in makefile
assert 'Build UniWRT pre-release packages' in workflow
assert ('C' + 'leanX') not in workflow
assert ('c' + 'leanx') not in workflow
assert ('CLEAN' + 'X_RELEASE_TOKEN') not in workflow
assert 'secrets.' not in workflow
assert 'GH_TOKEN: ${{ github.token }}' in workflow
assert 'contents: write' in workflow
assert './scripts/feeds install -a' not in workflow
assert './scripts/feeds install luci-base' not in workflow
assert 'luci-theme-uniwrt.apk' in workflow and 'luci-theme-uniwrt.ipk' in workflow
for name in ['logo.svg', 'favicon.svg']:
    ET.parse(root / 'htdocs/luci-static/uniwrt' / name)
assert not (root / '.github/workflows/build-openwrt-packages.yml').exists()
print('static-ok')
PYINNER

echo 'self-test-ok'
