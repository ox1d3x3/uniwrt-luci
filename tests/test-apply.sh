#!/usr/bin/env bash
#
# tests/test-apply.sh <standalone.tar.gz>
#
# Exercises uniwrt-apply.sh against a fake router root (UNIWRT_ROOT), run by
# BusyBox ash with only BusyBox applets on PATH, plus stub apk / uclient-fetch
# / df. Includes a simulated sysupgrade that keeps exactly what OpenWrt's
# sysupgrade keeps (base-files' list_static_conffiles expansion of keep.d).
#
# For the router's exact tools, build them with tests/setup-openwrt-tools.sh:
#   BUSYBOX=…/busybox  BUSYBOX_LINKS=…/busybox.links  BusyBox with OpenWrt's config
#   UCI_BIN=…/uci                                      OpenWrt's real uci
# Without them, the system busybox and a small uci stub are used.
#
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../uniwrt-apply.sh"
ARCHIVE="$(cd "$(dirname "${1:?usage: $0 <standalone.tar.gz>}")" && pwd)/$(basename "$1")"
BUSYBOX="${BUSYBOX:-$(command -v busybox)}" || { echo "busybox is required"; exit 2; }
UCI_BIN="${UCI_BIN:-}"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0; SECTION=""
ok()  { printf '\033[32mok\033[0m   %s\n' "$*"; pass=$((pass+1)); }
bad() {
	printf '\033[31mFAIL\033[0m %s\n' "$*"; fail=$((fail+1))
	# surface failures as annotations in GitHub Actions, with the script's output
	[ -n "${GITHUB_ACTIONS:-}" ] && echo "::error title=test-apply::$SECTION — $* | $(tail -n 4 "$T/out" 2>/dev/null | tr '\n' ' ' | cut -c1-400)"
	return 0
}
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

# --- BusyBox applets + stubs on PATH -----------------------------------------
BB="$T/bin"; mkdir -p "$BB"
if [ -n "${BUSYBOX_LINKS:-}" ]; then applets=$(sed 's,.*/,,' "$BUSYBOX_LINKS"); else applets=$("$BUSYBOX" --list); fi
for a in $applets; do ln -sf "$BUSYBOX" "$BB/$a"; done
rm -f "$BB/wget"   # downloads must go through uclient-fetch, as on OpenWrt

if [ -n "$UCI_BIN" ]; then
	cat > "$BB/uci" <<EOF
#!/bin/sh
exec "$UCI_BIN" -c "\$UNIWRT_ROOT/etc/config" -t "\$UNIWRT_ROOT/tmp/.uci" "\$@"
EOF
	UCI_KIND="OpenWrt uci"
else
	cat > "$BB/uci" <<'EOF'
#!/bin/sh
# minimal file-backed uci stub: get / set / delete / add_list / del_list / show / commit
db="$UNIWRT_ROOT/etc/config/.stubdb"; touch "$db"
[ "$1" = "-q" ] && shift
case "$1" in
  get)      v=$(grep "^$2=" "$db" | cut -d= -f2- | tr '\n' ' ' | sed 's/ $//'); [ -n "$v" ] && echo "$v" || exit 1 ;;
  set)      k="${2%%=*}"; grep -v "^$k=" "$db" > "$db.n"; echo "$2" >> "$db.n"; mv "$db.n" "$db" ;;
  add_list) echo "$2" >> "$db" ;;
  del_list) grep -v -x -F "$2" "$db" > "$db.n"; mv "$db.n" "$db" ;;
  delete)   grep -q "^$2=" "$db" || exit 1; grep -v "^$2=" "$db" > "$db.n"; mv "$db.n" "$db" ;;
  show)     grep "^$2\." "$db" | sed "s/=\(.*\)/='\1'/" ;;
  commit)   : ;;
esac
EOF
	UCI_KIND="uci stub"
fi
cat > "$BB/uclient-fetch" <<'EOF'
#!/bin/sh
# serves https://github.com/.../releases/<latest/download|download/TAG>/<file> from $FAKE_GH/<tag>/
out=""; while [ $# -gt 1 ]; do case "$1" in -O) out="$2"; shift ;; esac; shift; done
url="$1"; echo "$url" >> "$UNIWRT_ROOT/fetch.log"
case "$url" in
  */releases/latest/download/*) tag=latest ;;
  */releases/download/*) tag=$(echo "$url" | sed 's,.*/releases/download/\([^/]*\)/.*,\1,') ;;
  *) exit 1 ;;
esac
f="${FAKE_GH:-/nonexistent}/$tag/$(basename "$url")"; [ -f "$f" ] || { echo "HTTP error 404" >&2; exit 8; }; cp "$f" "$out"
EOF
chmod +x "$BB/uci" "$BB/uclient-fetch"
echo "BusyBox: $(echo "$applets" | wc -w) applets${BUSYBOX_LINKS:+ (OpenWrt config)}; $UCI_KIND"

# --- fake router roots --------------------------------------------------------
uci_() { PATH="$BB" "$BB/uci" "$@"; }
uciget() { uci_ -q get "$1" 2>/dev/null || true; }

new_root() {
	export UNIWRT_ROOT="$T/root$1"; rm -rf "$UNIWRT_ROOT"
	mkdir -p "$UNIWRT_ROOT/tmp/.uci" "$UNIWRT_ROOT/etc/config" "$UNIWRT_ROOT/www/luci-static/bootstrap" \
	         "$UNIWRT_ROOT/usr/share/ucode/luci/template/themes/bootstrap" "$UNIWRT_ROOT/lib/upgrade/keep.d"
	echo "/etc/config" > "$UNIWRT_ROOT/lib/upgrade/keep.d/base"   # stand-in for conffiles (kept on upgrade)
	printf "config core 'main'\n\toption mediaurlbase '/luci-static/bootstrap'\n\nconfig internal 'themes'\n\toption Bootstrap '/luci-static/bootstrap'\n" \
		> "$UNIWRT_ROOT/etc/config/luci"
	printf "config server 'server'\n\toption url 'https://sysupgrade.openwrt.org'\n" > "$UNIWRT_ROOT/etc/config/attendedsysupgrade"
	[ -n "$UCI_BIN" ] || printf '%s\n' "luci.themes.Bootstrap=/luci-static/bootstrap" "luci.main.mediaurlbase=/luci-static/bootstrap" \
		> "$UNIWRT_ROOT/etc/config/.stubdb"
}
run() { PATH="$BB" "$BUSYBOX" sh "$SCRIPT" "$@" > "$T/out" 2>&1; local rc=$?; [ $rc = 0 ] || sed 's/^/      | /' "$T/out"; return $rc; }
runfail() { ! PATH="$BB" "$BUSYBOX" sh "$SCRIPT" "$@" > "$T/out" 2>&1; }
KEEP=lib/upgrade/keep.d/uniwrt-standalone
FILES=$(tar tzf "$ARCHIVE" | sed 's,^\./,/,' | grep -v '/$' | grep -v '^/etc/uci-defaults/')
fake_release() { # tag [archive]
	mkdir -p "$FAKE_GH/$1"; cp "${2:-$ARCHIVE}" "$FAKE_GH/$1/luci-theme-uniwrt-standalone.tar.gz"
	( cd "$FAKE_GH/$1" && sha256sum luci-theme-uniwrt-standalone.tar.gz > SHA256SUMS )
}
export FAKE_GH="$T/gh"

# Simulate a firmware upgrade with "Keep settings": compute the keep list the
# way base-files' sysupgrade does, wipe everything, restore only those files.
sysupgrade_keep() {
	local r="$UNIWRT_ROOT"
	( cd "$r" && find $(sed -ne '/^[[:space:]]*$/d; /^#/d; s,^/,./,; p' lib/upgrade/keep.d/* 2>/dev/null) \
		\( -type f -o -type l \) 2>/dev/null ) | sort -u > "$T/kept"
	tar -C "$r" -cf "$T/backup.tar" -T "$T/kept"
	new_root "${r#"$T"/root}"                             # factory-fresh firmware…
	tar -C "$UNIWRT_ROOT" -xf "$T/backup.tar"             # …plus the restored backup
}

all_present() { local m=0; for f in $FILES; do [ -f "$UNIWRT_ROOT$f" ] || { echo "      missing $f"; m=1; }; done; [ $m = 0 ]; }

SECTION="1. fresh standalone install from a local archive"; echo "== 1. fresh standalone install from a local archive =="
new_root 1
check "install succeeds" run --file "$ARCHIVE"
check "all theme files installed" all_present
check "files are byte-identical to the archive" bash -c "mkdir -p '$T/x' && tar xzf '$ARCHIVE' -C '$T/x' && for f in $(echo $FILES | tr '\n' ' '); do cmp -s \"$T/x\$f\" \"$UNIWRT_ROOT\$f\" || exit 1; done"
check "uci-defaults hook NOT installed" [ ! -e "$UNIWRT_ROOT/etc/uci-defaults/30_luci-theme-uniwrt" ]
check "theme registered" [ "$(uciget luci.themes.UniWRT)" = /luci-static/uniwrt ]
check "theme activated on fresh install" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/uniwrt ]
check "keep.d manifest written" [ -f "$UNIWRT_ROOT/$KEEP" ]
check "manifest lists itself and the config" bash -c "grep -qx /$KEEP '$UNIWRT_ROOT/$KEEP' && grep -qx /etc/config/uniwrt '$UNIWRT_ROOT/$KEEP'"
check "no temp files left behind" bash -c "! find '$UNIWRT_ROOT' -name '*.uniwrt-new' | grep -q . && ! ls -d '$UNIWRT_ROOT'/tmp/uniwrt.* >/dev/null 2>&1"
check "status: standalone, all files present" bash -c "PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --status | grep -q 'All theme files present'"

SECTION="2. survives a firmware upgrade with Keep settings"; echo "== 2. survives a firmware upgrade with Keep settings =="
echo "	option accent '#38cc65'" >> "$UNIWRT_ROOT/etc/config/uniwrt"
sysupgrade_keep
check "every theme file is restored after the upgrade" all_present
check "user settings restored" grep -q "38cc65" "$UNIWRT_ROOT/etc/config/uniwrt"
check "manifest itself restored (so the next upgrade keeps it too)" [ -f "$UNIWRT_ROOT/$KEEP" ]
check "theme still registered and active" bash -c "[ '$(uciget luci.themes.UniWRT)' = /luci-static/uniwrt ] && [ '$(uciget luci.main.mediaurlbase)' = /luci-static/uniwrt ]"
sysupgrade_keep
check "and survives a second upgrade" all_present

SECTION="3. update: keeps settings and theme choice, removes obsolete files"; echo "== 3. update: keeps settings and theme choice, removes obsolete files =="
uci_ set luci.main.mediaurlbase=/luci-static/bootstrap; uci_ commit luci
mkdir -p "$UNIWRT_ROOT/www/luci-static/uniwrt/old"; echo x > "$UNIWRT_ROOT/www/luci-static/uniwrt/old/legacy.css"
echo "/www/luci-static/uniwrt/old/legacy.css" >> "$UNIWRT_ROOT/$KEEP"
check "re-run succeeds" run --file "$ARCHIVE"
check "reports a same-version refresh" grep -q "already installed" "$T/out"
check "user settings untouched" grep -q "38cc65" "$UNIWRT_ROOT/etc/config/uniwrt"
check "user's theme choice not overridden on update" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/bootstrap ]
check "obsolete file and its empty dir removed" bash -c "[ ! -e '$UNIWRT_ROOT/www/luci-static/uniwrt/old' ]"
check "obsolete file dropped from manifest" bash -c "! grep -q legacy.css '$UNIWRT_ROOT/$KEEP'"

SECTION="4. status detects damage; re-run repairs"; echo "== 4. status detects damage; re-run repairs =="
rm -f "$UNIWRT_ROOT/www/luci-static/uniwrt/css/dark.css"
PATH="$BB" "$BUSYBOX" sh "$SCRIPT" --status > "$T/out" 2>&1
check "status reports the missing file" grep -q "missing: /www/luci-static/uniwrt/css/dark.css" "$T/out"
check "re-run repairs it" bash -c "PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --file '$ARCHIVE' >/dev/null 2>&1 && [ -f '$UNIWRT_ROOT/www/luci-static/uniwrt/css/dark.css' ]"

SECTION="5. uninstall"; echo "== 5. uninstall =="
uci_ set luci.main.mediaurlbase=/luci-static/uniwrt; uci_ commit luci
check "uninstall succeeds" run --uninstall
left=$(cd "$UNIWRT_ROOT" && find . -path '*uniwrt*' | grep -v '^./etc/config/\.stubdb' || true)
check "no UniWRT files or dirs left" [ -z "$left" ]
[ -z "$left" ] || echo "$left" | sed 's/^/      left: /'
check "bootstrap theme dirs untouched" [ -d "$UNIWRT_ROOT/usr/share/ucode/luci/template/themes/bootstrap" ]
check "theme unregistered" [ -z "$(uciget luci.themes.UniWRT)" ]
check "LuCI switched back to Bootstrap" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/bootstrap ]
check "uninstall again fails cleanly" runfail --uninstall

SECTION="6. uninstall picks another installed theme when Bootstrap is absent"; echo "== 6. uninstall picks another installed theme when Bootstrap is absent =="
new_root 6; rm -rf "$UNIWRT_ROOT/www/luci-static/bootstrap"
run --file "$ARCHIVE" >/dev/null
uci_ set luci.themes.Material=/luci-static/material; uci_ delete luci.themes.Bootstrap; uci_ commit luci
check "uninstall succeeds" run --uninstall
check "LuCI set to the remaining theme" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/material ]

SECTION="7. online install: always downloads, checksum enforced"; echo "== 7. online install: always downloads, checksum enforced =="
new_root 7; fake_release latest; fake_release v9.9.9
check "downloads the latest release" run
check "used the releases/latest URL" grep -q "releases/latest/download/luci-theme-uniwrt-standalone.tar.gz" "$UNIWRT_ROOT/fetch.log"
check "--version fetches that tag" run --version 9.9.9
check "used the pinned tag URL" grep -q "releases/download/v9.9.9/" "$UNIWRT_ROOT/fetch.log"
check "unknown --version gives a clear error" bash -c "! PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --version v1.0.0 > '$T/out' 2>&1 && grep -q 'from v2.0.39 onward' '$T/out'"
echo garbage >> "$FAKE_GH/latest/luci-theme-uniwrt-standalone.tar.gz"
check "corrupt download is rejected" runfail
check "…with a checksum error" grep -qi "checksum mismatch" "$T/out"
check "…and the installed theme is left intact" all_present
fake_release latest

SECTION="8. a stale archive in /tmp is never used instead of the latest release"; echo "== 8. a stale archive in /tmp is never used instead of the latest release =="
new_root 8; fake_release latest
mkdir -p "$T/old" && tar xzf "$ARCHIVE" -C "$T/old" && echo "1.0.0" > "$T/old/usr/share/ucode/luci/template/themes/uniwrt/version"
tar czf "$UNIWRT_ROOT/tmp/luci-theme-uniwrt-standalone.tar.gz" -C "$T/old" .
( cd "$UNIWRT_ROOT/tmp" && cp "$SCRIPT" ./uniwrt-apply.sh && PATH="$BB" "$BUSYBOX" sh ./uniwrt-apply.sh > "$T/out" 2>&1 )
check "downloaded instead of using the leftover archive" grep -q "releases/latest/download" "$UNIWRT_ROOT/fetch.log"
check "installed the real latest version" [ "$(sed -n 1p "$UNIWRT_ROOT/usr/share/ucode/luci/template/themes/uniwrt/version" | tr -d '[:space:]')" = "$(tar xzf "$ARCHIVE" -O ./usr/share/ucode/luci/template/themes/uniwrt/version | tr -d '[:space:]')" ]

SECTION="9. migrating from the package install (apk)"; echo "== 9. migrating from the package install (apk) =="
apk_stub() { # $1 = behaviour of 'apk del': ok | fail
	rm -f "$BB/apk"; cat > "$BB/apk" <<EOF
#!/bin/sh
echo "apk \$*" >> "\$UNIWRT_ROOT/apk.log"
case "\$1" in
  info) [ -f "\$UNIWRT_ROOT/pkg-installed" ] ;;
  del)  [ "$1" = fail ] && { echo "ERROR: unable to select packages:" >&2; echo "  luci-theme-aurora (no such package)" >&2; exit 1; }
        # like the real removal: files go, postrm unregisters the theme
        rm -f "\$UNIWRT_ROOT/pkg-installed" "\$UNIWRT_ROOT/etc/config/uniwrt"
        rm -rf "\$UNIWRT_ROOT/www/luci-static/uniwrt" "\$UNIWRT_ROOT/usr/share/ucode/luci/template/themes/uniwrt" \
               "\$UNIWRT_ROOT/www/luci-static/resources/view/uniwrt" "\$UNIWRT_ROOT"/www/luci-static/resources/*-uniwrt.js
        "$BB/uci" -q delete luci.themes.UniWRT; "$BB/uci" -q commit luci ;;
esac
EOF
	chmod +x "$BB/apk"
}
pkg_root() {
	new_root "$1"
	mkdir -p "$T/x$1" && tar xzf "$ARCHIVE" -C "$T/x$1" && cp -a "$T/x$1/." "$UNIWRT_ROOT/" && rm -rf "$UNIWRT_ROOT/etc/uci-defaults"
	echo "	option mode 'dark'" >> "$UNIWRT_ROOT/etc/config/uniwrt"
	uci_ set luci.themes.UniWRT=/luci-static/uniwrt; uci_ set luci.main.mediaurlbase=/luci-static/uniwrt; uci_ commit luci
	touch "$UNIWRT_ROOT/pkg-installed"
}
pkg_root 9; apk_stub ok
uci_ set attendedsysupgrade.owut=owut; uci_ add_list attendedsysupgrade.owut.remove=luci-theme-uniwrt
uci_ add_list attendedsysupgrade.owut.remove=luci-app-foo; uci_ commit attendedsysupgrade
check "status flags the package install" bash -c "PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --status 2>&1 | grep -q 'as a package'"
check "switch to standalone succeeds" run --file "$ARCHIVE"
check "package was removed" grep -q "apk del luci-theme-uniwrt" "$UNIWRT_ROOT/apk.log"
check "settings carried over" grep -q "mode 'dark'" "$UNIWRT_ROOT/etc/config/uniwrt"
check "all theme files back in place" all_present
check "theme re-registered and still active" bash -c "[ '$(uciget luci.themes.UniWRT)' = /luci-static/uniwrt ] && [ '$(uciget luci.main.mediaurlbase)' = /luci-static/uniwrt ]"
check "owut remove entry for the theme dropped" bash -c "! UNIWRT_ROOT='$UNIWRT_ROOT' '$BB/uci' -q get attendedsysupgrade.owut.remove | grep -q luci-theme-uniwrt"
check "…other owut remove entries kept" bash -c "UNIWRT_ROOT='$UNIWRT_ROOT' '$BB/uci' -q get attendedsysupgrade.owut.remove | grep -q luci-app-foo"
check "now reported as standalone" bash -c "PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --status | grep -q standalone"

SECTION="10. apk failure leaves everything as it was"; echo "== 10. apk failure leaves everything as it was =="
pkg_root 10; apk_stub fail
check "migration refused" runfail --file "$ARCHIVE"
check "apk's real error is shown" grep -q "luci-theme-aurora" "$T/out"
check "hint about stale world entries" grep -q "/etc/apk/world" "$T/out"
check "package still installed, no standalone manifest" bash -c "[ -f '$UNIWRT_ROOT/pkg-installed' ] && [ ! -e '$UNIWRT_ROOT/$KEEP' ]"
check "theme still active" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/uniwrt ]

SECTION="11. not enough space: refused before touching anything"; echo "== 11. not enough space: refused before touching anything =="
pkg_root 11; apk_stub ok
rm -f "$BB/df"; cat > "$BB/df" <<'EOF'
#!/bin/sh
echo "Filesystem 1024-blocks Used Available Capacity Mounted on"; echo "overlayfs:/overlay 3072 3062 10 99% /"
EOF
chmod +x "$BB/df"
check "install refused" runfail --file "$ARCHIVE"
check "…with a clear message" grep -q "Not enough free space" "$T/out"
check "package NOT removed" [ -f "$UNIWRT_ROOT/pkg-installed" ]
rm -f "$BB/df"; ln -s "$BUSYBOX" "$BB/df"

SECTION="12. copy failure after migration keeps LuCI usable"; echo "== 12. copy failure after migration keeps LuCI usable =="
pkg_root 12; apk_stub ok
rm -rf "$UNIWRT_ROOT/usr/share/ucode/luci/template/themes"; : > "$UNIWRT_ROOT/usr/share/ucode/luci/template/themes"   # mkdir will fail
check "install fails" runfail --file "$ARCHIVE"
check "…explaining what to do" grep -q "run this script again" "$T/out"
check "LuCI switched to a working theme" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/bootstrap ]
rm -f "$UNIWRT_ROOT/usr/share/ucode/luci/template/themes"
check "re-running completes the install" run --file "$ARCHIVE"
check "…all files present" all_present
rm -f "$BB/apk"

SECTION="12b. package detected from the database even if 'apk info' fails"; echo "== 12b. package detected from the database even if 'apk info' fails =="
pkg_root 14; apk_stub ok
mkdir -p "$UNIWRT_ROOT/lib/apk/db"; printf 'C:Q1x\nP:luci-theme-uniwrt\nV:2.0.39-r1\n\n' > "$UNIWRT_ROOT/lib/apk/db/installed"
rm -f "$UNIWRT_ROOT/pkg-installed"          # stub's 'apk info -e' now says "not installed"
sed -i 's|^  del)  |  del)  sed -i "/^P:luci-theme-uniwrt\$/d" "\$UNIWRT_ROOT/lib/apk/db/installed"; |' "$BB/apk"
check "migration still happens" run --file "$ARCHIVE"
check "apk del was called" grep -q "apk del luci-theme-uniwrt" "$UNIWRT_ROOT/apk.log"
check "package gone from the database" bash -c "! grep -qx 'P:luci-theme-uniwrt' '$UNIWRT_ROOT/lib/apk/db/installed'"

SECTION="12c. a removal that leaves the package registered is caught"; echo "== 12c. a removal that leaves the package registered is caught =="
pkg_root 15; apk_stub ok
mkdir -p "$UNIWRT_ROOT/lib/apk/db"; printf 'P:luci-theme-uniwrt\n\n' > "$UNIWRT_ROOT/lib/apk/db/installed"
check "install stops" runfail --file "$ARCHIVE"
check "…saying the package is still registered" grep -q "still registered" "$T/out"
check "…and LuCI is on a working theme" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/bootstrap ]
rm -f "$BB/apk"

SECTION="12d. migrating from the package install (opkg, OpenWrt 23.05 / 24.10)"; echo "== 12d. migrating from the package install (opkg, OpenWrt 23.05 / 24.10) =="
pkg_root 16; rm -f "$UNIWRT_ROOT/pkg-installed"
mkdir -p "$UNIWRT_ROOT/usr/lib/opkg"
printf 'Package: luci-base\nStatus: install user installed\n\nPackage: luci-theme-uniwrt\nVersion: 2.0.39-r1\nStatus: install user installed\n\n' > "$UNIWRT_ROOT/usr/lib/opkg/status"
rm -f "$BB/opkg"
cat > "$BB/opkg" <<OPKG
#!/bin/sh
echo "opkg \$*" >> "\$UNIWRT_ROOT/opkg.log"
case "\$1" in
  status) grep -A2 "^Package: \$2\$" "\$UNIWRT_ROOT/usr/lib/opkg/status" ;;
  remove) awk -v p="\$2" 'BEGIN{RS="";ORS="\n\n"} \$2!=p' "\$UNIWRT_ROOT/usr/lib/opkg/status" > "\$UNIWRT_ROOT/s.n" && mv "\$UNIWRT_ROOT/s.n" "\$UNIWRT_ROOT/usr/lib/opkg/status"
          rm -rf "\$UNIWRT_ROOT/www/luci-static/uniwrt" "\$UNIWRT_ROOT/etc/config/uniwrt" ;;
esac
OPKG
chmod +x "$BB/opkg"
check "switch to standalone succeeds" run --file "$ARCHIVE"
check "opkg remove was called" grep -q "opkg remove luci-theme-uniwrt" "$UNIWRT_ROOT/opkg.log"
check "package gone from opkg status, others untouched" bash -c "! grep -q 'Package: luci-theme-uniwrt' '$UNIWRT_ROOT/usr/lib/opkg/status' && grep -q 'Package: luci-base' '$UNIWRT_ROOT/usr/lib/opkg/status'"
check "settings carried over" grep -q "mode 'dark'" "$UNIWRT_ROOT/etc/config/uniwrt"
check "all theme files present" all_present
rm -f "$BB/opkg"

if [ -n "${APK_BIN:-}" ] && [ -n "${PKG_APK:-}" ]; then
SECTION="12e. REAL apk: migrating the real 25.12 package"; echo "== 12e. REAL apk: migrating the real 25.12 package =="
new_root 17; mkdir -p "$UNIWRT_ROOT/etc/apk"
"$APK_BIN" mkpkg --info name:libc --info version:1-r1 --info arch:noarch --info description:stub --output "$T/libc.apk" >/dev/null
"$APK_BIN" mkpkg --info name:luci-base --info version:1-r1 --info arch:noarch --info description:stub --output "$T/luci-base.apk" >/dev/null
"$APK_BIN" --root "$UNIWRT_ROOT" --initdb --allow-untrusted --no-network add --no-scripts "$T/libc.apk" "$T/luci-base.apk" "$PKG_APK" >/dev/null 2>&1
check "real apk installed the 25.12 package (test precondition)" grep -qx "P:luci-theme-uniwrt" "$UNIWRT_ROOT/lib/apk/db/installed"
uci_ set luci.themes.UniWRT=/luci-static/uniwrt; uci_ set luci.main.mediaurlbase=/luci-static/uniwrt; uci_ commit luci
echo "	option accent '#38cc65'" >> "$UNIWRT_ROOT/etc/config/uniwrt"
rm -f "$BB/apk"
cat > "$BB/apk" <<APK
#!/bin/sh
# real apk on the fake root; maintainer scripts cannot run outside a real system
case "\$1" in add|del) c=\$1; shift; exec "$APK_BIN" --root "\$UNIWRT_ROOT" --no-network \$c --no-scripts "\$@" ;;
  *) exec "$APK_BIN" --root "\$UNIWRT_ROOT" --no-network "\$@" ;; esac
APK
chmod +x "$BB/apk"
# what rpcd's packagelist reports to the LuCI upgrade page: installed AND in world
asu_list() {
	awk '/^P:/{print substr($0,3)}' "$UNIWRT_ROOT/lib/apk/db/installed" | while read -r p; do
		sed 's/[@~<>=].*//' "$UNIWRT_ROOT/etc/apk/world" | grep -qx "$p" && echo "$p"
	done; true
}
if asu_list | grep -qx luci-theme-uniwrt; then ok "before: the theme is in the upgrade request"; else bad "before: the theme is in the upgrade request"; fi
check "migration succeeds" run --file "$ARCHIVE"
if [ -f "$UNIWRT_ROOT/lib/apk/db/installed" ] && ! asu_list | grep -qx luci-theme-uniwrt; then ok "after: the theme is NOT in the upgrade request"; else bad "after: the theme is NOT in the upgrade request"; fi
check "after: not installed per apk either" bash -c "! UNIWRT_ROOT='$UNIWRT_ROOT' '$BB/apk' info -e luci-theme-uniwrt >/dev/null 2>&1"
check "custom settings kept" grep -q 38cc65 "$UNIWRT_ROOT/etc/config/uniwrt"
check "all theme files present" all_present
check "theme active" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/uniwrt ]
rm -f "$BB/apk"
fi

SECTION="13. rejects a wrong archive"; echo "== 13. rejects a wrong archive =="
new_root 13; mkdir -p "$T/bogus/etc"; echo hi > "$T/bogus/etc/x"; tar czf "$T/luci-theme-uniwrt-standalone.tar.gz" -C "$T/bogus" .
check "non-UniWRT archive refused" runfail --file "$T/luci-theme-uniwrt-standalone.tar.gz"
check "nothing installed" [ ! -e "$UNIWRT_ROOT/$KEEP" ]

echo
echo "passed: $pass  failed: $fail"
[ "$fail" = 0 ]
