#!/bin/sh
# UniWRT helper script for OpenWrt routers.
#
# Default behaviour:
#   1) Detect luci-theme-uniwrt .apk or .ipk in the same folder as this script
#   2) Install it with the correct package manager
#   3) Apply UniWRT as the active LuCI theme
#   4) Clear LuCI caches and restart LuCI web services
set -eu

THEME_NAME="UniWRT"
THEME_MEDIA="/luci-static/uniwrt"
BOOTSTRAP_MEDIA="/luci-static/bootstrap"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
THEME_DIR="/www/luci-static/uniwrt"
TPL_UCODE="/usr/share/ucode/luci/template/themes/uniwrt"
TPL_LUA="/usr/lib/lua/luci/view/themes/uniwrt"

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

find_one_package() {
  pattern="$1"
  found=""
  count=0

  # Shell glob order is stable enough for package detection. If more than one
  # matching package exists, the last one in glob order is used and we warn.
  for file in $pattern; do
    [ -f "$file" ] || continue
    found="$file"
    count=$((count + 1))
  done

  [ "$count" -gt 1 ] && warn "multiple packages matched $(basename "$pattern"); using $(basename "$found")"
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

detect_package() {
  apk_pkg=""
  ipk_pkg=""

  apk_pkg="$(find_one_package "$SCRIPT_DIR/luci-theme-uniwrt"'*.apk' 2>/dev/null || true)"
  ipk_pkg="$(find_one_package "$SCRIPT_DIR/luci-theme-uniwrt"'*.ipk' 2>/dev/null || true)"

  if has_cmd apk; then
    [ -n "$apk_pkg" ] && { printf 'apk:%s\n' "$apk_pkg"; return 0; }
    [ -n "$ipk_pkg" ] && fail "found .ipk but this router uses apk. Copy the .apk package into: $SCRIPT_DIR"
    fail "no luci-theme-uniwrt .apk package found in: $SCRIPT_DIR"
  fi

  if has_cmd opkg; then
    [ -n "$ipk_pkg" ] && { printf 'ipk:%s\n' "$ipk_pkg"; return 0; }
    [ -n "$apk_pkg" ] && fail "found .apk but this router uses opkg. Copy the .ipk package into: $SCRIPT_DIR"
    fail "no luci-theme-uniwrt .ipk package found in: $SCRIPT_DIR"
  fi

  fail "neither apk nor opkg was found on this router"
}

install_package() {
  detected="$(detect_package)"
  pkg_type="${detected%%:*}"
  pkg_file="${detected#*:}"

  log "Detected package: $(basename "$pkg_file")"
  case "$pkg_type" in
    apk)
      log "Installing with apk..."
      apk add --allow-untrusted "$pkg_file"
      ;;
    ipk)
      log "Installing with opkg..."
      opkg install "$pkg_file"
      ;;
    *)
      fail "unsupported package type: $pkg_type"
      ;;
  esac
}

clear_luci_cache() {
  log "Clearing LuCI cache..."
  rm -rf /tmp/luci-* /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-templatecache 2>/dev/null || true
}

restart_luci_services() {
  log "Restarting LuCI web services..."
  [ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart 2>/dev/null || true
  [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart 2>/dev/null || true
}

verify_install() {
  [ -d "$THEME_DIR" ] || fail "theme assets were not installed at $THEME_DIR"

  if [ -d /usr/share/ucode/luci/template ]; then
    [ -d "$TPL_UCODE" ] || fail "ucode templates were not installed at $TPL_UCODE"
  fi

  log "Theme files found. Install looks OK."
}

apply_theme() {
  log "Applying $THEME_NAME as active LuCI theme..."
  uci -q set luci.themes."$THEME_NAME"="$THEME_MEDIA"
  uci -q set luci.main.mediaurlbase="$THEME_MEDIA"
  uci -q commit luci
  clear_luci_cache
  restart_luci_services
  log "Done. Hard-refresh LuCI with Ctrl+Shift+R."
}

recover_bootstrap() {
  log "Recovering LuCI to Bootstrap..."
  uci -q set luci.main.mediaurlbase="$BOOTSTRAP_MEDIA"
  uci -q commit luci
  clear_luci_cache
  restart_luci_services
  log "Done. LuCI should use Bootstrap again."
}

show_paths() {
  log "Script folder: $SCRIPT_DIR"
  log "Static assets: $THEME_DIR"
  log "ucode templates: $TPL_UCODE"
  log "Lua templates: $TPL_LUA"
}

show_usage() {
  cat <<EOF
Usage: $0 [install|apply|recover|bootstrap|detect|paths]

Commands:
  install    Detect local .apk/.ipk, install it, apply UniWRT, clear cache, restart LuCI. Default.
  apply      Apply UniWRT only. Use after the package is already installed.
  recover    Switch LuCI back to Bootstrap and clear cache.
  bootstrap  Same as recover.
  detect     Show which package file would be installed.
  paths      Show expected install paths.

Put this script in the same folder as one package file, for example:
  luci-theme-uniwrt_2.0.7-1_all.ipk     for OpenWrt 24.10 / opkg
  luci-theme-uniwrt-2.0.7-r1.apk        for OpenWrt 25.12+ / apk
EOF
}

case "${1:-install}" in
  install|auto)
    install_package
    verify_install
    apply_theme
    ;;
  apply)
    verify_install
    apply_theme
    ;;
  recover|bootstrap)
    recover_bootstrap
    ;;
  detect)
    detected="$(detect_package)"
    log "${detected%%:*}: ${detected#*:}"
    ;;
  paths)
    show_paths
    ;;
  help|-h|--help)
    show_usage
    ;;
  *)
    show_usage >&2
    exit 1
    ;;
esac
