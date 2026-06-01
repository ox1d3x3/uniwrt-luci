# luci-theme-uniwrt

**UniWRT Portal** is a modern, mobile-ready OpenWrt LuCI theme built from the current UniWRT package architecture and visually reworked from the `My-theme2` portal inspection. It keeps the LuCI/Bootstrap rendering path for safety, then applies an original UniWRT shell: left controller rail, responsive mobile drawer, rounded appliance-style cards, clean tables/forms, light/dark modes, and a new original UniWRT logo.

No third-party product names, logos, icons, or proprietary assets are included in the theme package.

## Which package should I install?

The theme has **no compiled code**, so it is architecture-independent. Your router CPU/target does not matter. Pick by OpenWrt version because OpenWrt changed package managers across release lines.

| OpenWrt version | Package manager | Download/install |
|---:|:---:|:---|
| 23.05.x / older opkg builds | opkg | `.ipk` |
| 24.10.x | opkg | `.ipk` |
| 25.12.x and newer | apk | `.apk` |

Check your router version:

```sh
cat /etc/openwrt_release
# or
ubus call system board
```

Install:

```sh
# OpenWrt 23.05 / 24.10
opkg install ./luci-theme-uniwrt_*_all.ipk

# OpenWrt 25.12+
apk add --allow-untrusted ./luci-theme-uniwrt-*.apk
```

Then hard-refresh LuCI with `Ctrl+Shift+R`.

## Structure

```text
luci-theme-uniwrt/
├── Makefile
├── root/etc/uci-defaults/30_luci-theme-uniwrt
├── ucode/template/themes/uniwrt/
│   ├── header.ut
│   ├── footer.ut
│   └── sysauth.ut
├── luasrc/view/themes/uniwrt/
│   ├── header.htm
│   ├── footer.htm
│   └── sysauth.htm
└── htdocs/luci-static/uniwrt/
    ├── cascade.css
    ├── mobile.css
    ├── logo.svg
    ├── css/uniwrt.css
    └── js/uniwrt.js
```

The ucode templates cover current LuCI builds. The Lua templates are kept as a compatibility fallback for older LuCI render paths.

## How it works

UniWRT Portal deliberately keeps LuCI’s stock Bootstrap theme as the base renderer. That protects the real LuCI controls: Save & Apply, modals, dropdowns, CBI forms, dynamic tables, tabs, polling widgets, and installed/custom LuCI apps.

The theme then layers its own UI safely:

- `cascade.css` is the LuCI theme CSS entrypoint.
- `css/uniwrt.css` contains the full portal visual system and mobile rules.
- `js/uniwrt.js` reads LuCI’s real menu DOM and turns it into the UniWRT left rail. If LuCI’s menu is not exposed, it falls back to a small recovery menu instead of hiding navigation.
- `sysauth.ut` and `sysauth.htm` are present so the login page does not depend on missing theme fallback behaviour.
- `logo.svg` is a new original UniWRT mark.

## GitHub Actions build

`.github/workflows/build.yml` performs:

1. Static QA.
2. OpenWrt 23.05.6 SDK build for legacy `.ipk`.
3. OpenWrt 24.10.6 SDK build for current `.ipk`.
4. OpenWrt 25.12.4 SDK build for `.apk`.
5. A rolling `nightly` pre-release, or a tagged pre-release when pushing `v*` tags.

The package itself remains universal because `LUCI_PKGARCH:=all` is set in the Makefile.

## Local QA

```sh
./qa-static.sh
```

This checks required files, JavaScript syntax, the UCI defaults script, and workflow YAML parsing.

## Recovery

If LuCI looks broken after testing, recover from SSH:

```sh
uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci commit luci
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache
/etc/init.d/uhttpd restart
```

Or use the helper:

```sh
./uniwrt-apply.sh recover
```

## Customising

- Logo: replace `htdocs/luci-static/uniwrt/logo.svg`.
- Main colours/radius/sidebar width: edit CSS variables at the top of `css/uniwrt.css`.
- Brand text and shell behaviour: edit `js/uniwrt.js`.

## License

MIT. UniWRT is an independent OpenWrt LuCI theme project.


## v2.0.1

- Fixed GitHub Actions Static QA permission failure by running `qa-static.sh` through `bash` instead of relying on executable file mode.
