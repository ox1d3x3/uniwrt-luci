# Changelog

## 0.2.8

- Renamed the project cleanly to UniWRT everywhere.
- Removed all legacy project/release/workflow naming.
- Removed duplicate package build workflow entry so only one package workflow runs.
- Fixed GitHub pre-release publishing to use the built-in `${{ github.token }}` with `contents: write` only, no custom PAT secret.
- Fixed static theme packaging to use `package.mk` only, never `luci.mk`.
- Removed `DEPENDS:=+luci-base` and feed installation from the SDK build path to stop LuCI/ucode/rpcd/libnl/lua dependency builds from breaking APK/IPK packaging.
- Builds exactly the required package formats: OpenWrt 24.10.6 IPK and OpenWrt 25.12.4 APK for mediatek/mt7622.
- Publishes a moving GitHub pre-release named `pre-release` with clean package assets.

## 0.2.0

- Switched GitHub Actions back to OpenWrt SDK builds for mediatek/mt7622 only.
- Builds IPK for OpenWrt 24.10.6 and APK for OpenWrt 25.12.4.
- Copies the package into `package/custom/luci-theme-uniwrt` and builds the matching SDK target.
- Removed broad all-architecture and manual package generation from the CI path.
