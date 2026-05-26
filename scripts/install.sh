#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

set -eu

REPO="${REPO:-ox1d3x3/uniwrt-luci}"
TAG="${TAG:-pre-release}"
PKG_NAME="luci-theme-uniwrt"
TMP_DIR="/tmp/uniwrt-install"
mkdir -p "$TMP_DIR"

log() { printf '%s\n' "==> $*"; }
fail() { printf '%s\n' "ERROR: $*" >&2; exit 1; }

if command -v apk >/dev/null 2>&1; then
	PM="apk"
	EXT="apk"
elif command -v opkg >/dev/null 2>&1; then
	PM="opkg"
	EXT="ipk"
else
	fail "Neither apk nor opkg was found. This does not look like a supported OpenWrt system."
fi

log "Detected package manager: ${PM}"
log "Kernel: $(uname -m 2>/dev/null || echo unknown)"
[ -r /etc/openwrt_release ] && . /etc/openwrt_release && log "OpenWrt target: ${DISTRIB_TARGET:-unknown}"

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

PKG_PATH=""
fetch_one "${PKG_NAME}.${EXT}" || fetch_one "${PKG_NAME}_all.${EXT}" || fail "Could not download UniWRT ${EXT} package from ${REPO} ${TAG}."

log "Installing ${PKG_PATH}"
if [ "$PM" = "apk" ]; then
	# Clean up a previously failed architecture-specific install request from /etc/apk/world.
	apk del "$PKG_NAME" >/dev/null 2>&1 || true
	[ -f /etc/apk/world ] && sed -i "/^${PKG_NAME}/d" /etc/apk/world || true
	apk add --allow-untrusted "$PKG_PATH"
else
	opkg install "$PKG_PATH"
fi

log "Activating UniWRT"
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

log "Done. Refresh LuCI with Ctrl+F5 / hard refresh."
