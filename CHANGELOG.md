# Changelog


## v0.2.5

### Fixed

- Removed duplicate workflow files from `.github/workflows`.
- Kept only `build-prerelease.yml` as the single source of truth for IPK, APK and GitHub pre-release publishing.
- Removed the old `build-packages.yml` workflow that still contained the stale package-only validator.
- Removed the manual placeholder workflow to avoid confusion in the GitHub Actions UI.
- Fixed the README OpenWrt 24.10 install command typo.

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
