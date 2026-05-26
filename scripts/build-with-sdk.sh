#!/usr/bin/env bash
set -euo pipefail

OPENWRT_RELEASE="${1:-24.10.2}"
TARGET_PATH="${2:-x86/64}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="${WORKDIR:-$(mktemp -d)}"
DIST_DIR="$PROJECT_ROOT/dist/${OPENWRT_RELEASE}-${TARGET_PATH//\//-}"
BASE_URL="https://downloads.openwrt.org/releases/${OPENWRT_RELEASE}/targets/${TARGET_PATH}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need curl
need tar
need rsync
need grep
need sed
need sha256sum

mkdir -p "$WORKDIR" "$DIST_DIR"

echo "==> Discovering SDK from $BASE_URL/"
SDK_TARBALL="$(curl -fsSL "$BASE_URL/" | grep -oE 'openwrt-sdk-[^"<>]+Linux-x86_64\.tar\.zst' | head -n1 || true)"

if [ -z "$SDK_TARBALL" ]; then
  echo "Could not find OpenWrt SDK tarball at $BASE_URL/" >&2
  exit 1
fi

SDK_ARCHIVE="$WORKDIR/$SDK_TARBALL"
SDK_DIR="$WORKDIR/sdk"

echo "==> Downloading $SDK_TARBALL"
curl -fL --retry 4 --retry-delay 5 -o "$SDK_ARCHIVE" "$BASE_URL/$SDK_TARBALL"
rm -rf "$SDK_DIR"
mkdir -p "$SDK_DIR"
tar --zstd -xf "$SDK_ARCHIVE" -C "$SDK_DIR" --strip-components=1

echo "==> Installing LuCI feed metadata"
cd "$SDK_DIR"
./scripts/feeds update luci
./scripts/feeds install luci-base luci-theme-bootstrap

echo "==> Copying UniWRT package into SDK"
mkdir -p package/uniwrt/luci-theme-uniwrt
rsync -a --delete "$PROJECT_ROOT/" package/uniwrt/luci-theme-uniwrt/ \
  --exclude='.git' \
  --exclude='.github' \
  --exclude='dist' \
  --exclude='.DS_Store' \
  --exclude='*.zip'

echo "==> Building package"
make defconfig
make package/luci-theme-uniwrt/compile V=s

echo "==> Collecting packages"
find bin -type f \( -name 'luci-theme-uniwrt*.ipk' -o -name 'luci-theme-uniwrt*.apk' \) -print -exec cp -f {} "$DIST_DIR/" \;
(cd "$DIST_DIR" && sha256sum luci-theme-uniwrt* > SHA256SUMS)

echo "==> Done. Output: $DIST_DIR"
ls -lah "$DIST_DIR"
