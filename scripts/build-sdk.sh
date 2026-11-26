#!/usr/bin/env bash
# Run inside the release-specific OpenWrt SDK image.
set -euo pipefail
if [ -f setup.sh ]; then bash setup.sh; fi
sed -e 's,https://git.openwrt.org/feed/,https://github.com/openwrt/,' \
    -e 's,https://git.openwrt.org/project/,https://github.com/openwrt/,' \
    -e 's,https://git.openwrt.org/openwrt/,https://github.com/openwrt/,' \
    feeds.conf.default > feeds.conf
# Feed indexing and package preparation may write into the feed directory.
feed_dir="$(mktemp -d)"
cp -R "/feed/$PACKAGE" "$feed_dir/"
echo "src-link $FEEDNAME $feed_dir" >> feeds.conf
./scripts/feeds update -a
./scripts/feeds install -p "$FEEDNAME" "$PACKAGE"
langpkg=luci-i18n-uniwrt-zh-cn
printf 'CONFIG_PACKAGE_%s=m\nCONFIG_LUCI_LANG_zh_Hans=y\nCONFIG_PACKAGE_%s=m\n' "$PACKAGE" "$langpkg" >> .config
make defconfig
for pkg in "$PACKAGE" "$langpkg"; do
    grep -Eq "^CONFIG_PACKAGE_${pkg}=[ym]$" .config
done
make -j"$(nproc)" "package/$PACKAGE/compile" V=s
for pkg in "$PACKAGE" "$langpkg"; do
    mapfile -t files < <(find bin/packages -type f -name "${pkg}[-_]*.$EXT")
    if [ "${#files[@]}" -ne 1 ]; then
        echo "Expected one $pkg .$EXT package, found ${#files[@]}" >&2
        exit 1
    fi
    asset=${files[0]##*/}
    if [[ "$pkg" == "$langpkg" && "$EXT" == ipk ]]; then
        # The two SDKs can assign the same PO version. Keep both release assets.
        asset="${asset%_all.ipk}_openwrt-${SDK_RELEASE}_all.ipk"
    fi
    cp "${files[0]}" "/out/$asset"
done
