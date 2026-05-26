#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n scripts/build-sdk.sh
bash -n scripts/package.sh
bash -n scripts/install.sh
bash -n scripts/uninstall.sh
sh -n root/etc/uci-defaults/30_luci-theme-uniwrt
node --check htdocs/luci-static/uniwrt/uniwrt.js >/dev/null
python3 - <<'PY'
from pathlib import Path
from xml.etree import ElementTree as ET
root = Path('.')
version = root.joinpath('VERSION').read_text().strip()
assert version == '0.1.9', f'Unexpected VERSION: {version}'
makefile = root.joinpath('Makefile').read_text()
assert 'PKG_VERSION:=0.1.9' in makefile
assert '$(eval $(call BuildPackage,luci-theme-uniwrt))' in makefile
workflow = root.joinpath('.github/workflows/build-prerelease.yml').read_text()
assert 'Build universal IPK/APK' in workflow
assert './scripts/package.sh' in workflow
assert './scripts/build-sdk.sh' not in workflow
packager = root.joinpath('scripts/package.sh').read_text()
assert 'Architecture: all' in packager
assert 'arch = all' in packager
assert '${PKG_NAME}.apk' in packager
assert '${PKG_NAME}.ipk' in packager
for name in ['logo.svg', 'favicon.svg']:
    ET.parse(root / 'htdocs/luci-static/uniwrt' / name)
print('static-ok')
PY

echo 'self-test-ok'
