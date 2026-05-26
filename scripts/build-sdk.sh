#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-luci-theme-cleanx}"
TARGET="${TARGET:-mediatek}"
SUBTARGET="${SUBTARGET:-mt7622}"
OPENWRT_VERSION="${OPENWRT_VERSION:-25.12.4}"

SDK_BASE_URL="${SDK_BASE_URL:-https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}/}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/.sdk-work"
OUT_DIR="${ROOT_DIR}/package-artifacts"
LOG_DIR="${ROOT_DIR}/build-logs"

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}" "${OUT_DIR}" "${LOG_DIR}"

cd "${WORK_DIR}"

echo "==> Detecting SDK from ${SDK_BASE_URL}"
SDK_FILE="$(curl -fsSL "${SDK_BASE_URL}" | grep -oE 'openwrt-sdk-[^"<>]+Linux-x86_64\.tar\.(xz|zst)' | head -n 1)"

if [ -z "${SDK_FILE}" ]; then
	echo "ERROR: could not detect OpenWrt SDK archive"
	exit 1
fi

echo "==> Downloading ${SDK_FILE}"
curl -fL --retry 5 --retry-delay 5 "${SDK_BASE_URL}${SDK_FILE}" -o "${SDK_FILE}"

case "${SDK_FILE}" in
	*.tar.zst) tar --zstd -xf "${SDK_FILE}" ;;
	*.tar.xz) tar -xf "${SDK_FILE}" ;;
	*) echo "ERROR: unsupported SDK archive: ${SDK_FILE}"; exit 1 ;;
esac

SDK_DIR="$(find "${WORK_DIR}" -maxdepth 1 -type d -name 'openwrt-sdk-*' | head -n 1)"
if [ -z "${SDK_DIR}" ]; then
	echo "ERROR: SDK directory not found"
	exit 1
fi

echo "==> Preparing feeds"
cd "${SDK_DIR}"
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> Copying CleanX into SDK"
rm -rf "${SDK_DIR}/package/custom/${PACKAGE_NAME}"
mkdir -p "${SDK_DIR}/package/custom/${PACKAGE_NAME}"

rsync -a --delete \
	--exclude ".git" \
	--exclude ".github" \
	--exclude ".sdk-work" \
	--exclude "package-artifacts" \
	--exclude "build-logs" \
	"${ROOT_DIR}/" "${SDK_DIR}/package/custom/${PACKAGE_NAME}/"

echo "==> Building ${PACKAGE_NAME}"
make defconfig
make "package/${PACKAGE_NAME}/clean" V=s || true
make "package/${PACKAGE_NAME}/compile" V=s -j"$(nproc)"

echo "==> Collecting outputs"
find "${SDK_DIR}/bin" -type f \
	\( -name "${PACKAGE_NAME}_*.ipk" -o -name "${PACKAGE_NAME}-*.apk" -o -name "${PACKAGE_NAME}_*.apk" \) \
	-print -exec cp -v {} "${OUT_DIR}/" \;

echo
echo "Done. Packages:"
find "${OUT_DIR}" -maxdepth 1 -type f -print | sort
