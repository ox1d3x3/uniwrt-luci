#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Quick installer for testing UniWRT from GitHub releases.

set -eu

REPO="${REPO:-ox1d3x3/uniwrt-luci-theme}"
TAG="${TAG:-pre-release}"
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

URL="https://github.com/${REPO}/releases/download/${TAG}/luci-theme-uniwrt.${EXT}"
PKG="${TMP_DIR}/luci-theme-uniwrt.${EXT}"

log "Downloading UniWRT ${EXT} package from ${REPO} ${TAG}"
if command -v uclient-fetch >/dev/null 2>&1; then
	uclient-fetch -O "$PKG" "$URL"
elif command -v wget >/dev/null 2>&1; then
	wget -O "$PKG" "$URL"
else
	fail "Need uclient-fetch or wget to download the package."
fi

log "Installing package with ${PM}"
if [ "$PM" = "apk" ]; then
	apk add --allow-untrusted "$PKG"
else
	opkg install "$PKG"
fi

log "Activating UniWRT"
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

log "Done. Refresh LuCI with Ctrl+F5 / hard refresh."
