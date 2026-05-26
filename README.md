# UniWRT LuCI Theme

UniWRT is a clean, animated, controller-style LuCI theme for OpenWrt 24.x and 25.x. It is designed to feel like a polished network controller UI while using original OpenWrt/UniWRT branding and assets.

## What this is

- Package name: `luci-theme-uniwrt`
- Theme name in LuCI: `UniWRT`
- OpenWrt 24.10 and older: builds `.ipk`
- OpenWrt 25.12 and newer: builds `.apk`
- Template base: LuCI Bootstrap wrapper for safer compatibility
- Styling: modern glass cards, rounded tables, responsive layout, dark/light/auto theme toggle, subtle live animations

## What this is not

This is not a UniFi OS redistribution and does not include UniFi logos, names, icons, screenshots, fonts, or proprietary UI assets. The design direction is inspired by modern network-controller dashboards, but the implementation and branding are original.

## Repository layout

```text
.
├── Makefile
├── htdocs/luci-static/uniwrt/
│   ├── cascade.css
│   ├── favicon.svg
│   ├── assets/
│   │   ├── logo.svg
│   │   └── noise.svg
│   └── js/uniwrt.js
├── root/etc/uci-defaults/30_luci-theme-uniwrt
├── ucode/template/themes/uniwrt/
│   ├── header.ut
│   ├── footer.ut
│   └── sysauth.ut
├── scripts/build-with-sdk.sh
└── .github/workflows/build-openwrt-packages.yml
```

## Build with GitHub Actions

Push this project to GitHub, then run **Actions → Build OpenWrt packages → Run workflow**.

The workflow builds both:

- `luci-theme-uniwrt_..._all.ipk` for OpenWrt 24.10.x
- `luci-theme-uniwrt-...apk` for OpenWrt 25.12.x

When you push a tag such as `v0.1.0`, the workflow also publishes the packages to a GitHub Release.

## Install on OpenWrt 24.x

```sh
cd /tmp
opkg install ./luci-theme-uniwrt_0.1.0-r1_all.ipk
/etc/init.d/uhttpd restart
```

## Install on OpenWrt 25.x

```sh
cd /tmp
apk add --allow-untrusted ./luci-theme-uniwrt-0.1.0-r1.apk
/etc/init.d/uhttpd restart
```

## Manually select the theme

```sh
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
/etc/init.d/uhttpd restart
```

Or in LuCI: **System → System → Language and Style → Design → UniWRT**.

## Recovery if a theme breaks LuCI

SSH into the router and switch back to Bootstrap:

```sh
uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci commit luci
/etc/init.d/uhttpd restart
```

## Local SDK build

```sh
./scripts/build-with-sdk.sh 24.10.2 x86/64
./scripts/build-with-sdk.sh 25.12.1 x86/64
```

The output packages are copied into `dist/`.

## Licence

Apache-2.0.
