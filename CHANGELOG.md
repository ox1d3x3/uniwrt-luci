# Changelog

## v0.2.4

### Fixed

- Replaced the broken custom package-only workflow with the proven CleanX pre-release workflow style.
- Removed the bad validation logic that rejected `luci.mk`.
- Changed the package Makefile to use the correct LuCI helper from the SDK feeds:

  ```make
  include $(TOPDIR)/feeds/luci/luci.mk
  ```

- Added feed preparation before package build:

  ```sh
  ./scripts/feeds update -a
  ./scripts/feeds install -a
  ```

- Builds:
  - OpenWrt 24.10.6 `.ipk`
  - OpenWrt 25.12.4 `.apk`
  - OpenWrt snapshot `.apk`

- Publishes package assets and build logs to a GitHub pre-release.

## v0.2.3

### Fixed

- Initial full project scaffold.
- This version had a broken workflow validator and should not be used.
