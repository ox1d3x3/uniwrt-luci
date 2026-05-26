#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -Eeuo pipefail

OPENWRT_VERSION="${OPENWRT_VERSION:-25.12.4}"
TARGET="${TARGET:-x86}"
SUBTARGET="${SUBTARGET:-64}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.sdk-$OPENWRT_VERSION-$TARGET-$SUBTARGET}"
DIST_DIR="$ROOT_DIR/dist"
SDK_BASE="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}/"
PKG_NAME="luci-theme-uniwrt"
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
	curl --fail --location --retry 5 --retry-delay 3 --retry-all-errors "$SDK_BASE/$SDK_FILE" -o "$SDK_FILE"

	echo "==> Extracting SDK"
	rm -f sdk-tar-list.txt
	tar -tf "$SDK_FILE" > sdk-tar-list.txt
	SDK_TOPDIR="$(awk -F/ 'NF { print $1; exit }' sdk-tar-list.txt)"
	[ -n "$SDK_TOPDIR" ] || fail "Could not detect SDK root directory in $SDK_FILE"

	rm -rf "$SDK_TOPDIR" sdk
	tar -xf "$SDK_FILE"
	[ -d "$SDK_TOPDIR" ] || fail "Extracted SDK directory not found: $SDK_TOPDIR"
	mv "$SDK_TOPDIR" sdk
fi

cd sdk

echo "==> Updating feeds"
./scripts/feeds update -a

THEME_DIR="feeds/luci/themes/$PKG_NAME"
echo "==> Copying UniWRT into LuCI feed: $THEME_DIR"
rm -rf "$THEME_DIR"
mkdir -p "$THEME_DIR"
rsync -a --delete \
	--exclude '.git' \
	--exclude '.github' \
	--exclude '.sdk-*' \
	--exclude 'dist' \
	--exclude '*.zip' \
	"$ROOT_DIR/" "$THEME_DIR/"

echo "==> Installing feed packages"
./scripts/feeds install -a
./scripts/feeds install -p luci "$PKG_NAME"

make defconfig

echo "==> Building $PKG_NAME for OpenWrt $OPENWRT_VERSION target $TARGET/$SUBTARGET"
make "package/feeds/luci/$PKG_NAME/clean" V=s || true
make "package/feeds/luci/$PKG_NAME/compile" V=s

echo "==> Collecting packages"
find bin -type f \( -name "$PKG_NAME*.ipk" -o -name "$PKG_NAME*.apk" \) -print -exec cp -f {} "$DIST_DIR/" \;

shopt -s nullglob
ipks=("$DIST_DIR"/${PKG_NAME}*.ipk)
apks=("$DIST_DIR"/${PKG_NAME}*.apk)

if [ "${#ipks[@]}" -eq 0 ] && [ "${#apks[@]}" -eq 0 ]; then
	fail "Build completed but no UniWRT package was found in bin/."
fi

for f in "${ipks[@]}"; do
	cp -f "$f" "$DIST_DIR/${PKG_NAME}.ipk"
	cp -f "$f" "$DIST_DIR/${PKG_NAME}_all.ipk"
done

for f in "${apks[@]}"; do
	cp -f "$f" "$DIST_DIR/${PKG_NAME}.apk"
	cp -f "$f" "$DIST_DIR/${PKG_NAME}_all.apk"
done

ls -lh "$DIST_DIR"/${PKG_NAME}* 2>/dev/null || true
echo "==> Done. Output is in $DIST_DIR"
