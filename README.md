# UniWRT LuCI Theme

UniWRT is a clean, modern LuCI theme for OpenWrt **24.x** and **25.x**. It uses UniWRT branding with a premium network-controller layout, smooth motion, glass cards, and responsive dark/light modes.

> Project package name: `luci-theme-uniwrt`  
> Static theme path: `/luci-static/uniwrt`  
> Author footer: `Author: @Ox1d3x3 × UniWRT Theme v0.1.9`

## What it includes

- Universal OpenWrt 24.x `.ipk` package for `opkg` systems
- Universal OpenWrt 25.x `.apk` package for `apk` systems
- Architecture-independent package metadata for ARM, ARM64, MIPS, x86, x86_64, RISC-V, PowerPC and other OpenWrt targets
- Automatic GitHub Actions build
- Automatic moving GitHub **pre-release** named `pre-release`
- Build logs attached to every pre-release
- Modern glass-card UI, fixed left controller rail on desktop, rounded dashboard panels, smooth transitions, dark/light/auto mode toggle, mobile responsiveness
- Compatibility-first structure: UniWRT inherits LuCI Bootstrap ucode templates, then applies its own CSS/JS skin

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
│   ├── package.sh
│   ├── install.sh
│   ├── self-test.sh
│   └── uninstall.sh
└── ucode/template/themes/uniwrt/
    ├── footer.ut
    ├── header.ut
    └── sysauth.ut
```

## Quick install from pre-release

```sh
wget -O- https://raw.githubusercontent.com/ox1d3x3/uniwrt-luci/main/scripts/install.sh | sh
```

The installer detects `apk` or `opkg`, downloads the correct universal package, cleans up any failed previous APK world entry, installs UniWRT, activates it, and restarts LuCI.

## Manual install from pre-release

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
apk del luci-theme-uniwrt 2>/dev/null || true
sed -i '/^luci-theme-uniwrt/d' /etc/apk/world 2>/dev/null || true
wget https://github.com/ox1d3x3/uniwrt-luci/releases/download/pre-release/luci-theme-uniwrt.apk
apk add --allow-untrusted ./luci-theme-uniwrt.apk
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
/etc/init.d/uhttpd restart
```

Then hard refresh LuCI with `Ctrl + F5`.

## Build locally

```sh
sudo apt update
sudo apt install -y binutils coreutils gzip tar python3 nodejs

./scripts/self-test.sh
./scripts/package.sh
```

Packages will be copied into `dist/`.

## GitHub workflow behaviour

Every push to `main` or `master` builds:

- `luci-theme-uniwrt.ipk`
- `luci-theme-uniwrt.apk`
- `luci-theme-uniwrt_all.ipk`
- `luci-theme-uniwrt_all.apk`
- `package-*.log` files

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
