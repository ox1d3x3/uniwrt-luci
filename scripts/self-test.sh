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
assert version == '0.1.6', f'Unexpected VERSION: {version}'
makefile = root.joinpath('Makefile').read_text()
assert 'PKG_VERSION:=0.1.6' in makefile
pkg_block = makefile.split('define Package/luci-theme-uniwrt', 1)[1].split('endef', 1)[0]
assert 'PKGARCH:=all' in pkg_block, 'PKGARCH:=all must be inside the package definition'
prelude = makefile.split('define Package/luci-theme-uniwrt', 1)[0]
assert 'PKGARCH:=all' not in prelude, 'PKGARCH:=all must not be only global/prelude metadata'
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

# Metadata parser smoke tests for universal package formats.
meta_mock="/tmp/uniwrt-meta-mock-$$"
rm -rf "$meta_mock"
mkdir -p "$meta_mock/ipk/control" "$meta_mock/apk"
printf '2.0\n' > "$meta_mock/ipk/debian-binary"
printf 'Package: luci-theme-uniwrt\nVersion: 0.1.6-r1\nArchitecture: all\n' > "$meta_mock/ipk/control/control"
tar -C "$meta_mock/ipk/control" -czf "$meta_mock/ipk/control.tar.gz" control
tar -C "$meta_mock/ipk/control" -czf "$meta_mock/ipk/data.tar.gz" control
( cd "$meta_mock/ipk" && ar rcs "$meta_mock/test.ipk" debian-binary control.tar.gz data.tar.gz )
control_member="$(ar t "$meta_mock/test.ipk" | awk '/^control\.tar/ { print; exit }')"
ar p "$meta_mock/test.ipk" "$control_member" > "$meta_mock/control.tar"
tar -C "$meta_mock" -xaf "$meta_mock/control.tar"
grep -q '^Architecture: all$' "$meta_mock/control"
printf 'pkgname = luci-theme-uniwrt\npkgver = 0.1.6-r1\narch = all\n' > "$meta_mock/apk/.PKGINFO"
tar -C "$meta_mock/apk" -czf "$meta_mock/test.apk" .PKGINFO
apk_member="$(tar -tf "$meta_mock/test.apk" | awk '/(^|\/)\.PKGINFO$/ { print; exit }')"
tar -xOf "$meta_mock/test.apk" "$apk_member" | grep -Eq '^arch = (all|noarch)$'
rm -rf "$meta_mock"
echo 'self-test-ok'
