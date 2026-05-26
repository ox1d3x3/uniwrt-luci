#!/usr/bin/env bash
set -euo pipefail

rm -f .github/workflows/build-openwrt-packages.yml
rm -f .github/workflows/build-packages.yml
rm -f .github/workflows/openwrt-25-apk.yml
rm -f .github/workflows/apk-build.yml
rm -f .github/workflows/ipk-build.yml

if grep -RInE 'C[l]eanX|c[l]eanx|luci-theme-c[l]eanx|LEGACY_RELEASE_TOKEN' Makefile README.md CHANGELOG.md htdocs root ucode scripts .github/workflows 2>/dev/null; then
  echo "ERROR: old legacy naming still exists. Replace it with UniWRT / luci-theme-uniwrt." >&2
  exit 1
fi

if grep -q 'luci.mk' Makefile; then
  echo "ERROR: Makefile still uses luci.mk. This static theme must use package.mk only." >&2
  exit 1
fi

./scripts/self-test.sh

echo "UniWRT repo cleanup OK."
