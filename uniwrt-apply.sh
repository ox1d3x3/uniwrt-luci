#!/bin/sh
#
# uniwrt-apply.sh — install, update or remove UniWRT Portal on OpenWrt.
#
#   sh uniwrt-apply.sh               Standalone install or update (recommended)
#   sh uniwrt-apply.sh --uninstall   Remove a standalone install
#   sh uniwrt-apply.sh --status      Show how UniWRT is installed
#   sh uniwrt-apply.sh --package     Install the .apk / .ipk package instead
#
# Options for a standalone install:
#   --version vX.Y.Z   Install that release instead of the latest
#   --file PATH        Use a local luci-theme-uniwrt-standalone.tar.gz
#
# Why "standalone"?
#   Attended Sysupgrade (the LuCI upgrade page and owut) asks OpenWrt's build
#   servers for an image containing every installed *package*. They only know
#   packages from the official feeds, so a manually installed theme package
#   makes the request fail ("Impossible package selection: missing ...").
#
#   A standalone install copies the theme's files into place without
#   registering a package, and lists them in /lib/upgrade/keep.d so sysupgrade
#   carries them into the new firmware when "Keep settings" is on. The upgrade
#   request never mentions UniWRT, and the theme is still there after reboot.
#
# The archive is cut from the same build as the .ipk, so the files are
# byte-identical to the package.
#
set -eu

REPO="ox1d3x3/uniwrt-luci"
ARCHIVE="luci-theme-uniwrt-standalone.tar.gz"
PKG="luci-theme-uniwrt"

# UNIWRT_ROOT lets the test suite run against a fake root; empty on a router.
R="${UNIWRT_ROOT:-}"
KEEP="/lib/upgrade/keep.d/uniwrt-standalone"
VERSION_FILE="/usr/share/ucode/luci/template/themes/uniwrt/version"
CONFIG="/etc/config/uniwrt"

say()  { printf '\033[1;34m[uniwrt]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[uniwrt]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[uniwrt]\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '3,13p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; }

TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; return 0; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# ------------------------------------------------------------------ helpers --

pkg_installed() {
	if command -v apk >/dev/null 2>&1; then
		apk info -e "$PKG" >/dev/null 2>&1
	elif command -v opkg >/dev/null 2>&1; then
		opkg status "$PKG" 2>/dev/null | grep -q '^Status:.* installed'
	else
		return 1
	fi
}

standalone_installed() { [ -f "$R$KEEP" ]; }

installed_version() {
	[ -f "$R$VERSION_FILE" ] && tr -d '[:space:]' < "$R$VERSION_FILE" || echo "unknown"
}

# Files recorded in the keep list, minus comments, the config and the list itself.
manifest_files() {
	[ -f "$1" ] || return 0
	sed -e '/^[[:space:]]*$/d' -e '/^#/d' "$1" | grep -v -x -F -e "$CONFIG" -e "$KEEP" || true
}

# Only ever remove directories that belong to the theme (path contains "uniwrt").
dir_is_ours() { case "$1" in *uniwrt*) return 0 ;; *) return 1 ;; esac; }

prune_dirs() { # file — remove the theme's now-empty parent directories
	d="$(dirname "$1")"
	while dir_is_ours "$d" && rmdir "$R$d" 2>/dev/null; do d="$(dirname "$d")"; done
	return 0
}

fetch() { # url out
	if command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$2" "$1"
	elif command -v curl >/dev/null 2>&1; then
		curl -fsSL -o "$2" "$1"
	else
		die "No downloader found (uclient-fetch, wget or curl)."
	fi
}

verify_sum() { # dir  — checks $ARCHIVE against SHA256SUMS in the same dir
	( cd "$1" && grep "  $ARCHIVE\$" SHA256SUMS > SHA256SUMS.one && [ -s SHA256SUMS.one ] \
		&& sha256sum -c SHA256SUMS.one >/dev/null 2>&1 )
}

clear_caches() {
	rm -rf "$R"/tmp/luci-indexcache* "$R"/tmp/luci-modulecache 2>/dev/null || true
	[ -x "$R/etc/init.d/rpcd" ] && "$R/etc/init.d/rpcd" reload >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- locate ----

locate_archive() {
	if [ -n "$FILE" ]; then
		[ -f "$FILE" ] || die "Archive not found: $FILE"
		SRC="$FILE"
	else
		SRC=""
		for d in "$(dirname "$0")" "$(pwd)" /tmp; do
			if [ -f "$d/$ARCHIVE" ]; then SRC="$d/$ARCHIVE"; break; fi
		done
	fi

	if [ -n "$SRC" ]; then
		say "Using $SRC"
		# Verify against a SHA256SUMS sitting next to the archive, when there is one.
		if [ -f "$(dirname "$SRC")/SHA256SUMS" ]; then
			cp "$SRC" "$TMP/$ARCHIVE"; cp "$(dirname "$SRC")/SHA256SUMS" "$TMP/"
			verify_sum "$TMP" || die "Checksum mismatch for $SRC — download it again."
			say "Checksum OK"
			SRC="$TMP/$ARCHIVE"
		fi
		return
	fi

	if [ -n "$WANT" ]; then
		base="https://github.com/$REPO/releases/download/$WANT"
	else
		base="https://github.com/$REPO/releases/latest/download"
	fi
	say "Downloading ${WANT:-latest release} from GitHub"
	fetch "$base/$ARCHIVE" "$TMP/$ARCHIVE" || die "Download failed: $base/$ARCHIVE"
	fetch "$base/SHA256SUMS" "$TMP/SHA256SUMS" || die "Download failed: $base/SHA256SUMS"
	verify_sum "$TMP" || die "Checksum mismatch — the download is incomplete or corrupt."
	say "Checksum OK"
	SRC="$TMP/$ARCHIVE"
}

# --------------------------------------------------------------- install ----

do_install() {
	TMP="$(mktemp -d "${R:-}/tmp/uniwrt.XXXXXX" 2>/dev/null || mktemp -d)"
	locate_archive

	mkdir -p "$TMP/root"
	tar -xzf "$SRC" -C "$TMP/root" || die "Could not unpack $SRC"
	[ -f "$TMP/root$VERSION_FILE" ] || die "$SRC is not a UniWRT standalone archive."
	NEWVER="$(tr -d '[:space:]' < "$TMP/root$VERSION_FILE")"

	fresh=1
	standalone_installed && fresh=0

	# Switching from the package: remove it first so nothing is left registered
	# in the package database (that registration is what breaks sysupgrade).
	if pkg_installed; then
		fresh=0
		say "Removing the $PKG package (replaced by the standalone install)"
		[ -f "$R$CONFIG" ] && cp -p "$R$CONFIG" "$TMP/uniwrt.config"
		if command -v apk >/dev/null 2>&1; then
			apk del "$PKG" >/dev/null || die "apk del $PKG failed"
		else
			opkg remove "$PKG" >/dev/null || die "opkg remove $PKG failed"
		fi
		[ -f "$TMP/uniwrt.config" ] && cp -p "$TMP/uniwrt.config" "$R$CONFIG"
	fi

	say "Installing UniWRT $NEWVER"
	: > "$TMP/files"
	( cd "$TMP/root" && find . \( -type f -o -type l \) | sed 's,^\.,,' | sort ) |
	while IFS= read -r f; do
		case "$f" in
			/etc/uci-defaults/*) continue ;;   # done below, without a boot hook
			"$CONFIG")
				# never overwrite the user's settings
				[ -f "$R$f" ] && { echo "$f" >> "$TMP/files"; continue; } ;;
		esac
		mkdir -p "$R$(dirname "$f")"
		cp -p "$TMP/root$f" "$R$f.uniwrt-new" && mv -f "$R$f.uniwrt-new" "$R$f"
		echo "$f" >> "$TMP/files"
	done

	# Drop files that an earlier version installed but this one no longer ships.
	manifest_files "$R$KEEP" | while IFS= read -r f; do
		grep -q -x -F "$f" "$TMP/files" || { rm -f "$R$f"; prune_dirs "$f"; say "Removed stale $f"; }
	done

	# The keep list doubles as the install manifest. sysupgrade reads every file
	# in keep.d, so it must list itself to survive into the new firmware.
	mkdir -p "$R$(dirname "$KEEP")"
	{
		echo "# UniWRT Portal $NEWVER — standalone install (uniwrt-apply.sh)."
		echo "# Kept across sysupgrade. Remove with: sh uniwrt-apply.sh --uninstall"
		grep -v -x -F "$CONFIG" "$TMP/files"
		echo "$CONFIG"
		echo "$KEEP"
	} > "$R$KEEP.uniwrt-new"
	mv -f "$R$KEEP.uniwrt-new" "$R$KEEP"

	# Same registration as the package's uci-defaults script: always list the
	# theme, but only make it active on a fresh install.
	uci -q set luci.themes.UniWRT=/luci-static/uniwrt
	[ "$fresh" = 1 ] && uci -q set luci.main.mediaurlbase=/luci-static/uniwrt
	uci -q commit luci

	clear_caches

	if [ "$fresh" = 1 ]; then
		say "Done — UniWRT $NEWVER is installed and active."
	else
		say "Done — UniWRT is now $NEWVER."
	fi
	say "It will survive firmware upgrades made with \"Keep settings\" enabled."
	say "Reload LuCI in your browser (Ctrl/Cmd+Shift+R)."
}

# ------------------------------------------------------------- uninstall ----

do_uninstall() {
	standalone_installed || {
		pkg_installed && die "UniWRT is installed as a package — remove it with apk del / opkg remove $PKG."
		die "No standalone UniWRT install found."
	}
	say "Removing UniWRT $(installed_version)"

	manifest_files "$R$KEEP" > "${R:-}/tmp/uniwrt.files.$$"
	echo "$CONFIG" >> "${R:-}/tmp/uniwrt.files.$$"
	while IFS= read -r f; do
		rm -f "$R$f"
	done < "${R:-}/tmp/uniwrt.files.$$"

	# Remove the theme's own now-empty directories, deepest first.
	while IFS= read -r f; do
		d="$(dirname "$f")"
		while dir_is_ours "$d"; do echo "$d"; d="$(dirname "$d")"; done
	done < "${R:-}/tmp/uniwrt.files.$$" | sort -u -r | while IFS= read -r d; do
		rmdir "$R$d" 2>/dev/null || true
	done
	rm -f "${R:-}/tmp/uniwrt.files.$$" "$R$KEEP"

	uci -q delete luci.themes.UniWRT || true
	if [ "$(uci -q get luci.main.mediaurlbase || true)" = "/luci-static/uniwrt" ]; then
		uci -q set luci.main.mediaurlbase=/luci-static/bootstrap
		say "Switched LuCI back to the Bootstrap theme"
	fi
	uci -q commit luci

	clear_caches
	say "Done — UniWRT has been removed."
}

# --------------------------------------------------------------- package ----

do_package() {
	if standalone_installed; then
		say "Removing the standalone install first"
		( do_uninstall ) >/dev/null
	fi
	cd "$(dirname "$0")"
	if command -v apk >/dev/null 2>&1; then
		P="$(ls -1 "$PKG"-*.apk 2>/dev/null | sort | tail -n1 || true)"
		[ -n "$P" ] || die "No $PKG-*.apk found in $(pwd)"
		say "Installing $P via apk"
		apk add --allow-untrusted "./$P"
	elif command -v opkg >/dev/null 2>&1; then
		P="$(ls -1 "$PKG"_*_all.ipk 2>/dev/null | sort | tail -n1 || true)"
		[ -n "$P" ] || die "No ${PKG}_*_all.ipk found in $(pwd)"
		say "Installing $P via opkg"
		opkg install "./$P"
	else
		die "Neither apk nor opkg found — is this an OpenWrt device?"
	fi
	uci -q set luci.themes.UniWRT=/luci-static/uniwrt
	uci -q set luci.main.mediaurlbase=/luci-static/uniwrt
	uci -q commit luci
	clear_caches
	say "Done. Note: Attended Sysupgrade cannot build firmware while the package"
	say "is installed — see the README FAQ, or use the standalone install."
}

# ---------------------------------------------------------------- status ----

do_status() {
	if standalone_installed; then
		say "UniWRT $(installed_version) — standalone install (kept across firmware upgrades)"
	elif pkg_installed; then
		say "UniWRT $(installed_version) — installed as a package"
		say "Attended Sysupgrade will fail until it is removed; run this script without options to switch."
	else
		say "UniWRT is not installed."
	fi
}

# ------------------------------------------------------------------ main ----

MODE=install; WANT=""; FILE=""
while [ $# -gt 0 ]; do
	case "$1" in
		--uninstall|--remove) MODE=uninstall ;;
		--status)             MODE=status ;;
		--package)            MODE=package ;;
		--version)            shift; WANT="${1:-}"; [ -n "$WANT" ] || die "--version needs a tag, e.g. v2.0.39" ;;
		--file)               shift; FILE="${1:-}"; [ -n "$FILE" ] || die "--file needs a path" ;;
		-h|--help)            usage; exit 0 ;;
		*)                    usage; die "Unknown option: $1" ;;
	esac
	shift
done
case "$WANT" in ""|v*) ;; *) WANT="v$WANT" ;; esac

case "$MODE" in
	install)   do_install ;;
	uninstall) do_uninstall ;;
	status)    do_status ;;
	package)   do_package ;;
esac
