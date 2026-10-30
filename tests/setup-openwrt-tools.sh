#!/usr/bin/env bash
#
# tests/setup-openwrt-tools.sh <outdir>
#
# Builds the router tools uniwrt-apply.sh depends on, as OpenWrt ships them:
#   - BusyBox, configured with OpenWrt's default applet set (no tr classes,
#     no busybox wget, ...), from openwrt/openwrt's Config-defaults.in
#   - uci, from openwrt/uci (with libubox)
#   - apk-tools, at the exact commit OpenWrt's apk package pins (25.12+)
#
# Prints the environment for tests/test-apply.sh:
#   BUSYBOX=… BUSYBOX_LINKS=… UCI_BIN=… APK_BIN=…
#
# Set BUSYBOX_SRC to an unpacked BusyBox tree to skip the download.
# Needs: git, make, gcc, cmake, pkg-config, meson, ninja, json-c, openssl and zlib headers.
#
set -euo pipefail
OUT="$(mkdir -p "${1:?usage: $0 <outdir>}" && cd "$1" && pwd)"
W="$OUT/work"; mkdir -p "$W"; cd "$W"

log() { echo "[setup] $*" >&2; }

# --- OpenWrt's BusyBox config and version ------------------------------------
if [ ! -d openwrt ]; then
	git clone -q --depth 1 --filter=blob:none --sparse https://github.com/openwrt/openwrt.git openwrt
	git -C openwrt sparse-checkout set package/utils/busybox package/system/apk
fi
MK=openwrt/package/utils/busybox/Makefile
BBVER="$(sed -n 's/^PKG_VERSION:=//p' "$MK")"
BBHASH="$(sed -n 's/^PKG_HASH:=//p' "$MK")"

if [ -n "${BUSYBOX_SRC:-}" ]; then
	BB="$BUSYBOX_SRC"
else
	if [ ! -d "busybox-$BBVER" ]; then
		log "downloading BusyBox $BBVER"
		curl -fsSL -o bb.tar.bz2 "https://www.busybox.net/downloads/busybox-$BBVER.tar.bz2"
		echo "$BBHASH  bb.tar.bz2" | sha256sum -c - >&2
		tar xjf bb.tar.bz2
	fi
	BB="$W/busybox-$BBVER"
fi

log "configuring BusyBox with OpenWrt defaults"
python3 - "$W/openwrt/package/utils/busybox/Config-defaults.in" "$BB/.config" <<'EOF'
import re, sys
src = open(sys.argv[1]).read()
out = []
for m in re.finditer(r'config BUSYBOX_DEFAULT_(\w+)\n(?:.*\n)*?\s*default (.+)', src):
    k, v = m.group(1), m.group(2).strip()
    if k in ('EXTRA_CFLAGS', 'SYSROOT'):   # host build: no cross-compile flags
        continue
    if k == 'TC':                          # needs old kernel headers; irrelevant here
        v = 'n'
    out.append(f'CONFIG_{k}=y' if v == 'y' else f'# CONFIG_{k} is not set' if v == 'n' else f'CONFIG_{k}={v}')
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
EOF
( cd "$BB" && { yes '' | make oldconfig >/dev/null 2>&1 || true; } && make -j"$(nproc)" >"$W/busybox-build.log" 2>&1 && make busybox.links >/dev/null 2>&1 ) \
	|| { tail -20 "$W/busybox-build.log" >&2; exit 1; }
cp "$BB/busybox" "$BB/busybox.links" "$OUT/"
grep -q '^# CONFIG_FEATURE_TR_CLASSES is not set' "$BB/.config" || { log "unexpected config"; exit 1; }

# --- uci ----------------------------------------------------------------------
P="$W/prefix"
for r in libubox uci; do [ -d "$r" ] || git clone -q --depth 1 "https://github.com/openwrt/$r.git"; done
log "building libubox + uci"
( cd libubox && cmake -S . -B b -DCMAKE_INSTALL_PREFIX="$P" -DBUILD_LUA=OFF -DBUILD_EXAMPLES=OFF >/dev/null && cmake --build b -j8 >/dev/null && cmake --install b >/dev/null )
( cd uci && cmake -S . -B b -DCMAKE_INSTALL_PREFIX="$P" -DBUILD_LUA=OFF -DCMAKE_C_FLAGS="-I$P/include" \
	-DCMAKE_EXE_LINKER_FLAGS="-L$P/lib -Wl,-rpath,$P/lib" -DCMAKE_SHARED_LINKER_FLAGS="-L$P/lib -Wl,-rpath,$P/lib" >/dev/null \
	&& cmake --build b -j8 >/dev/null && cmake --install b >/dev/null )
cp "$P/bin/uci" "$OUT/uci"

# --- apk-tools ------------------------------------------------------------------
APKREV="$(sed -n 's/^PKG_SOURCE_VERSION:=//p' openwrt/package/system/apk/Makefile)"
if [ ! -d apk-tools ]; then
	git init -q apk-tools
	git -C apk-tools fetch -q --depth 1 https://github.com/alpinelinux/apk-tools.git "$APKREV"
	git -C apk-tools checkout -q FETCH_HEAD
fi
log "building apk-tools ${APKREV:0:10}"
( cd apk-tools && meson setup b -Dlua=disabled -Ddocs=disabled -Dhelp=disabled -Dtests=disabled -Durl_backend=wget -Ddefault_library=static >/dev/null \
	&& ninja -C b >/dev/null )
cp apk-tools/b/src/apk "$OUT/apk"
"$OUT/apk" --version >&2   # must run from its new location

echo "BUSYBOX=$OUT/busybox BUSYBOX_LINKS=$OUT/busybox.links UCI_BIN=$OUT/uci APK_BIN=$OUT/apk"
