# Changelog

## 1.7.0

- Reworked LuCI integration safety around Bootstrap headers/footers.
- Added required `cascade.css` / `mobile.css` static entrypoints.
- Fixed ucode include paths for 24.x/25.x LuCI.
- Replaced hard-coded navigation-first behaviour with real LuCI menu parsing.
- Added recovery navigation only if LuCI exposes no menu.
- Fixed checkbox/toggle styling so inputs remain clickable.
- Added post-remove Bootstrap recovery.
- Updated GitHub Actions matrix to OpenWrt 24.10.7 `.ipk` and 25.12.4 `.apk`.
