#!/bin/sh
set -eu
cd "$(dirname "$0")"
test -f luci-theme-uniwrt/Makefile
test -f luci-theme-uniwrt/htdocs/luci-static/uniwrt/cascade.css
test -f luci-theme-uniwrt/htdocs/luci-static/uniwrt/mobile.css
test -f luci-theme-uniwrt/htdocs/luci-static/uniwrt/css/uniwrt.css
test -f luci-theme-uniwrt/htdocs/luci-static/uniwrt/js/uniwrt.js
test -f luci-theme-uniwrt/ucode/template/themes/uniwrt/header.ut
test -f luci-theme-uniwrt/ucode/template/themes/uniwrt/footer.ut
test -f luci-theme-uniwrt/ucode/template/themes/uniwrt/sysauth.ut
node --check luci-theme-uniwrt/htdocs/luci-static/uniwrt/js/uniwrt.js
sh -n luci-theme-uniwrt/root/etc/uci-defaults/30_luci-theme-uniwrt
python3 - <<'PY2'
import yaml, pathlib
yaml.safe_load(pathlib.Path('.github/workflows/build.yml').read_text())
PY2
echo "Static QA passed"
