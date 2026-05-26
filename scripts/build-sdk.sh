#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -Eeuo pipefail

OPENWRT_VERSION="${OPENWRT_VERSION:-25.12.4}"
TARGET="${TARGET:-mediatek}"
SUBTARGET="${SUBTARGET:-mt7622}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.sdk-$OPENWRT_VERSION-$TARGET-$SUBTARGET}"
DIST_DIR="$ROOT_DIR/dist"
SDK_BASE="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}/"
PKG_NAME="luci-theme-uniwrt"
CUSTOM_PKG_PATH="package/custom/$PKG_NAME"
LOG_FILE="$DIST_DIR/build-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}.log"

mkdir -p "$WORK_DIR" "$DIST_DIR"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

fail() {
	echo "ERROR: $*" >&2
	echo "Build log saved to: $LOG_FILE" >&2
	exit 1
}

cd "$WORK_DIR"

echo "==> Discovering SDK at $SDK_BASE"
SDK_INDEX="$(curl --fail --silent --show-error --location --retry 5 --retry-delay 3 --retry-all-errors "$SDK_BASE")"
SDK_FILE="$(printf '%s\n' "$SDK_INDEX" | grep -oE 'openwrt-sdk-[^"<>]+Linux-x86_64\.tar\.(xz|zst)' | sort -V | tail -n1 || true)"
[ -n "$SDK_FILE" ] || fail "SDK file not found at $SDK_BASE"

if [ ! -d sdk ]; then
	echo "==> Downloading $SDK_FILE"
	rm -f "$SDK_FILE"
	curl --fail --location --retry 5 --retry-delay 3 --retry-all-errors "$SDK_BASE$SDK_FILE" -o "$SDK_FILE"

	echo "==> Extracting SDK"
	rm -rf openwrt-sdk-* sdk
	case "$SDK_FILE" in
		*.tar.zst) tar --zstd -xf "$SDK_FILE" ;;
		*.tar.xz)  tar -xf "$SDK_FILE" ;;
		*) fail "Unsupported SDK archive: $SDK_FILE" ;;
	esac
	SDK_TOPDIR="$(find . -maxdepth 1 -type d -name 'openwrt-sdk-*' | sort -V | tail -n1)"
	[ -n "$SDK_TOPDIR" ] || fail "Extracted SDK directory not found"
	mv "$SDK_TOPDIR" sdk
fi

cd sdk

echo "==> Copying UniWRT package into SDK package tree: $CUSTOM_PKG_PATH"
rm -rf "$CUSTOM_PKG_PATH"
mkdir -p "$CUSTOM_PKG_PATH"
rsync -a --delete \
	--exclude '.git' \
	--exclude '.github' \
	--exclude '.sdk-*' \
	--exclude 'dist' \
	--exclude '*.zip' \
	"$ROOT_DIR/" "$CUSTOM_PKG_PATH/"

[ -f "$CUSTOM_PKG_PATH/Makefile" ] || fail "Package Makefile missing at $CUSTOM_PKG_PATH/Makefile"
[ -f "$CUSTOM_PKG_PATH/htdocs/luci-static/uniwrt/cascade.css" ] || fail "Theme assets missing after copy"
[ -f "$CUSTOM_PKG_PATH/ucode/template/themes/uniwrt/header.ut" ] || fail "Theme template missing after copy"

if grep -q 'luci.mk' "$CUSTOM_PKG_PATH/Makefile"; then
	fail "Do not use luci.mk for this static theme package. Use package.mk only."
fi

if grep -RInE 'C[l]eanX|c[l]eanx|luci-theme-c[l]eanx' "$CUSTOM_PKG_PATH" 2>/dev/null; then
	fail "Old legacy naming still exists. This package must be UniWRT / luci-theme-uniwrt only."
fi

grep -nE 'PKG_NAME|PKG_VERSION|TITLE|BuildPackage' "$CUSTOM_PKG_PATH/Makefile" || true

sed -i "/^CONFIG_PACKAGE_${PKG_NAME}=/d" .config 2>/dev/null || true
echo "CONFIG_PACKAGE_${PKG_NAME}=m" >> .config
make defconfig

echo "==> Building $PKG_NAME for OpenWrt $OPENWRT_VERSION target $TARGET/$SUBTARGET"
make "package/custom/$PKG_NAME/clean" V=s || true
make "package/custom/$PKG_NAME/compile" V=s -j1

echo "==> Collecting packages"
find bin -type f \( -name "${PKG_NAME}_*.ipk" -o -name "${PKG_NAME}-*.apk" -o -name "${PKG_NAME}_*.apk" \) -print -exec cp -f {} "$DIST_DIR/" \;

shopt -s nullglob
ipks=("$DIST_DIR"/${PKG_NAME}_*.ipk)
apks=("$DIST_DIR"/${PKG_NAME}-*.apk "$DIST_DIR"/${PKG_NAME}_*.apk)

if [ "${#ipks[@]}" -eq 0 ] && [ "${#apks[@]}" -eq 0 ]; then
	fail "Build completed but no UniWRT package was found in bin/."
fi

for f in "${ipks[@]}"; do
	[ -f "$f" ] || continue
	cp -f "$f" "$DIST_DIR/${PKG_NAME}.ipk"
	cp -f "$f" "$DIST_DIR/${PKG_NAME}-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}.ipk"
done

for f in "${apks[@]}"; do
	[ -f "$f" ] || continue
	cp -f "$f" "$DIST_DIR/${PKG_NAME}.apk"
	cp -f "$f" "$DIST_DIR/${PKG_NAME}-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}.apk"
done

ls -lh "$DIST_DIR"/${PKG_NAME}* 2>/dev/null || true
echo "==> Done. Output is in $DIST_DIR"
