#!/bin/sh
# UniWRT helper script for OpenWrt routers.
#
# Default behaviour:
#   1) Detect luci-theme-uniwrt .apk or .ipk in the same folder as this script
#   2) Temporarily recover LuCI to Bootstrap so a broken theme cannot block LuCI
#   3) Remove any existing UniWRT package cleanly
#   4) Install the detected package with the correct package manager
#   5) Verify the installed theme files and version
#   6) Apply UniWRT, clear LuCI caches and restart LuCI web services
set -eu

THEME_NAME="UniWRT"
PKG_NAME="luci-theme-uniwrt"
EXPECTED_VERSION="2.0.13"
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

  apk_pkg="$(find_one_package "$SCRIPT_DIR/$PKG_NAME"'*.apk' 2>/dev/null || true)"
  ipk_pkg="$(find_one_package "$SCRIPT_DIR/$PKG_NAME"'*.ipk' 2>/dev/null || true)"

  if has_cmd apk; then
    [ -n "$apk_pkg" ] && { printf 'apk:%s\n' "$apk_pkg"; return 0; }
    [ -n "$ipk_pkg" ] && fail "found .ipk but this router uses apk. Copy the .apk package into: $SCRIPT_DIR"
    fail "no $PKG_NAME .apk package found in: $SCRIPT_DIR"
  fi

  if has_cmd opkg; then
    [ -n "$ipk_pkg" ] && { printf 'ipk:%s\n' "$ipk_pkg"; return 0; }
    [ -n "$apk_pkg" ] && fail "found .apk but this router uses opkg. Copy the .ipk package into: $SCRIPT_DIR"
    fail "no $PKG_NAME .ipk package found in: $SCRIPT_DIR"
  fi

  fail "neither apk nor opkg was found on this router"
}

clear_luci_cache() {
  log "Clearing LuCI cache..."
  rm -rf \
    /tmp/luci-* \
    /tmp/luci-indexcache \
    /tmp/luci-modulecache \
    /tmp/luci-templatecache \
    /tmp/luci-sessions \
    2>/dev/null || true
}

restart_luci_services() {
  log "Restarting LuCI web services..."
  [ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart 2>/dev/null || true
  [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart 2>/dev/null || true
}

switch_bootstrap_no_restart() {
  log "Temporarily switching LuCI to Bootstrap for a safe clean install..."
  uci -q set luci.main.mediaurlbase="$BOOTSTRAP_MEDIA" || true
  uci -q commit luci || true
  clear_luci_cache
}

remove_existing_package() {
  log "Removing any existing UniWRT package before reinstall..."
  if has_cmd apk; then
    apk del "$PKG_NAME" >/dev/null 2>&1 || true
  elif has_cmd opkg; then
    opkg remove "$PKG_NAME" >/dev/null 2>&1 || true
  fi

  # Package managers should remove these, but keep this as a safety cleanup for
  # broken/partial old installs and cached files from earlier development rolls.
  rm -rf "$THEME_DIR" "$TPL_UCODE" "$TPL_LUA" 2>/dev/null || true
  clear_luci_cache
}

install_package() {
  detected="$(detect_package)"
  pkg_type="${detected%%:*}"
  pkg_file="${detected#*:}"

  log "Detected package: $(basename "$pkg_file")"
  switch_bootstrap_no_restart
  remove_existing_package

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

verify_install() {
  log "Verifying installed UniWRT files..."
  [ -d "$THEME_DIR" ] || fail "theme assets were not installed at $THEME_DIR"
  [ -f "$THEME_DIR/cascade.css" ] || fail "missing $THEME_DIR/cascade.css"
  [ -f "$THEME_DIR/css/uniwrt.css" ] || fail "missing $THEME_DIR/css/uniwrt.css"
  [ -f "$THEME_DIR/js/uniwrt.js" ] || fail "missing $THEME_DIR/js/uniwrt.js"
  [ -f "$THEME_DIR/logo.svg" ] || fail "missing $THEME_DIR/logo.svg"

  if [ -d /usr/share/ucode/luci/template ]; then
    [ -f "$TPL_UCODE/header.ut" ] || fail "missing $TPL_UCODE/header.ut"
    [ -f "$TPL_UCODE/footer.ut" ] || fail "missing $TPL_UCODE/footer.ut"
    [ -f "$TPL_UCODE/sysauth.ut" ] || fail "missing $TPL_UCODE/sysauth.ut"
  fi

  if [ -d /usr/lib/lua/luci/view ]; then
    [ -f "$TPL_LUA/header.htm" ] || warn "Lua header.htm not found; this is OK on pure ucode LuCI builds"
    [ -f "$TPL_LUA/footer.htm" ] || warn "Lua footer.htm not found; this is OK on pure ucode LuCI builds"
    [ -f "$TPL_LUA/sysauth.htm" ] || warn "Lua sysauth.htm not found; this is OK on pure ucode LuCI builds"
  fi

  grep -q "$EXPECTED_VERSION" "$THEME_DIR/css/uniwrt.css" || fail "installed CSS does not contain version $EXPECTED_VERSION"
  grep -q "UNIWRT_VERSION = \"$EXPECTED_VERSION\"" "$THEME_DIR/js/uniwrt.js" || fail "installed JS does not contain version $EXPECTED_VERSION"
  grep -q "css/uniwrt.css?v=$EXPECTED_VERSION" "$TPL_UCODE/header.ut" 2>/dev/null || warn "ucode header does not show direct $EXPECTED_VERSION CSS link"

  log "Installed files verified for UniWRT v$EXPECTED_VERSION."
}

apply_theme() {
  log "Applying $THEME_NAME as active LuCI theme..."
  uci -q set luci.themes."$THEME_NAME"="$THEME_MEDIA"
  uci -q set luci.main.mediaurlbase="$THEME_MEDIA"
  uci -q commit luci
  clear_luci_cache
  restart_luci_services
  log "Done. Open a private/incognito LuCI window first, or hard-refresh with Ctrl+Shift+R."
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
  cat <<USAGE_EOF
Usage: $0 [install|apply|recover|bootstrap|detect|verify|paths]

Commands:
  install    Clean reinstall local .apk/.ipk, apply UniWRT, clear cache, restart LuCI. Default.
  apply      Apply UniWRT only. Use after the package is already installed.
  recover    Switch LuCI back to Bootstrap and clear cache.
  bootstrap  Same as recover.
  detect     Show which package file would be installed.
  verify     Verify installed UniWRT files and version.
  paths      Show expected install paths.

Put this script in the same folder as one package file, for example:
  luci-theme-uniwrt_2.0.13-1_all.ipk     for OpenWrt 24.10 / opkg
  luci-theme-uniwrt-2.0.13-r1.apk        for OpenWrt 25.12+ / apk
USAGE_EOF
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
  verify)
    verify_install
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
