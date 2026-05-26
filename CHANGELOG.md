# Changelog

## 0.2.0

- Switched GitHub Actions back to OpenWrt SDK builds for mediatek/mt7622 only.
- Builds IPK for OpenWrt 24.10.6 and APK for OpenWrt 25.12.4.
- Copies the package into `package/custom/luci-theme-uniwrt` and builds the matching SDK target.
- Removed broad all-architecture and manual package generation from the CI path.
- Simplified package dependencies for LuCI base.

