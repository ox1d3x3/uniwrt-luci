#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Local SDK builder. Example: OPENWRT_VERSION=25.12.4 ./scripts/build-sdk.sh

set -euo pipefail

OPENWRT_VERSION="${OPENWRT_VERSION:-24.10.2}"
TARGET="${TARGET:-x86}"
SUBTARGET="${SUBTARGET:-64}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.sdk-$OPENWRT_VERSION-$TARGET-$SUBTARGET}"
DIST_DIR="$ROOT_DIR/dist"
SDK_BASE="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}/"

mkdir -p "$WORK_DIR" "$DIST_DIR"
cd "$WORK_DIR"

printf '==> Discovering SDK at %s\n' "$SDK_BASE"
SDK_FILE="$(curl -fsSL "$SDK_BASE" | grep -oE "openwrt-sdk-[^\"]+Linux-x86_64\\.tar\\.(xz|zst)" | head -n1)"
[ -n "$SDK_FILE" ] || { echo "ERROR: SDK file not found at $SDK_BASE" >&2; exit 1; }

if [ ! -d sdk ]; then
	printf '==> Downloading %s\n' "$SDK_FILE"
	curl -fL "$SDK_BASE/$SDK_FILE" -o "$SDK_FILE"
	tar -xf "$SDK_FILE"
	mv openwrt-sdk-* sdk
fi

printf '==> Copying package source\n'
rm -rf sdk/package/luci-theme-uniwrt
mkdir -p sdk/package/luci-theme-uniwrt
rsync -a --delete \
	--exclude '.git' \
	--exclude '.sdk-*' \
	--exclude 'dist' \
	--exclude '*.zip' \
	"$ROOT_DIR/" sdk/package/luci-theme-uniwrt/

cd sdk
printf '==> Updating feeds\n'
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig

printf '==> Building luci-theme-uniwrt for OpenWrt %s\n' "$OPENWRT_VERSION"
make package/luci-theme-uniwrt/clean V=s || true
make package/luci-theme-uniwrt/compile V=s 2>&1 | tee "$DIST_DIR/build-${OPENWRT_VERSION}.log"

printf '==> Collecting packages\n'
find bin -type f \( -name 'luci-theme-uniwrt*.ipk' -o -name 'luci-theme-uniwrt*.apk' \) -print -exec cp -f {} "$DIST_DIR/" \;

# Friendly fixed names for release downloads.
for f in "$DIST_DIR"/luci-theme-uniwrt*.ipk; do [ -e "$f" ] && cp -f "$f" "$DIST_DIR/luci-theme-uniwrt.ipk"; done
for f in "$DIST_DIR"/luci-theme-uniwrt*.apk; do [ -e "$f" ] && cp -f "$f" "$DIST_DIR/luci-theme-uniwrt.apk"; done

printf '==> Done. Output is in %s\n' "$DIST_DIR"
