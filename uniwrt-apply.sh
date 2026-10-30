#!/bin/sh
#
# uniwrt-apply.sh — install, update or remove UniWRT Portal on OpenWrt.
#
#   sh uniwrt-apply.sh               Standalone install, or update to the latest release
#   sh uniwrt-apply.sh --uninstall   Remove a standalone install
#   sh uniwrt-apply.sh --status      Show how UniWRT is installed and check its files
#   sh uniwrt-apply.sh --package     Install the .apk / .ipk package instead
#
# Options for a standalone install:
#   --version vX.Y.Z   Install that release instead of the latest
#   --file PATH        Install from a downloaded luci-theme-uniwrt-standalone.tar.gz
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
# byte-identical to the package. Written for BusyBox ash with OpenWrt's
# default applet set.
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

# OpenWrt's BusyBox has no tr character classes, so trim with sed.
read_version() { sed -n '1{s/[[:space:]]//g;p;q;}' "$1" 2>/dev/null; }

installed_version() {
	v="$(read_version "$R$VERSION_FILE")"
	echo "${v:-unknown}"
}

# Is the theme registered in the package database? This reads the same files
# rpcd's packagelist reads — the list Attended Sysupgrade sends to the build
# server — so "not registered" here means "not in the upgrade request".
pkg_in_db() {
	if [ -f "$R/lib/apk/db/installed" ] && grep -q -x "P:$PKG" "$R/lib/apk/db/installed"; then
		return 0
	fi
	if [ -f "$R/usr/lib/opkg/status" ] && awk -v p="$PKG" '
		/^Package: / { cur = $2 }
		/^Status: / && cur == p && / installed/ { found = 1 }
		END { exit !found }' "$R/usr/lib/opkg/status"; then
		return 0
	fi
	return 1
}

# Either the database files or the package manager saying so is enough: a
# false "not installed" would leave the package in the upgrade request.
pkg_installed() {
	pkg_in_db && return 0
	if command -v apk >/dev/null 2>&1; then
		apk info -e "$PKG" >/dev/null 2>&1
	elif command -v opkg >/dev/null 2>&1; then
		opkg status "$PKG" 2>/dev/null | grep -q '^Status:.* installed'
	else
		return 1
	fi
}

standalone_installed() { [ -f "$R$KEEP" ]; }

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

verify_sum() { # dir — checks $ARCHIVE against SHA256SUMS in the same dir
	( cd "$1" && grep "  $ARCHIVE\$" SHA256SUMS > SHA256SUMS.one 2>/dev/null && [ -s SHA256SUMS.one ] \
		&& sha256sum -c SHA256SUMS.one >/dev/null 2>&1 )
}

clear_caches() {
	rm -rf "$R"/tmp/luci-indexcache* "$R"/tmp/luci-modulecache 2>/dev/null || true
	[ -x "$R/etc/init.d/rpcd" ] && "$R/etc/init.d/rpcd" reload >/dev/null 2>&1 || true
}

# A permanent owut "remove" entry for the theme makes owut versions before
# July 2026 fail once the package is gone ("not installed and cannot be
# removed"). The standalone install makes it unnecessary, so drop it.
drop_owut_remove() {
	if uci -q get attendedsysupgrade.owut.remove 2>/dev/null | grep -q -w "$PKG"; then
		uci -q del_list attendedsysupgrade.owut.remove="$PKG" || true
		uci -q del_list attendedsysupgrade.owut.remove="$PKG/if-installed" || true
		uci -q commit attendedsysupgrade || true
		say "Removed $PKG from owut's remove list (no longer needed)"
	fi
}

# Point LuCI at a theme that exists, if it is currently set to UniWRT.
leave_uniwrt_theme() {
	[ "$(uci -q get luci.main.mediaurlbase 2>/dev/null || true)" = "/luci-static/uniwrt" ] || return 0
	fallback=/luci-static/bootstrap
	[ -d "$R/www/luci-static/bootstrap" ] || \
		fallback="$(uci -q show luci.themes 2>/dev/null | sed -n "s/^luci\.themes\.[^=]*='\{0,1\}\([^']*\)'\{0,1\}$/\1/p" \
			| grep -v -x /luci-static/uniwrt | head -n1)"
	[ -n "$fallback" ] || fallback=/luci-static/bootstrap
	uci -q set luci.main.mediaurlbase="$fallback"
	say "Switched LuCI to $fallback"
}

# ---------------------------------------------------------------- locate ----

locate_archive() {
	if [ -n "$FILE" ]; then
		[ -f "$FILE" ] || die "Archive not found: $FILE"
		say "Using $FILE"
		cp "$FILE" "$TMP/$ARCHIVE"
		# Verify against a SHA256SUMS sitting next to the archive, when there is one.
		if [ -f "$(dirname "$FILE")/SHA256SUMS" ]; then
			cp "$(dirname "$FILE")/SHA256SUMS" "$TMP/"
			verify_sum "$TMP" || die "Checksum mismatch for $FILE — download it again."
			say "Checksum OK"
		fi
		return
	fi

	# Always download unless --file is given: a leftover archive in /tmp must
	# never be mistaken for the latest release.
	if [ -n "$WANT" ]; then
		base="https://github.com/$REPO/releases/download/$WANT"
	else
		base="https://github.com/$REPO/releases/latest/download"
	fi
	say "Downloading ${WANT:-the latest release} from GitHub"
	if ! fetch "$base/$ARCHIVE" "$TMP/$ARCHIVE" 2>"$TMP/fetch.err"; then
		[ -n "$WANT" ] && die "Could not download $ARCHIVE for $WANT. Standalone archives exist from v2.0.39 onward."
		die "Download failed ($base/$ARCHIVE). Check the router's internet access and clock, or use --file."
	fi
	fetch "$base/SHA256SUMS" "$TMP/SHA256SUMS" 2>>"$TMP/fetch.err" || die "Download failed: $base/SHA256SUMS"
	verify_sum "$TMP" || die "Checksum mismatch — the download is incomplete or corrupt. Nothing was changed."
	say "Checksum OK"
}

# --------------------------------------------------------------- install ----

# Copy the unpacked tree into place. Every step is checked explicitly, and
# each file is written beside its target and renamed, so the web server never
# serves a half-written file.
copy_files() {
	( cd "$TMP/root" && find . \( -type f -o -type l \) ) | sed 's,^\.,,' | sort > "$TMP/all" || return 1
	: > "$TMP/files"
	while IFS= read -r f; do
		case "$f" in
			/etc/uci-defaults/*) continue ;;    # registration is done below, without a boot hook
			"$CONFIG")
				# never overwrite the user's settings
				if [ -f "$R$f" ]; then echo "$f" >> "$TMP/files"; continue; fi ;;
		esac
		mkdir -p "$R$(dirname "$f")" || return 1
		cp -p "$TMP/root$f" "$R$f.uniwrt-new" || { rm -f "$R$f.uniwrt-new"; return 1; }
		mv -f "$R$f.uniwrt-new" "$R$f" || return 1
		echo "$f" >> "$TMP/files"
	done < "$TMP/all"
}

do_install() {
	TMP="$(mktemp -d "$R/tmp/uniwrt.XXXXXX" 2>/dev/null || mktemp -d)"
	locate_archive

	mkdir -p "$TMP/root"
	tar -xzf "$TMP/$ARCHIVE" -C "$TMP/root" 2>/dev/null || die "Could not unpack the archive."
	[ -f "$TMP/root$VERSION_FILE" ] || die "That is not a UniWRT standalone archive."
	NEWVER="$(read_version "$TMP/root$VERSION_FILE")"
	OLDVER="$(installed_version)"

	# Pre-flight: everything that can fail without side effects happens before
	# anything on the router is touched.
	need="$(du -sk "$TMP/root" | awk '{print $1}')"
	avail="$(df -P -k "$R/www" 2>/dev/null | awk 'END{print $4}')"
	case "$avail" in ''|*[!0-9]*) avail="" ;; esac
	if [ -n "$avail" ] && [ "$avail" -lt $((need + 64)) ]; then
		die "Not enough free space: need about $((need + 64)) KB, ${avail} KB available. Nothing was changed."
	fi

	fresh=1
	standalone_installed && fresh=0

	# Switching from the package: remove it first, so it is no longer
	# registered in the package database (that is what breaks sysupgrade).
	migrated=0
	if pkg_installed; then
		fresh=0
		say "Removing the $PKG package (replaced by the standalone install)"
		[ -f "$R$CONFIG" ] && cp -p "$R$CONFIG" "$TMP/uniwrt.config"
		if command -v apk >/dev/null 2>&1; then
			apk del "$PKG" > "$TMP/pm.log" 2>&1 || {
				cat "$TMP/pm.log" >&2
				die "apk could not remove $PKG — nothing else was changed. If apk mentions packages that are no longer available, 'cat /etc/apk/world' and 'apk del' those names first."
			}
		else
			opkg remove "$PKG" > "$TMP/pm.log" 2>&1 || {
				cat "$TMP/pm.log" >&2
				die "opkg could not remove $PKG — nothing else was changed."
			}
		fi
		migrated=1
		[ -f "$TMP/uniwrt.config" ] && cp -p "$TMP/uniwrt.config" "$R$CONFIG"
		# The whole point: the package must be gone from what sysupgrade reports.
		if pkg_installed; then
			leave_uniwrt_theme; uci -q commit luci || true
			die "$PKG is still registered after removal — please report this. LuCI has been switched to a working theme."
		fi
	fi

	if [ "$OLDVER" = "$NEWVER" ] && [ "$fresh" = 0 ] && [ "$migrated" = 0 ]; then
		say "UniWRT $NEWVER is already installed — refreshing its files"
	else
		say "Installing UniWRT $NEWVER"
	fi

	if ! copy_files; then
		# Out of space or a read-only filesystem mid-way: make sure LuCI stays
		# usable, then report. Re-running the script completes the install.
		leave_uniwrt_theme; uci -q commit luci || true
		die "Copying files failed (is the overlay full?). LuCI has been switched to a working theme; free some space and run this script again."
	fi

	# Drop files that an earlier version installed but this one no longer ships.
	manifest_files "$R$KEEP" > "$TMP/old"
	while IFS= read -r f; do
		grep -q -x -F "$f" "$TMP/files" || { rm -f "$R$f"; prune_dirs "$f"; say "Removed obsolete $f"; }
	done < "$TMP/old"

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
	drop_owut_remove
	clear_caches

	if [ "$fresh" = 1 ]; then
		say "Done — UniWRT $NEWVER is installed and active."
	elif [ "$migrated" = 1 ]; then
		say "Done — switched to the standalone install (UniWRT $NEWVER). Your settings were kept."
	else
		say "Done — UniWRT is now $NEWVER."
	fi
	say "Attended Sysupgrade will now work, and the theme stays installed across"
	say "firmware upgrades made with \"Keep settings\" enabled."
	say "Reload LuCI in your browser (Ctrl/Cmd+Shift+R)."
}

# ------------------------------------------------------------- uninstall ----

do_uninstall() {
	standalone_installed || {
		pkg_installed && die "UniWRT is installed as a package — remove it with: apk del $PKG  (or: opkg remove $PKG)"
		die "No standalone UniWRT install found."
	}
	say "Removing UniWRT $(installed_version)"

	list="$(mktemp "$R/tmp/uniwrt.files.XXXXXX" 2>/dev/null || mktemp)"
	manifest_files "$R$KEEP" > "$list"
	echo "$CONFIG" >> "$list"
	while IFS= read -r f; do rm -f "$R$f"; done < "$list"
	while IFS= read -r f; do prune_dirs "$f"; done < "$list"
	rm -f "$list" "$R$KEEP"

	uci -q delete luci.themes.UniWRT || true
	leave_uniwrt_theme
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
	sa=0; pk=0
	standalone_installed && sa=1
	pkg_installed && pk=1
	if [ "$sa" = 1 ] && [ "$pk" = 1 ]; then
		warn "UniWRT $(installed_version) is installed BOTH as a package and standalone."
		warn "Attended Sysupgrade will fail while the package is installed. Run this script without options to fix it."
	elif [ "$sa" = 1 ]; then
		say "UniWRT $(installed_version) — standalone install (kept across firmware upgrades)"
	elif [ "$pk" = 1 ]; then
		say "UniWRT $(installed_version) — installed as a package"
		warn "Attended Sysupgrade will fail until it is removed. Run this script without options to switch to the standalone install."
	else
		say "UniWRT is not installed."
		return 0
	fi
	if [ "$sa" = 1 ]; then
		missing=0
		for f in $(manifest_files "$R$KEEP"); do
			[ -e "$R$f" ] || { warn "missing: $f"; missing=$((missing + 1)); }
		done
		if [ "$missing" = 0 ]; then say "All theme files present."
		else warn "$missing file(s) missing — run this script again to repair."; fi
	fi
	if [ "$(uci -q get luci.main.mediaurlbase 2>/dev/null || true)" = "/luci-static/uniwrt" ]; then
		say "Active theme: UniWRT"
	else
		say "Active theme: $(uci -q get luci.main.mediaurlbase 2>/dev/null || echo unknown) (select UniWRT under System → System → Language and Style)"
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
