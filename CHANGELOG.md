# Changelog

## v0.2.3

### Fixed

- Provides a proper full project ZIP, not only a patch bundle.
- Uses `luci-theme-cleanx` as the package name.
- Builds the package from `package/custom/luci-theme-cleanx`.
- Removes all LuCI runtime dependencies from the theme package.
- Avoids `luci.mk`, `LUCI_DEPENDS`, and `DEPENDS:=+luci-base`.
- Avoids `scripts/feeds update -a` and `scripts/feeds install -a` in the GitHub build.
- Builds OpenWrt 24.10.6 `.ipk`.
- Builds OpenWrt 25.12.4 `.apk`.
- Adds defensive CSS/JS wrappers for wide tables, graphs, routing, processes, software, startup, and interface pages.

### Notes

For OpenWrt 25.x, install only the `.apk` package.
