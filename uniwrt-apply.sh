#!/bin/sh
# UniWRT helper script for quick recovery or local file install.
# Normal users should install the generated .ipk/.apk package instead.
set -eu

THEME_DIR="/www/luci-static/uniwrt"
TPL_UCODE="/usr/share/ucode/luci/template/themes/uniwrt"
TPL_LUA="/usr/lib/lua/luci/view/themes/uniwrt"

case "${1:-apply}" in
  apply)
    echo "Applying UniWRT as active LuCI theme..."
    uci -q set luci.themes.UniWRT='/luci-static/uniwrt'
    uci -q set luci.main.mediaurlbase='/luci-static/uniwrt'
    uci -q commit luci
    rm -f /tmp/luci-indexcache 2>/dev/null || true
    rm -rf /tmp/luci-modulecache 2>/dev/null || true
    /etc/init.d/uhttpd restart 2>/dev/null || true
    echo "Done. Hard-refresh LuCI (Ctrl+Shift+R)."
    ;;
  recover|bootstrap)
    echo "Recovering LuCI to Bootstrap..."
    uci -q set luci.main.mediaurlbase='/luci-static/bootstrap'
    uci -q commit luci
    rm -f /tmp/luci-indexcache 2>/dev/null || true
    rm -rf /tmp/luci-modulecache 2>/dev/null || true
    /etc/init.d/uhttpd restart 2>/dev/null || true
    echo "Done. LuCI should use Bootstrap again."
    ;;
  paths)
    echo "Static assets: $THEME_DIR"
    echo "ucode templates: $TPL_UCODE"
    echo "Lua templates: $TPL_LUA"
    ;;
  *)
    echo "Usage: $0 [apply|recover|bootstrap|paths]" >&2
    exit 1
    ;;
esac
