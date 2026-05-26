# UniWRT LuCI Theme

UniWRT is a clean, modern LuCI theme for OpenWrt **24.x** and **25.x**. It uses UniWRT branding with a premium network-controller layout, smooth motion, glass cards, and responsive dark/light modes.

> Project package name: `luci-theme-uniwrt`  
> Static theme path: `/luci-static/uniwrt`  
> Author footer: `Author: @Ox1d3x3 × UniWRT Theme v0.1.4`

## What it includes

- OpenWrt 24.x `.ipk` build path through the OpenWrt SDK
- OpenWrt 25.x `.apk` build path through the OpenWrt SDK
- Automatic GitHub Actions build
- Automatic moving GitHub **pre-release** named `pre-release`
- Build logs attached to every pre-release
- Modern glass-card UI, fixed left controller rail on desktop, rounded dashboard panels, smooth transitions, dark/light/auto mode toggle, mobile responsiveness
- Compatibility-first structure: UniWRT inherits LuCI Bootstrap ucode templates, then applies its own CSS/JS skin

## Why this structure

OpenWrt 24.10 and older systems use `opkg`/`.ipk`, while OpenWrt 25.12 and newer use `apk`/`.apk`. The workflow builds both using the official OpenWrt SDK so the packages are valid router packages, not fake renamed archives.

## Repository structure

```text
luci-theme-uniwrt/
├── .github/workflows/build-prerelease.yml
├── Makefile
├── VERSION
├── htdocs/luci-static/uniwrt/
│   ├── cascade.css
│   ├── uniwrt.js
│   ├── dark.css
│   ├── favicon.svg
│   ├── light.css
│   ├── logo.svg
│   └── mobile.css
├── root/etc/uci-defaults/30_luci-theme-uniwrt
├── scripts/
│   ├── build-sdk.sh
│   ├── install.sh
│   └── uninstall.sh
└── ucode/template/themes/uniwrt/
    ├── footer.ut
    ├── header.ut
    └── sysauth.ut
```

## Install from pre-release

### OpenWrt 24.x / opkg

```sh
cd /tmp
wget https://github.com/ox1d3x3/uniwrt-luci/releases/download/pre-release/luci-theme-uniwrt.ipk
opkg install luci-theme-uniwrt.ipk
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
/etc/init.d/uhttpd restart
```

### OpenWrt 25.x / apk

```sh
cd /tmp
wget https://github.com/ox1d3x3/uniwrt-luci/releases/download/pre-release/luci-theme-uniwrt.apk
apk add --allow-untrusted luci-theme-uniwrt.apk
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
/etc/init.d/uhttpd restart
```

Then hard refresh LuCI with `Ctrl + F5`.

## Quick install script

```sh
wget -O- https://raw.githubusercontent.com/ox1d3x3/uniwrt-luci/main/scripts/install.sh | sh
```

By default, this downloads from the moving `pre-release`. You can override it:

```sh
REPO=ox1d3x3/uniwrt-luci TAG=pre-release sh scripts/install.sh
```

## Build locally with OpenWrt SDK

```sh
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib gettext git \
  libncurses-dev libssl-dev python3 python3-setuptools rsync unzip zlib1g-dev \
  file wget curl tar xz-utils zstd

# Build IPK for 24.10.2
OPENWRT_VERSION=24.10.2 ./scripts/build-sdk.sh

# Build APK for 25.12.4
OPENWRT_VERSION=25.12.4 ./scripts/build-sdk.sh
```

Packages will be copied into `dist/`.

## GitHub workflow behaviour

Every push to `main` or `master` builds:

- `luci-theme-uniwrt.ipk` using OpenWrt `24.10.2`
- `luci-theme-uniwrt.apk` using OpenWrt `25.12.4`
- `build-*.log` files

Then it deletes and recreates a moving GitHub pre-release called `pre-release`. This gives you one clean testing release every time. After testing, create your stable release manually from the package files you trust.

## Revert to default LuCI theme

```sh
uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci commit luci
/etc/init.d/uhttpd restart
```

Or fully remove:

```sh
wget -O- https://raw.githubusercontent.com/ox1d3x3/uniwrt-luci/main/scripts/uninstall.sh | sh
```

## Design notes

See [`docs/DESIGN.md`](docs/DESIGN.md) for the UI direction.

## Licence

Apache-2.0
