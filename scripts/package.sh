#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_NAME="luci-theme-uniwrt"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
RELEASE="1"
PKGVER="${VERSION}-r${RELEASE}"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/build/package"
PKGROOT="$BUILD_DIR/pkgroot"
CONTROL_IPK="$BUILD_DIR/control-ipk"
CONTROL_APK="$BUILD_DIR/control-apk"
LOG_FILE="$DIST_DIR/package-${VERSION}.log"

mkdir -p "$DIST_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$PKGROOT" "$CONTROL_IPK" "$CONTROL_APK"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

fail() {
  echo "ERROR: $*" >&2
  echo "Build log saved to: $LOG_FILE" >&2
  exit 1
}

need_file() {
  [ -e "$ROOT_DIR/$1" ] || fail "Missing required file or directory: $1"
}

need_file htdocs/luci-static/uniwrt/cascade.css
need_file htdocs/luci-static/uniwrt/uniwrt.js
need_file htdocs/luci-static/uniwrt/logo.svg
need_file ucode/template/themes/uniwrt/header.ut
need_file ucode/template/themes/uniwrt/footer.ut
need_file root/etc/uci-defaults/30_luci-theme-uniwrt

if [ -z "$VERSION" ]; then
  fail "VERSION is empty"
fi

case "$VERSION" in
  *[!0-9.]*|'') fail "VERSION must be numeric dotted format, got: $VERSION" ;;
esac

if ! command -v ar >/dev/null 2>&1; then
  fail "ar command is required to build .ipk"
fi

copy_tree() {
  src="$1"
  dst="$2"
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
}

echo "==> Staging UniWRT files"
copy_tree "$ROOT_DIR/htdocs/luci-static/uniwrt" "$PKGROOT/www/luci-static/uniwrt"
copy_tree "$ROOT_DIR/ucode/template/themes/uniwrt" "$PKGROOT/usr/share/ucode/luci/template/themes/uniwrt"
mkdir -p "$PKGROOT/etc/uci-defaults"
install -m 0755 "$ROOT_DIR/root/etc/uci-defaults/30_luci-theme-uniwrt" "$PKGROOT/etc/uci-defaults/30_luci-theme-uniwrt"

DATA_SIZE="$(du -ks "$PKGROOT" | awk '{print $1 * 1024}')"
BUILD_DATE="$(date +%s)"

cat > "$CONTROL_IPK/control" <<EOF_CONTROL
Package: ${PKG_NAME}
Version: ${PKGVER}
Architecture: all
Maintainer: Mahabub X <mgrsubhany7@gmail.com>
Section: luci
Priority: optional
Depends: luci-base, luci-theme-bootstrap
Description: UniWRT Theme for LuCI.
EOF_CONTROL

cat > "$CONTROL_IPK/postinst" <<'EOF_POSTINST'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
[ -x /etc/uci-defaults/30_luci-theme-uniwrt ] && /etc/uci-defaults/30_luci-theme-uniwrt || true
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
exit 0
EOF_POSTINST

cat > "$CONTROL_IPK/postrm" <<'EOF_POSTRM'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
uci -q delete luci.themes.UniWRT
uci -q delete luci.themes.UniWRTDark
uci -q delete luci.themes.UniWRTLight
if [ "$(uci -q get luci.main.mediaurlbase)" = "/luci-static/uniwrt" ]; then
  uci set luci.main.mediaurlbase='/luci-static/bootstrap'
fi
uci commit luci
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
exit 0
EOF_POSTRM
chmod 0755 "$CONTROL_IPK/postinst" "$CONTROL_IPK/postrm"

cat > "$CONTROL_APK/.PKGINFO" <<EOF_PKGINFO
pkgname = ${PKG_NAME}
pkgver = ${PKGVER}
pkgdesc = UniWRT Theme for LuCI.
url = https://github.com/ox1d3x3/uniwrt-luci
builddate = ${BUILD_DATE}
packager = Mahabub X <mgrsubhany7@gmail.com>
size = ${DATA_SIZE}
arch = all
origin = ${PKG_NAME}
maintainer = Mahabub X <mgrsubhany7@gmail.com>
license = Apache-2.0
depend = luci-base
depend = luci-theme-bootstrap
EOF_PKGINFO

cat > "$CONTROL_APK/.post-install" <<'EOF_APK_POSTINSTALL'
#!/bin/sh
[ -x /etc/uci-defaults/30_luci-theme-uniwrt ] && /etc/uci-defaults/30_luci-theme-uniwrt || true
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
exit 0
EOF_APK_POSTINSTALL

cat > "$CONTROL_APK/.post-deinstall" <<'EOF_APK_POSTDEINSTALL'
#!/bin/sh
uci -q delete luci.themes.UniWRT
uci -q delete luci.themes.UniWRTDark
uci -q delete luci.themes.UniWRTLight
if [ "$(uci -q get luci.main.mediaurlbase)" = "/luci-static/uniwrt" ]; then
  uci set luci.main.mediaurlbase='/luci-static/bootstrap'
fi
uci commit luci
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
exit 0
EOF_APK_POSTDEINSTALL
chmod 0755 "$CONTROL_APK/.post-install" "$CONTROL_APK/.post-deinstall"

make_tar_gz() {
  dir="$1"
  out="$2"
  shift 2
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='UTC 2024-01-01' -C "$dir" -czf "$out" "$@"
}

make_apk_control_gz() {
  dir="$1"
  out="$2"
  if command -v abuild-tar >/dev/null 2>&1; then
    tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='UTC 2024-01-01' -C "$dir" -cf - ./.PKGINFO ./.post-install ./.post-deinstall | abuild-tar --cut | gzip -9 -n > "$out"
  else
    make_tar_gz "$dir" "$out" ./.PKGINFO ./.post-install ./.post-deinstall
  fi
}

make_apk_data_gz() {
  dir="$1"
  out="$2"
  if command -v abuild-tar >/dev/null 2>&1; then
    tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='UTC 2024-01-01' -C "$dir" -cf - . | abuild-tar --hash | gzip -9 -n > "$out"
  else
    make_tar_gz "$dir" "$out" .
  fi
}

build_ipk() {
  echo "==> Building universal IPK"
  work="$BUILD_DIR/ipk"
  mkdir -p "$work"
  printf '2.0\n' > "$work/debian-binary"
  make_tar_gz "$CONTROL_IPK" "$work/control.tar.gz" ./control ./postinst ./postrm
  make_tar_gz "$PKGROOT" "$work/data.tar.gz" .
  (cd "$work" && ar r "$DIST_DIR/${PKG_NAME}_${PKGVER}_all.ipk" debian-binary control.tar.gz data.tar.gz >/dev/null)
  cp -f "$DIST_DIR/${PKG_NAME}_${PKGVER}_all.ipk" "$DIST_DIR/${PKG_NAME}.ipk"
  cp -f "$DIST_DIR/${PKG_NAME}_${PKGVER}_all.ipk" "$DIST_DIR/${PKG_NAME}_all.ipk"
}

build_apk() {
  echo "==> Building universal APK"
  work="$BUILD_DIR/apk"
  mkdir -p "$work"
  make_apk_data_gz "$PKGROOT" "$work/data.tar.gz"
  datahash="$(sha256sum "$work/data.tar.gz" | awk '{print $1}')"
  sed -i '/^datahash = /d' "$CONTROL_APK/.PKGINFO"
  printf 'datahash = %s\n' "$datahash" >> "$CONTROL_APK/.PKGINFO"
  make_apk_control_gz "$CONTROL_APK" "$work/control.tar.gz"
  cat "$work/control.tar.gz" "$work/data.tar.gz" > "$DIST_DIR/${PKG_NAME}-${PKGVER}.apk"
  cp -f "$DIST_DIR/${PKG_NAME}-${PKGVER}.apk" "$DIST_DIR/${PKG_NAME}.apk"
  cp -f "$DIST_DIR/${PKG_NAME}-${PKGVER}.apk" "$DIST_DIR/${PKG_NAME}_all.apk"
}

verify_ipk() {
  ipk="$DIST_DIR/${PKG_NAME}.ipk"
  echo "==> Verifying IPK"
  ar t "$ipk" | grep -qx 'debian-binary'
  ar t "$ipk" | grep -qx 'control.tar.gz'
  ar t "$ipk" | grep -qx 'data.tar.gz'
  tmp="$BUILD_DIR/verify-ipk"
  mkdir -p "$tmp"
  (cd "$tmp" && ar x "$ipk" control.tar.gz data.tar.gz)
  tar -xOf "$tmp/control.tar.gz" ./control | grep -qx 'Architecture: all'
  tar -tf "$tmp/data.tar.gz" | grep -qx './www/luci-static/uniwrt/cascade.css'
  tar -tf "$tmp/data.tar.gz" | grep -qx './usr/share/ucode/luci/template/themes/uniwrt/header.ut'
}

verify_apk() {
  apk="$DIST_DIR/${PKG_NAME}.apk"
  echo "==> Verifying APK payload"
  # APK is two gzip-compressed tar streams concatenated. Python's gzip reader can split them reliably.
  python3 - "$apk" "$BUILD_DIR/verify-apk" <<'PY'
import io, os, sys, tarfile, zlib
apk, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)
with open(apk, 'rb') as f:
    raw = f.read()
streams = []
blob = raw
while blob:
    d = zlib.decompressobj(16 + zlib.MAX_WBITS)
    data = d.decompress(blob)
    data += d.flush()
    consumed = len(blob) - len(d.unused_data)
    if consumed <= 0:
        raise SystemExit('failed to parse gzip member')
    streams.append(data)
    blob = d.unused_data
if len(streams) != 2:
    raise SystemExit(f'expected 2 gzip members, got {len(streams)}')
control = tarfile.open(fileobj=io.BytesIO(streams[0]), mode='r:')
data = tarfile.open(fileobj=io.BytesIO(streams[1]), mode='r:')
control_names = set(control.getnames())
data_names = set(data.getnames())
assert '.PKGINFO' in control_names or './.PKGINFO' in control_names, control_names
pkginfo_member = '.PKGINFO' if '.PKGINFO' in control_names else './.PKGINFO'
pkginfo = control.extractfile(pkginfo_member).read().decode()
assert 'pkgname = luci-theme-uniwrt' in pkginfo
assert 'arch = all' in pkginfo
assert 'datahash = ' in pkginfo
assert './www/luci-static/uniwrt/cascade.css' in data_names or 'www/luci-static/uniwrt/cascade.css' in data_names
assert './usr/share/ucode/luci/template/themes/uniwrt/header.ut' in data_names or 'usr/share/ucode/luci/template/themes/uniwrt/header.ut' in data_names
print('apk-structure-ok')
PY
}

rm -f "$DIST_DIR"/${PKG_NAME}*.ipk "$DIST_DIR"/${PKG_NAME}*.apk
build_ipk
build_apk
verify_ipk
verify_apk

ls -lh "$DIST_DIR"/${PKG_NAME}*.ipk "$DIST_DIR"/${PKG_NAME}*.apk "$LOG_FILE"
echo "==> Done. Universal packages are in $DIST_DIR"
