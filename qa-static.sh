#!/bin/sh
set -eu
cd "$(dirname "$0")"

required_files='luci-theme-uniwrt/Makefile
luci-theme-uniwrt/htdocs/luci-static/uniwrt/cascade.css
luci-theme-uniwrt/htdocs/luci-static/uniwrt/mobile.css
luci-theme-uniwrt/htdocs/luci-static/uniwrt/logo.svg
luci-theme-uniwrt/htdocs/luci-static/uniwrt/css/uniwrt.css
luci-theme-uniwrt/htdocs/luci-static/uniwrt/js/uniwrt.js
luci-theme-uniwrt/ucode/template/themes/uniwrt/header.ut
luci-theme-uniwrt/ucode/template/themes/uniwrt/footer.ut
luci-theme-uniwrt/ucode/template/themes/uniwrt/sysauth.ut
luci-theme-uniwrt/luasrc/view/themes/uniwrt/header.htm
luci-theme-uniwrt/luasrc/view/themes/uniwrt/footer.htm
luci-theme-uniwrt/luasrc/view/themes/uniwrt/sysauth.htm
luci-theme-uniwrt/root/etc/uci-defaults/30_luci-theme-uniwrt
.github/workflows/build.yml'

echo "$required_files" | while IFS= read -r file; do
  [ -f "$file" ] || { echo "Missing required file: $file" >&2; exit 1; }
done

node --check luci-theme-uniwrt/htdocs/luci-static/uniwrt/js/uniwrt.js
sh -n luci-theme-uniwrt/root/etc/uci-defaults/30_luci-theme-uniwrt

# Do not accidentally ship captured/proprietary portal strings/assets inside the package.
if grep -RInE 'UniFi|ubnt|Ubiquiti' luci-theme-uniwrt; then
  echo "Proprietary/captured brand string found in package tree" >&2
  exit 1
fi

python3 - <<'PY'
import pathlib, re, sys, yaml
workflow = yaml.safe_load(pathlib.Path('.github/workflows/build.yml').read_text())
assert workflow['name'] == 'Build UniWRT Packages'
css = pathlib.Path('luci-theme-uniwrt/htdocs/luci-static/uniwrt/css/uniwrt.css').read_text()
js = pathlib.Path('luci-theme-uniwrt/htdocs/luci-static/uniwrt/js/uniwrt.js').read_text()
assert 'UniWRT Portal v2' in css
assert 'UNIWRT_VERSION = "2.0.0"' in js
assert 'LUCI_PKGARCH:=all' in pathlib.Path('luci-theme-uniwrt/Makefile').read_text()
for path in ['header.ut','footer.ut','sysauth.ut']:
    assert pathlib.Path('luci-theme-uniwrt/ucode/template/themes/uniwrt', path).exists()
print('Static QA passed')
PY
