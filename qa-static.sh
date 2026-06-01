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
.github/workflows/build.yml
uniwrt-apply.sh'

echo "$required_files" | while IFS= read -r file; do
  [ -f "$file" ] || { echo "Missing required file: $file" >&2; exit 1; }
done

node --check luci-theme-uniwrt/htdocs/luci-static/uniwrt/js/uniwrt.js
sh -n luci-theme-uniwrt/root/etc/uci-defaults/30_luci-theme-uniwrt
sh -n uniwrt-apply.sh

# Guard against broken relative Bootstrap template includes in executable ucode lines.
if grep -RInE '^\{%[[:space:]]*include\("\.\./bootstrap/.*\.ut"' luci-theme-uniwrt/ucode/template/themes/uniwrt; then
  echo "Invalid relative Bootstrap ucode include found" >&2
  exit 1
fi


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
assert 'UNIWRT_VERSION = "2.0.6"' in js
assert 'body.uniwrt-software' in css
assert 'uniwrtProgressSweep' in css
assert 'decorateSoftwarePage' in js
assert 'body.modal-overlay-active #modal_overlay' in css
assert '/luci-static/bootstrap/cascade.css' in pathlib.Path('luci-theme-uniwrt/htdocs/luci-static/uniwrt/cascade.css').read_text()
assert 'data-uniwrt-tabfix' in js
assert 'cbi-dropdown li input[type=checkbox]' in css
assert '#modal_overlay.active,body.modal-overlay-active #modal_overlay' in css
assert 'LUCI_PKGARCH:=all' in pathlib.Path('luci-theme-uniwrt/Makefile').read_text()
for path in ['header.ut','footer.ut','sysauth.ut']:
    assert pathlib.Path('luci-theme-uniwrt/ucode/template/themes/uniwrt', path).exists()

# sysauth should not add a second JS include; bootstrap/sysauth already calls the active theme header.
for path in ['luci-theme-uniwrt/ucode/template/themes/uniwrt/sysauth.ut', 'luci-theme-uniwrt/luasrc/view/themes/uniwrt/sysauth.htm']:
    text = pathlib.Path(path).read_text()
    assert 'uniwrt.js' not in text
print('Static QA passed')
PY
