#!/usr/bin/env bash
#
# tests/test-apply.sh <standalone.tar.gz>
#
# Exercises uniwrt-apply.sh against a fake router root (UNIWRT_ROOT) using
# BusyBox's shell and applets, with stub uci / apk / uclient-fetch. Includes
# a simulated sysupgrade that keeps exactly what OpenWrt's sysupgrade would
# (the same keep.d expansion as base-files' list_static_conffiles).
#
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../uniwrt-apply.sh"
ARCHIVE="$(cd "$(dirname "${1:?usage: $0 <standalone.tar.gz>}")" && pwd)/$(basename "$1")"
BUSYBOX="$(command -v busybox)" || { echo "busybox is required"; exit 2; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { printf '\033[32mok\033[0m   %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '\033[31mFAIL\033[0m %s\n' "$*"; fail=$((fail+1)); }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

# --- BusyBox applets + stubs on PATH -----------------------------------------
BB="$T/bin"; mkdir -p "$BB"
busybox --install -s "$BB" 2>/dev/null || for a in $(busybox --list); do ln -sf "$(command -v busybox)" "$BB/$a"; done
rm -f "$BB/wget"   # make sure downloads go through the uclient-fetch stub

cat > "$BB/uci" <<'EOF'
#!/bin/sh
# file-backed uci stub: get / set / delete / commit
db="$UNIWRT_ROOT/uci.db"; touch "$db"
[ "$1" = "-q" ] && shift
case "$1" in
  get)    v=$(grep "^$2=" "$db" | tail -n1 | cut -d= -f2-); [ -n "$v" ] && echo "$v" || exit 1 ;;
  set)    k="${2%%=*}"; grep -v "^$k=" "$db" > "$db.n"; echo "$2" >> "$db.n"; mv "$db.n" "$db" ;;
  delete) grep -q "^$2=" "$db" || exit 1; grep -v "^$2=" "$db" > "$db.n"; mv "$db.n" "$db" ;;
  commit) echo "commit $2" >> "$UNIWRT_ROOT/uci.log" ;;
esac
EOF
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
f="$FAKE_GH/$tag/$(basename "$url")"; [ -f "$f" ] || exit 1; cp "$f" "$out"
EOF
chmod +x "$BB/uci" "$BB/uclient-fetch"

new_root() {
	export UNIWRT_ROOT="$T/root$1"; rm -rf "$UNIWRT_ROOT"
	mkdir -p "$UNIWRT_ROOT/tmp" "$UNIWRT_ROOT/etc/config" "$UNIWRT_ROOT/www/luci-static/bootstrap" \
	         "$UNIWRT_ROOT/usr/share/ucode/luci/template/themes/bootstrap" "$UNIWRT_ROOT/lib/upgrade/keep.d"
	echo "/etc/config/luci" > "$UNIWRT_ROOT/lib/upgrade/keep.d/base"   # stand-in for stock keep entries
	printf '%s\n' "luci.themes.Bootstrap=/luci-static/bootstrap" "luci.main.mediaurlbase=/luci-static/bootstrap" > "$UNIWRT_ROOT/uci.db"
	: > "$UNIWRT_ROOT/etc/config/luci"
}
run() { PATH="$BB" "$BUSYBOX" sh "$SCRIPT" "$@" > "$T/out" 2>&1; local rc=$?; [ $rc = 0 ] || sed 's/^/      | /' "$T/out"; return $rc; }
uciget() { grep "^$1=" "$UNIWRT_ROOT/uci.db" | tail -n1 | cut -d= -f2-; }
KEEP=lib/upgrade/keep.d/uniwrt-standalone
FILES=$(tar tzf "$ARCHIVE" | sed 's,^\./,/,' | grep -v '/$' | grep -v '^/etc/uci-defaults/')

# Simulate a firmware upgrade with "Keep settings": compute the keep list the
# way base-files' sysupgrade does, wipe everything, restore only those files.
sysupgrade_keep() {
	local r="$UNIWRT_ROOT" list="$T/kept"
	( cd "$r" && find $(sed -ne '/^[[:space:]]*$/d; /^#/d; s,^/,./,; p' lib/upgrade/keep.d/* 2>/dev/null) \
		\( -type f -o -type l \) 2>/dev/null ) | sort -u > "$list"
	tar -C "$r" -cf "$T/backup.tar" -T "$list"
	cp "$r/uci.db" "$T/uci.db.bak"                       # /etc/config/luci stand-in
	new_root "${r#$T/root}"                              # factory-fresh firmware
	tar -C "$UNIWRT_ROOT" -xf "$T/backup.tar"; cp "$T/uci.db.bak" "$UNIWRT_ROOT/uci.db"
}

echo "== 1. fresh standalone install from a local archive =="
new_root 1; cp "$ARCHIVE" "$UNIWRT_ROOT/tmp/"
check "install succeeds" run --file "$UNIWRT_ROOT/tmp/$(basename "$ARCHIVE")"
missing=0; for f in $FILES; do [ -f "$UNIWRT_ROOT$f" ] || { echo "      missing $f"; missing=1; }; done
check "all theme files installed" [ $missing = 0 ]
check "files are byte-identical to the archive" bash -c "mkdir -p '$T/x' && tar xzf '$ARCHIVE' -C '$T/x' && for f in $(echo $FILES | tr '\n' ' '); do cmp -s \"$T/x\$f\" \"$UNIWRT_ROOT\$f\" || exit 1; done"
check "uci-defaults hook NOT installed" [ ! -e "$UNIWRT_ROOT/etc/uci-defaults/30_luci-theme-uniwrt" ]
check "theme registered" [ "$(uciget luci.themes.UniWRT)" = /luci-static/uniwrt ]
check "theme activated on fresh install" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/uniwrt ]
check "keep.d manifest written" [ -f "$UNIWRT_ROOT/$KEEP" ]
check "manifest lists itself and the config" bash -c "grep -qx /$KEEP '$UNIWRT_ROOT/$KEEP' && grep -qx /etc/config/uniwrt '$UNIWRT_ROOT/$KEEP'"
check "no temp files left behind" bash -c "! find '$UNIWRT_ROOT' -name '*.uniwrt-new' | grep -q . && ! ls '$UNIWRT_ROOT'/tmp/uniwrt.* >/dev/null 2>&1"
check "status reports standalone" bash -c "PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --status | grep -q standalone"

echo "== 2. survives a firmware upgrade with Keep settings =="
echo "	option accent '#38cc65'" >> "$UNIWRT_ROOT/etc/config/uniwrt"
sysupgrade_keep
missing=0; for f in $FILES; do [ -f "$UNIWRT_ROOT$f" ] || { echo "      lost $f"; missing=1; }; done
check "every theme file is restored after the upgrade" [ $missing = 0 ]
check "user settings restored" grep -q "38cc65" "$UNIWRT_ROOT/etc/config/uniwrt"
check "manifest itself restored (so the next upgrade keeps it too)" [ -f "$UNIWRT_ROOT/$KEEP" ]
check "theme still active" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/uniwrt ]
sysupgrade_keep
check "and survives a second upgrade" [ -f "$UNIWRT_ROOT/www/luci-static/uniwrt/css/cascade.css" ]

echo "== 3. update: keeps settings and theme choice, removes stale files =="
uci_db="$UNIWRT_ROOT/uci.db"; sed -i 's,^luci.main.mediaurlbase=.*,luci.main.mediaurlbase=/luci-static/bootstrap,' "$uci_db"
mkdir -p "$UNIWRT_ROOT/www/luci-static/uniwrt/old"; echo x > "$UNIWRT_ROOT/www/luci-static/uniwrt/old/legacy.css"
echo "/www/luci-static/uniwrt/old/legacy.css" >> "$UNIWRT_ROOT/$KEEP"
check "re-run succeeds" run --file "$ARCHIVE"
check "user settings untouched" grep -q "38cc65" "$UNIWRT_ROOT/etc/config/uniwrt"
check "user's theme choice not overridden on update" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/bootstrap ]
check "stale file from previous version removed" [ ! -e "$UNIWRT_ROOT/www/luci-static/uniwrt/old/legacy.css" ]
check "stale file dropped from manifest" bash -c "! grep -q legacy.css '$UNIWRT_ROOT/$KEEP'"

echo "== 4. uninstall =="
sed -i 's,^luci.main.mediaurlbase=.*,luci.main.mediaurlbase=/luci-static/uniwrt,' "$uci_db"
check "uninstall succeeds" run --uninstall
left=$(cd "$UNIWRT_ROOT" && find . -path '*uniwrt*' | grep -v '^./uci' || true)
check "no UniWRT files or dirs left" [ -z "$left" ]
[ -z "$left" ] || echo "$left" | sed 's/^/      left: /'
check "bootstrap theme dirs untouched" [ -d "$UNIWRT_ROOT/usr/share/ucode/luci/template/themes/bootstrap" ]
check "theme unregistered" [ -z "$(uciget luci.themes.UniWRT)" ]
check "LuCI switched back to Bootstrap" [ "$(uciget luci.main.mediaurlbase)" = /luci-static/bootstrap ]
check "uninstall again fails cleanly" bash -c "! PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --uninstall >/dev/null 2>&1"

echo "== 5. online install: latest and pinned version, checksum enforced =="
new_root 5; export FAKE_GH="$T/gh"
for tag in latest v9.9.9; do
	mkdir -p "$FAKE_GH/$tag"; cp "$ARCHIVE" "$FAKE_GH/$tag/luci-theme-uniwrt-standalone.tar.gz"
	( cd "$FAKE_GH/$tag" && sha256sum luci-theme-uniwrt-standalone.tar.gz uniwrt-apply.sh 2>/dev/null > SHA256SUMS; true )
done
check "downloads latest release" run
check "used the releases/latest URL" grep -q "releases/latest/download/luci-theme-uniwrt-standalone.tar.gz" "$UNIWRT_ROOT/fetch.log"
check "--version fetches that tag" run --version 9.9.9
check "used the pinned tag URL" grep -q "releases/download/v9.9.9/" "$UNIWRT_ROOT/fetch.log"
echo garbage >> "$FAKE_GH/latest/luci-theme-uniwrt-standalone.tar.gz"
check "corrupt download is rejected" bash -c "! PATH='$BB' '$BUSYBOX' sh '$SCRIPT' > '$T/out' 2>&1"
check "…with a checksum error" grep -qi "checksum mismatch" "$T/out"
check "…and the installed theme is left intact" [ -f "$UNIWRT_ROOT/www/luci-static/uniwrt/css/cascade.css" ]

echo "== 6. migrating from the package install =="
new_root 6
mkdir -p "$T/x6" && tar xzf "$ARCHIVE" -C "$T/x6" && cp -a "$T/x6/." "$UNIWRT_ROOT/" && rm -rf "$UNIWRT_ROOT/etc/uci-defaults"
echo "	option mode 'dark'" >> "$UNIWRT_ROOT/etc/config/uniwrt"
printf '%s\n' "luci.themes.UniWRT=/luci-static/uniwrt" >> "$UNIWRT_ROOT/uci.db"
sed -i 's,^luci.main.mediaurlbase=.*,luci.main.mediaurlbase=/luci-static/uniwrt,' "$UNIWRT_ROOT/uci.db"
touch "$UNIWRT_ROOT/pkg-installed"
cat > "$BB/apk" <<EOF
#!/bin/sh
echo "apk \$*" >> "\$UNIWRT_ROOT/apk.log"
case "\$1" in
  info) [ -f "\$UNIWRT_ROOT/pkg-installed" ] ;;
  del)  # like the real package removal: files go, postrm unregisters the theme
        rm -f "\$UNIWRT_ROOT/pkg-installed" "\$UNIWRT_ROOT/etc/config/uniwrt"
        rm -rf "\$UNIWRT_ROOT/www/luci-static/uniwrt" "\$UNIWRT_ROOT/usr/share/ucode/luci/template/themes/uniwrt"
        grep -v '^luci.themes.UniWRT=' "\$UNIWRT_ROOT/uci.db" > "\$UNIWRT_ROOT/uci.n"; mv "\$UNIWRT_ROOT/uci.n" "\$UNIWRT_ROOT/uci.db" ;;
esac
EOF
chmod +x "$BB/apk"
check "status flags the package install" bash -c "PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --status | grep -q 'as a package'"
check "switch to standalone succeeds" run --file "$ARCHIVE"
check "package was removed" grep -q "apk del luci-theme-uniwrt" "$UNIWRT_ROOT/apk.log"
check "settings carried over" grep -q "mode 'dark'" "$UNIWRT_ROOT/etc/config/uniwrt"
check "theme files back in place" [ -f "$UNIWRT_ROOT/www/luci-static/uniwrt/css/cascade.css" ]
check "theme re-registered and still active" bash -c "[ \"\$(grep '^luci.themes.UniWRT=' '$UNIWRT_ROOT/uci.db' | cut -d= -f2)\" = /luci-static/uniwrt ] && grep -q 'mediaurlbase=/luci-static/uniwrt' '$UNIWRT_ROOT/uci.db'"
check "now reported as standalone" bash -c "PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --status | grep -q standalone"
rm -f "$BB/apk"

echo "== 7. rejects a wrong archive =="
new_root 7; mkdir -p "$T/bogus/etc"; echo hi > "$T/bogus/etc/x"; tar czf "$T/luci-theme-uniwrt-standalone.tar.gz" -C "$T/bogus" .
check "non-UniWRT archive refused" bash -c "! PATH='$BB' '$BUSYBOX' sh '$SCRIPT' --file '$T/luci-theme-uniwrt-standalone.tar.gz' >/dev/null 2>&1"
check "nothing installed" [ ! -e "$UNIWRT_ROOT/$KEEP" ]

echo
echo "passed: $pass  failed: $fail"
[ "$fail" = 0 ]
