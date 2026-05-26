#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -Eeuo pipefail

OPENWRT_VERSION="${OPENWRT_VERSION:-24.10.2}"
TARGET="${TARGET:-x86}"
SUBTARGET="${SUBTARGET:-64}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.sdk-$OPENWRT_VERSION-$TARGET-$SUBTARGET}"
DIST_DIR="$ROOT_DIR/dist"
SDK_BASE="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}/"
PKG_NAME="luci-theme-uniwrt"

mkdir -p "$WORK_DIR" "$DIST_DIR"
cd "$WORK_DIR"

printf '==> Discovering SDK at %s\n' "$SDK_BASE"
SDK_FILE="$(curl -fsSL "$SDK_BASE" | grep -oE 'openwrt-sdk-[^"<>]+Linux-x86_64\.tar\.(xz|zst)' | sort -V | tail -n1)"
[ -n "$SDK_FILE" ] || { echo "ERROR: SDK file not found at $SDK_BASE" >&2; exit 1; }

if [ ! -d sdk ]; then
	printf '==> Downloading %s\n' "$SDK_FILE"
	rm -f "$SDK_FILE"
	curl --fail --location --retry 5 --retry-delay 3 --retry-all-errors "$SDK_BASE/$SDK_FILE" -o "$SDK_FILE"

	printf '==> Extracting SDK\n'
	rm -f sdk-tar-list.txt
	# Do not pipe tar directly into head/sed. With pipefail enabled, head/sed can close
	# the pipe early and tar exits with "stdout: write error" even when the archive is fine.
	tar -tf "$SDK_FILE" > sdk-tar-list.txt
	SDK_TOPDIR="$(awk -F/ 'NF { print $1; exit }' sdk-tar-list.txt)"
	[ -n "$SDK_TOPDIR" ] || { echo "ERROR: Could not detect SDK root directory in $SDK_FILE" >&2; exit 1; }

	rm -rf "$SDK_TOPDIR" sdk
	tar -xf "$SDK_FILE"
	[ -d "$SDK_TOPDIR" ] || { echo "ERROR: Extracted SDK directory not found: $SDK_TOPDIR" >&2; exit 1; }
	mv "$SDK_TOPDIR" sdk
fi

printf '==> Copying package source\n'
rm -rf "sdk/package/$PKG_NAME"
mkdir -p "sdk/package/$PKG_NAME"
rsync -a --delete \
	--exclude '.git' \
	--exclude '.github' \
	--exclude '.sdk-*' \
	--exclude 'dist' \
	--exclude '*.zip' \
	"$ROOT_DIR/" "sdk/package/$PKG_NAME/"

cd sdk
printf '==> Updating feeds\n'
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig

printf '==> Building %s for OpenWrt %s\n' "$PKG_NAME" "$OPENWRT_VERSION"
make "package/$PKG_NAME/clean" V=s || true

set +e
make "package/$PKG_NAME/compile" V=s 2>&1 | tee "$DIST_DIR/build-${OPENWRT_VERSION}.log"
build_status=${PIPESTATUS[0]}
set -e

if [ "$build_status" -ne 0 ]; then
	echo "ERROR: OpenWrt SDK package build failed with exit code $build_status" >&2
	echo "Build log saved to: $DIST_DIR/build-${OPENWRT_VERSION}.log" >&2
	exit "$build_status"
fi

printf '==> Collecting packages\n'
find bin -type f \( -name "$PKG_NAME*.ipk" -o -name "$PKG_NAME*.apk" \) -print -exec cp -f {} "$DIST_DIR/" \;

for f in "$DIST_DIR"/${PKG_NAME}*.ipk; do [ -e "$f" ] && cp -f "$f" "$DIST_DIR/${PKG_NAME}.ipk"; done
for f in "$DIST_DIR"/${PKG_NAME}*.apk; do [ -e "$f" ] && cp -f "$f" "$DIST_DIR/${PKG_NAME}.apk"; done

if ! find "$DIST_DIR" -maxdepth 1 -type f \( -name "$PKG_NAME*.ipk" -o -name "$PKG_NAME*.apk" \) | grep -q .; then
	echo "ERROR: Build completed but no UniWRT package was found in bin/." >&2
	exit 1
fi

printf '==> Done. Output is in %s\n' "$DIST_DIR"
