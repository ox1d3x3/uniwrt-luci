#!/bin/sh
# UniWRT universal installer/apply helper for OpenWrt.
#
# Put this script in the same folder as ONE UniWRT package:
#   - luci-theme-uniwrt*.apk  for OpenWrt 25.x+ / apk systems
#   - luci-theme-uniwrt*.ipk  for OpenWrt 24.x and older / opkg systems
#
# The script intentionally matches only the first package-name part:
#   luci-theme-uniwrt
# and ignores the version/revision part of the filename.

set -eu

THEME_NAME="UniWRT"
PKG_PREFIX="luci-theme-uniwrt"
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

openwrt_release() {
  if [ -r /etc/openwrt_release ]; then
    # shellcheck disable=SC1091
    . /etc/openwrt_release 2>/dev/null || true
    printf '%s' "${DISTRIB_RELEASE:-unknown}"
  else
    printf 'unknown'
  fi
}

openwrt_major() {
  rel="$(openwrt_release)"
  major="${rel%%.*}"
  case "$major" in
    ''|*[!0-9]*) return 1 ;;
    *) printf '%s' "$major" ;;
  esac
}

expected_format() {
  # OpenWrt 25.x+ uses apk. OpenWrt 24.x and older use opkg/ipk.
  # For SNAPSHOT/unknown releases, fall back to the package manager present.
  major="$(openwrt_major 2>/dev/null || true)"

  if [ -n "$major" ]; then
    if [ "$major" -ge 25 ]; then
      printf 'apk'
      return 0
    fi
    printf 'ipk'
    return 0
  fi

  if has_cmd apk && ! has_cmd opkg; then
    printf 'apk'
    return 0
  fi

  if has_cmd opkg && ! has_cmd apk; then
    printf 'ipk'
    return 0
  fi

  if has_cmd apk; then
    printf 'apk'
    return 0
  fi

  if has_cmd opkg; then
    printf 'ipk'
    return 0
  fi

  fail "neither apk nor opkg was found on this system"
}

find_latest_package() {
  ext="$1"
  # Package filenames are expected to be normal package filenames without spaces.
  # The glob deliberately ignores version/revision, e.g.:
  #   luci-theme-uniwrt-2.0.13-r1.apk
  #   luci-theme-uniwrt_2.0.13-1_all.ipk
  pkgs="$(ls -1t "$SCRIPT_DIR"/"$PKG_PREFIX"*."$ext" 2>/dev/null || true)"
  [ -n "$pkgs" ] || return 1

  count="$(printf '%s\n' "$pkgs" | sed '/^$/d' | wc -l | tr -d ' ')"
  pkg="$(printf '%s\n' "$pkgs" | sed -n '1p')"

  if [ "$count" -gt 1 ]; then
    warn "multiple .$ext packages found; using newest: $(basename "$pkg")"
  fi

  printf '%s\n' "$pkg"
}

package_version_hint() {
  file="$(basename "$1")"
  case "$file" in
    *.apk) file="${file%.apk}" ;;
    *.ipk) file="${file%.ipk}" ;;
  esac

  # Supports both common naming styles:
  #   luci-theme-uniwrt-2.0.13-r1
  #   luci-theme-uniwrt_2.0.13-1_all
  hint="${file#$PKG_PREFIX}"
  hint="${hint#-}"
  hint="${hint#_}"
  [ -n "$hint" ] && [ "$hint" != "$file" ] && printf '%s' "$hint" || true
}

wrong_package_error() {
  expected="$1"
  wrong="$2"
  rel="$(openwrt_release)"

  if [ "$expected" = "apk" ]; then
    fail "this router appears to be OpenWrt $rel / apk-based. Found .ipk only: $(basename "$wrong"). .ipk is not supported on this system. Please download/copy the .apk package."
  fi

  fail "this router appears to be OpenWrt $rel / opkg-based. Found .apk only: $(basename "$wrong"). .apk is not supported on this system. Please download/copy the .ipk package."
}

detect_package() {
  expected="$(expected_format)"
  rel="$(openwrt_release)"
  log "Detected OpenWrt release: $rel"
  log "Expected UniWRT package format: .$expected"

  case "$expected" in
    apk)
      pkg="$(find_latest_package apk 2>/dev/null || true)"
      if [ -n "$pkg" ]; then
        printf 'apk:%s\n' "$pkg"
        return 0
      fi
      wrong="$(find_latest_package ipk 2>/dev/null || true)"
      [ -n "$wrong" ] && wrong_package_error apk "$wrong"
      fail "no $PKG_PREFIX*.apk package found in: $SCRIPT_DIR"
      ;;
    ipk)
      pkg="$(find_latest_package ipk 2>/dev/null || true)"
      if [ -n "$pkg" ]; then
        printf 'ipk:%s\n' "$pkg"
        return 0
      fi
      wrong="$(find_latest_package apk 2>/dev/null || true)"
      [ -n "$wrong" ] && wrong_package_error ipk "$wrong"
      fail "no $PKG_PREFIX*.ipk package found in: $SCRIPT_DIR"
      ;;
    *)
      fail "unsupported expected package format: $expected"
      ;;
  esac
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
  log "Restarting LuCI services..."
  [ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart 2>/dev/null || true
  [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart 2>/dev/null || true
}

switch_to_bootstrap_no_restart() {
  log "Temporarily switching LuCI to Bootstrap for safe install..."
  uci -q set luci.main.mediaurlbase="$BOOTSTRAP_MEDIA" || true
  uci -q commit luci || true
  clear_luci_cache
}

remove_existing_uniwrt() {
  log "Removing existing UniWRT package/files if present..."

  if has_cmd apk; then
    apk del "$PKG_PREFIX" >/dev/null 2>&1 || true
  fi

  if has_cmd opkg; then
    opkg remove "$PKG_PREFIX" >/dev/null 2>&1 || true
  fi

  # Safety cleanup for older broken dev installs.
  rm -rf "$THEME_DIR" "$TPL_UCODE" "$TPL_LUA" 2>/dev/null || true
  clear_luci_cache
}

install_apk() {
  pkg_file="$1"
  pkg_base="$(basename "$pkg_file")"
  [ -f "$pkg_file" ] || fail "APK package was not found: $pkg_file"
  has_cmd apk || fail "apk command not found, but .apk package was selected"

  (
    cd "$SCRIPT_DIR" || exit 1
    apk add --force-non-repository --allow-untrusted "./$pkg_base"
  ) || (
    cd "$SCRIPT_DIR" || exit 1
    warn "Retrying APK install without --force-non-repository..."
    apk add --allow-untrusted "./$pkg_base"
  ) || fail "APK install failed: $pkg_base"
}

install_ipk() {
  pkg_file="$1"
  pkg_base="$(basename "$pkg_file")"
  [ -f "$pkg_file" ] || fail "IPK package was not found: $pkg_file"
  has_cmd opkg || fail "opkg command not found, but .ipk package was selected"

  (
    cd "$SCRIPT_DIR" || exit 1
    opkg install "./$pkg_base"
  ) || fail "IPK install failed: $pkg_base"
}

verify_installed_files() {
  log "Verifying installed UniWRT files..."

  [ -d "$THEME_DIR" ] || fail "missing theme asset directory: $THEME_DIR"
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
    [ -f "$TPL_LUA/header.htm" ] || warn "missing Lua header.htm; okay on pure ucode LuCI builds"
    [ -f "$TPL_LUA/footer.htm" ] || warn "missing Lua footer.htm; okay on pure ucode LuCI builds"
    [ -f "$TPL_LUA/sysauth.htm" ] || warn "missing Lua sysauth.htm; okay on pure ucode LuCI builds"
  fi

  # Important for your layout-cache issue: direct CSS/JS links should exist.
  if [ -f "$TPL_UCODE/header.ut" ]; then
    grep -q 'css/uniwrt.css?v=' "$TPL_UCODE/header.ut" || warn "ucode header has no direct css/uniwrt.css?v= link"
    grep -q 'js/uniwrt.js?v=' "$TPL_UCODE/header.ut" || warn "ucode header has no direct js/uniwrt.js?v= link"
  fi

  log "Installed UniWRT files look valid."
}

verify_version_hint() {
  hint="$1"
  [ -n "$hint" ] || return 0

  if grep -R "$hint" "$THEME_DIR" "$TPL_UCODE" "$TPL_LUA" >/dev/null 2>&1; then
    log "Version hint found in installed files: $hint"
  else
    warn "package version hint '$hint' was not found in installed files; install may still be valid if the theme does not embed the package version"
  fi
}

apply_theme() {
  log "Applying $THEME_NAME as the active LuCI theme..."
  uci -q set luci.themes."$THEME_NAME"="$THEME_MEDIA"
  uci -q set luci.main.mediaurlbase="$THEME_MEDIA"
  uci -q commit luci

  active="$(uci -q get luci.main.mediaurlbase 2>/dev/null || true)"
  [ "$active" = "$THEME_MEDIA" ] || fail "failed to apply theme; luci.main.mediaurlbase is '$active'"

  clear_luci_cache
  restart_luci_services

  log "Done. UniWRT is active. Open LuCI in Incognito/Private window first, or hard refresh with Ctrl+Shift+R."
}

recover_bootstrap() {
  log "Recovering LuCI to Bootstrap..."
  uci -q set luci.main.mediaurlbase="$BOOTSTRAP_MEDIA"
  uci -q commit luci
  clear_luci_cache
  restart_luci_services
  log "Done. LuCI should use Bootstrap again."
}

install_flow() {
  detected="$(detect_package)"
  pkg_type="${detected%%:*}"
  pkg_file="${detected#*:}"
  hint="$(package_version_hint "$pkg_file")"

  log "Selected package: $(basename "$pkg_file")"
  [ -n "$hint" ] && log "Package version hint: $hint"

  switch_to_bootstrap_no_restart
  remove_existing_uniwrt

  case "$pkg_type" in
    apk) log "Installing local APK package..."; install_apk "$pkg_file" ;;
    ipk) log "Installing local IPK package..."; install_ipk "$pkg_file" ;;
    *) fail "unsupported package type: $pkg_type" ;;
  esac

  verify_installed_files
  verify_version_hint "$hint"
  apply_theme
}

show_detect() {
  detected="$(detect_package)"
  pkg_type="${detected%%:*}"
  pkg_file="${detected#*:}"
  log "Selected .$pkg_type package: $pkg_file"
}

show_status() {
  rel="$(openwrt_release)"
  expected="$(expected_format)"
  active="$(uci -q get luci.main.mediaurlbase 2>/dev/null || true)"

  log "OpenWrt release: $rel"
  log "Expected package format: .$expected"
  log "Script folder: $SCRIPT_DIR"
  log "Active LuCI mediaurlbase: ${active:-not set}"

  apk_pkg="$(find_latest_package apk 2>/dev/null || true)"
  ipk_pkg="$(find_latest_package ipk 2>/dev/null || true)"
  [ -n "$apk_pkg" ] && log "Found APK: $(basename "$apk_pkg")" || log "Found APK: none"
  [ -n "$ipk_pkg" ] && log "Found IPK: $(basename "$ipk_pkg")" || log "Found IPK: none"
}

show_usage() {
  cat <<USAGE_EOF
Usage: $0 [install|apply|recover|detect|verify|status|paths|help]

Default:
  install   Detect correct local luci-theme-uniwrt*.apk/.ipk, clean reinstall,
            apply UniWRT, clear LuCI cache, restart services.

Commands:
  install   Full clean install and apply. Default.
  apply     Apply UniWRT only, after package is already installed.
  recover   Switch back to Bootstrap and clear LuCI cache.
  detect    Show which local package would be installed.
  verify    Verify installed UniWRT files.
  status    Show OpenWrt/package detection info.
  paths     Show important install paths.
  help      Show this help.

Package format rule:
  OpenWrt 25.x+        -> requires luci-theme-uniwrt*.apk
  OpenWrt 24.x/23.x    -> requires luci-theme-uniwrt*.ipk

The version/revision part is ignored. These are both valid examples:
  luci-theme-uniwrt-2.0.13-r1.apk
  luci-theme-uniwrt_2.0.13-1_all.ipk
USAGE_EOF
}

show_paths() {
  log "Script folder: $SCRIPT_DIR"
  log "Theme assets: $THEME_DIR"
  log "ucode templates: $TPL_UCODE"
  log "Lua templates: $TPL_LUA"
}

case "${1:-install}" in
  install|auto)
    install_flow
    ;;
  apply)
    verify_installed_files
    apply_theme
    ;;
  recover|bootstrap)
    recover_bootstrap
    ;;
  detect)
    show_detect
    ;;
  verify)
    verify_installed_files
    ;;
  status)
    show_status
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
