#!/bin/sh
#
# uniwrt-apply.sh — one-shot installer/activator for UniWRT Portal.
# Run this on the router, in the directory that holds the downloaded
# luci-theme-uniwrt .apk (OpenWrt 25.12+) or .ipk (23.05 / 24.10).
#
# It auto-detects the package manager, installs the matching package,
# activates the theme, clears the LuCI cache and restarts the web UI.
#
set -eu

say() { printf '\033[1;34m[uniwrt]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[uniwrt]\033[0m %s\n' "$*" >&2; }

DIR="$(dirname "$0")"
cd "$DIR"

install_pkg() {
	if command -v apk >/dev/null 2>&1; then
		PKG="$(ls -1 luci-theme-uniwrt-*.apk 2>/dev/null | sort | tail -n1 || true)"
		[ -n "$PKG" ] || { err "no luci-theme-uniwrt-*.apk found in $DIR"; exit 1; }
		say "Installing $PKG via apk"
		apk add --allow-untrusted "./$PKG"
	elif command -v opkg >/dev/null 2>&1; then
		PKG="$(ls -1 luci-theme-uniwrt_*_all.ipk 2>/dev/null | sort | tail -n1 || true)"
		[ -n "$PKG" ] || { err "no luci-theme-uniwrt_*_all.ipk found in $DIR"; exit 1; }
		say "Installing $PKG via opkg"
		opkg install "./$PKG"
	else
		err "neither apk nor opkg found — is this an OpenWrt device?"
		exit 1
	fi
}

install_pkg

say "Activating UniWRT theme"
uci -q set luci.themes.UniWRT=/luci-static/uniwrt
uci -q set luci.main.mediaurlbase=/luci-static/uniwrt
uci -q commit luci

say "Clearing LuCI cache"
rm -f /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null || true

say "Reloading services"
# rpcd reload picks up the new ACL; restart the web server so the theme is served.
/etc/init.d/rpcd reload 2>/dev/null || true
if [ -x /etc/init.d/uhttpd ]; then
	/etc/init.d/uhttpd restart 2>/dev/null || true
fi

say "Done. Reload the LuCI page in your browser (Ctrl/Cmd+Shift+R)."
