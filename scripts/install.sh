#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

set -eu

REPO="${REPO:-ox1d3x3/uniwrt-luci}"
TAG="${TAG:-pre-release}"
PKG_NAME="luci-theme-uniwrt"
TMP_DIR="/tmp/uniwrt-install"
mkdir -p "$TMP_DIR"

log() { printf '%s
' "==> $*"; }
fail() { printf '%s
' "ERROR: $*" >&2; exit 1; }

if command -v apk >/dev/null 2>&1; then
	PM="apk"
	EXT="apk"
elif command -v opkg >/dev/null 2>&1; then
	PM="opkg"
	EXT="ipk"
else
	fail "Neither apk nor opkg was found. This does not look like a supported OpenWrt system."
fi

DISTRIB_RELEASE=""
DISTRIB_TARGET=""
[ -r /etc/openwrt_release ] && . /etc/openwrt_release || true
TARGET_SAFE="$(printf '%s' "${DISTRIB_TARGET:-}" | tr '/' '-')"

log "Detected package manager: ${PM}"
log "Kernel: $(uname -m 2>/dev/null || echo unknown)"
[ -n "${DISTRIB_RELEASE:-}" ] && log "OpenWrt release: ${DISTRIB_RELEASE}"
[ -n "${DISTRIB_TARGET:-}" ] && log "OpenWrt target: ${DISTRIB_TARGET}"

fetch_one() {
	name="$1"
	url="https://github.com/${REPO}/releases/download/${TAG}/${name}"
	out="${TMP_DIR}/${name}"
	rm -f "$out"
	log "Trying ${name}"
	if command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$out" "$url" >/dev/null 2>&1 || return 1
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$out" "$url" || return 1
	else
		fail "Need uclient-fetch or wget to download the package."
	fi
	[ -s "$out" ] || return 1
	PKG_PATH="$out"
	return 0
}

install_pkg() {
	pkg="$1"
	if [ "$PM" = "apk" ]; then
		apk del "$PKG_NAME" >/dev/null 2>&1 || true
		[ -f /etc/apk/world ] && sed -i "/^${PKG_NAME}/d" /etc/apk/world || true
		apk add --allow-untrusted "$pkg"
	else
		opkg install "$pkg"
	fi
}

try_download_and_install() {
	name="$1"
	if fetch_one "$name"; then
		log "Installing ${PKG_PATH}"
		install_pkg "$PKG_PATH" && return 0
		log "Install failed for ${name}; trying next package if available."
	fi
	return 1
}

try_download_and_install "${PKG_NAME}.${EXT}" || { [ -n "${DISTRIB_RELEASE:-}" ] && [ -n "$TARGET_SAFE" ] && try_download_and_install "${PKG_NAME}-${DISTRIB_RELEASE}-${TARGET_SAFE}.${EXT}"; } || fail "Could not install UniWRT ${EXT} package from ${REPO} ${TAG}."

log "Activating UniWRT"
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

log "Done. Refresh LuCI with Ctrl+F5 / hard refresh."
