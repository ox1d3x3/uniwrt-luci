<div align="center">

<img src="luci-theme-uniwrt/htdocs/luci-static/uniwrt/img/uniwrt-logo.svg" width="84" alt="UniWRT logo">

# UniWRT Portal

**A clean, controller-style theme for the OpenWrt LuCI web interface.**

Icon sidebar · live dashboard · light, dark and auto modes · one small package, zero external requests.

[![Build](https://github.com/ox1d3x3/uniwrt-luci/actions/workflows/build.yml/badge.svg)](https://github.com/ox1d3x3/uniwrt-luci/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/ox1d3x3/uniwrt-luci?color=006fff)](https://github.com/ox1d3x3/uniwrt-luci/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ox1d3x3/uniwrt-luci/total?color=006fff&label=downloads)](https://github.com/ox1d3x3/uniwrt-luci/releases)
[![Stars](https://img.shields.io/github/stars/ox1d3x3/uniwrt-luci?color=006fff)](https://github.com/ox1d3x3/uniwrt-luci/stargazers)
[![License](https://img.shields.io/github/license/ox1d3x3/uniwrt-luci?color=blue)](./LICENSE)
![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05%20%7C%2024.10%20%7C%2025.12-orange)

[Screenshots](#screenshots) · [Install](#installation) · [Configure](#configuration) · [FAQ](#faq) · [Build](#building-from-source) · [Releases](https://github.com/ox1d3x3/uniwrt-luci/releases/latest)

<br>

<img src="docs/screenshots/dashboard-dark.png" width="100%" alt="UniWRT dashboard in dark mode">

</div>

---

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="docs/screenshots/dashboard-light.png" alt="Dashboard in light mode"></td>
    <td width="50%"><img src="docs/screenshots/sidebar-collapsed.png" alt="Dashboard with the sidebar collapsed to an icon rail"></td>
  </tr>
  <tr>
    <td align="center"><sub><b>Light mode</b></sub></td>
    <td align="center"><sub><b>Collapsed icon rail</b></sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/screenshots/config-page.png" alt="Firewall port forwards page with an unsaved-changes badge"></td>
    <td width="50%"><img src="docs/screenshots/settings.png" alt="UniWRT theme settings page"></td>
  </tr>
  <tr>
    <td align="center"><sub><b>Standard LuCI pages, fully styled</b></sub></td>
    <td align="center"><sub><b>Theme settings</b></sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/screenshots/login.png" alt="Login page"></td>
    <td width="50%"><img src="docs/screenshots/mobile.png" alt="Dashboard and menu on a phone"></td>
  </tr>
  <tr>
    <td align="center"><sub><b>Sign-in page</b></sub></td>
    <td align="center"><sub><b>Phones and tablets</b></sub></td>
  </tr>
</table>

---

## Features

**Navigation**
- Sidebar that collapses to a slim icon rail — click any icon to jump straight to that section
- Sticky sub-navigation for the current section, and a menu that remembers its state between pages
- Off-canvas menu on phones and tablets

**Dashboard**
- System, CPU load, memory and uptime at a glance
- Network interfaces, wireless radios and connected clients
- Flash, RAM and swap usage
- Live WAN throughput with peak, last-24-hour and since-boot totals
- Quick-action tiles for the pages you use most

**Appearance**
- Light, dark, or automatic (follows your operating system), switchable from the header
- Separate accent colours for light and dark mode
- Adjustable base font size
- No flash of the wrong theme while a page loads

**Under the hood**
- Live status bar in the header: CPU, memory, throughput and uptime
- Every stock LuCI component styled — tables, tabs, dialogs, tooltips, badges, progress bars, validation states — with checkboxes rendered as switches
- Settings stored in UCI (`/etc/config/uniwrt`) and kept across upgrades
- Architecture-independent `.ipk` and `.apk` packages
- Fully self-contained: no web fonts, no CDNs, no telemetry

---

## Installation

### 1. Download

Get the package for your OpenWrt release from the [latest release](https://github.com/ox1d3x3/uniwrt-luci/releases/latest):

| OpenWrt | Package manager | File |
|---|---|---|
| **25.12** and newer | apk | `luci-theme-uniwrt-<version>-r1.apk` |
| **24.10** | opkg | `luci-theme-uniwrt_<version>-r1_all.ipk` |
| **23.05** | opkg | `luci-theme-uniwrt_<version>_all.ipk` |

Not sure which you have? Run `command -v apk` on the router — if it prints a path, use the `.apk`. Each release also includes a `SHA256SUMS` file for verifying the download.

### 2. Install

Copy the file to the router (for example to `/tmp`), then:

```sh
# OpenWrt 25.12 and newer
apk add --allow-untrusted /tmp/luci-theme-uniwrt-*.apk

# OpenWrt 23.05 / 24.10
opkg install /tmp/luci-theme-uniwrt_*_all.ipk
```

`--allow-untrusted` is needed because the package comes from GitHub rather than a signed OpenWrt feed.

Alternatively, put [`uniwrt-apply.sh`](./uniwrt-apply.sh) (also attached to every release) next to the package and run `sh uniwrt-apply.sh`. It detects the package manager, installs the package, activates the theme, clears the LuCI cache and restarts the web server.

### 3. Activate

A fresh install switches LuCI to UniWRT automatically. An upgrade never overrides a theme you have chosen since. To select it yourself, go to *System → System → Language and Style*, or run:

```sh
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
```

Then reload the page. After upgrading from an older version, do one hard refresh (<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd>, or <kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> on macOS).

### Uninstall

```sh
apk del luci-theme-uniwrt      # 25.12+
opkg remove luci-theme-uniwrt  # 23.05 / 24.10
```

If LuCI is still pointing at UniWRT afterwards, switch back to the stock theme with `uci set luci.main.mediaurlbase='/luci-static/bootstrap' && uci commit luci`.

---

## Configuration

Open *System → UniWRT Theme* in the web interface, or edit `/etc/config/uniwrt`:

| Option | Values | Default | Description |
|---|---|---|---|
| `mode` | `auto` · `light` · `dark` | `auto` | Default theme mode; `auto` follows the operating system |
| `accent` | `#RGB` or `#RRGGBB` | `#006fff` | Accent colour in light mode |
| `dark_accent` | `#RGB` or `#RRGGBB` | `#4797ff` | Accent colour in dark mode |
| `font_size` | `13` · `14` · `16` · `18` | `14` | Base font size in pixels |
| `status_bar` | `0` · `1` | `1` | Show the live status bar in the header |
| `overview` | `0` · `1` | `1` | Show the UniWRT dashboard in the menu |
| `rail_collapsed` | `0` · `1` | `0` | Start with the sidebar collapsed on desktop |

Invalid values are ignored and the default is used instead.

Example — dark mode with a green accent:

```sh
uci set uniwrt.global.mode='dark'
uci set uniwrt.global.dark_accent='#38cc65'
uci commit uniwrt
```

The theme toggle in the header and the sidebar collapse button are remembered per browser and take precedence over the defaults above.

---

## FAQ

<details>
<summary><b>Attended Sysupgrade fails with “Impossible package selection: missing (luci-theme-uniwrt)”</b></summary>
<br>

Attended Sysupgrade asks the OpenWrt build servers for a firmware image that contains every package currently installed. Those servers only know packages from the official feeds, so any manually installed package — including this theme — makes the request fail.

Leave the theme out of the request and reinstall it afterwards:

1. Enable advanced mode:
   ```sh
   uci set attendedsysupgrade.client.advanced_mode='1'
   uci commit attendedsysupgrade
   ```
2. Reload the Attended Sysupgrade page, remove `luci-theme-uniwrt` from the **Packages** list, then build and flash with *Keep settings* enabled.
3. After the reboot, reinstall the theme. Your settings are preserved.

On the command line, `owut upgrade --remove luci-theme-uniwrt` does the same.
</details>

<details>
<summary><b>LuCI is unstyled after a firmware upgrade</b></summary>
<br>

A sysupgrade replaces the firmware image, which removes manually installed packages but keeps `/etc/config`. LuCI is still set to UniWRT, which is no longer there. Reinstall the package and everything returns as it was — or switch to the stock theme in the meantime:

```sh
uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci commit luci
```
</details>

<details>
<summary><b>The page looks broken or half-updated after upgrading the theme</b></summary>
<br>

The browser is using a cached stylesheet from the previous version. Do one hard refresh (<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> / <kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd>). Assets are versioned per release, so this should only be needed once.
</details>

<details>
<summary><b>A menu entry doesn’t appear or disappear after changing a setting</b></summary>
<br>

LuCI caches its menu. Clear the cache and reload:

```sh
rm -f /tmp/luci-indexcache* /tmp/luci-modulecache/*
```
</details>

<details>
<summary><b>Does the theme make any external requests?</b></summary>
<br>

No. All assets are served from the router, and every figure on the dashboard comes from your device over `ubus`. There are no web fonts, CDNs, analytics or update checks.
</details>

---

## Compatibility

| | |
|---|---|
| **OpenWrt** | 23.05, 24.10, 25.12 and newer |
| **Packages** | `.ipk` (opkg) and `.apk` (apk), architecture-independent |
| **Requirements** | `luci-base` with the ucode template engine (default on all supported releases) |
| **Browsers** | Current Chrome, Edge, Firefox and Safari, desktop and mobile |

Third-party LuCI apps generally work without changes, since UniWRT styles the standard LuCI components they are built from. If one doesn’t render correctly, please [open an issue](https://github.com/ox1d3x3/uniwrt-luci/issues).

---

## Building from source

Every push to `main` runs a static QA gate and builds packages for all supported releases with the OpenWrt SDK, published as a rolling [`nightly`](https://github.com/ox1d3x3/uniwrt-luci/releases/tag/nightly) pre-release. Pushing a `v*` tag publishes a versioned release.

To build locally inside an OpenWrt SDK:

```sh
echo "src-link uniwrt /path/to/uniwrt-luci" >> feeds.conf.default
./scripts/feeds update uniwrt
./scripts/feeds install -a -p uniwrt

make menuconfig                              # LuCI → 4. Themes → luci-theme-uniwrt
make package/luci-theme-uniwrt/compile V=s
```

The package is written to `bin/packages/<arch>/uniwrt/`.

<details>
<summary><b>Repository layout</b></summary>
<br>

```
luci-theme-uniwrt/
├── Makefile                         package definition (version read from ucode/.../version)
├── htdocs/luci-static/
│   ├── uniwrt/css/                  cascade.css (light + layout), dark.css (inlined at runtime)
│   ├── uniwrt/img/                  logo
│   └── resources/                   menu and status-bar renderers, dashboard and settings views
├── ucode/template/themes/uniwrt/    header.ut, footer.ut, sysauth.ut, version
└── root/                            default config, uci-defaults, menu and ACL entries
qa-static.sh                         static checks run in CI
uniwrt-apply.sh                      on-router install helper
```
</details>

---

## Contributing

Bug reports and pull requests are welcome. For rendering issues, please include:

- the page you were on (for example *Network → Firewall → Port Forwards*)
- your OpenWrt version and router model
- the browser you used and a screenshot

Run the static checks before opening a pull request:

```sh
./qa-static.sh
```

## Security

Please don’t report security problems in public issues. Use [private vulnerability reporting](https://github.com/ox1d3x3/uniwrt-luci/security/advisories/new) instead — see [SECURITY.md](./SECURITY.md).

## Changelog

Release notes for every version are on the [Releases](https://github.com/ox1d3x3/uniwrt-luci/releases) page.

---

<div align="center">

Made by [ox1d3x3](https://github.com/ox1d3x3) · Licensed under [Apache 2.0](./LICENSE)

UniWRT is an independent project and is not affiliated with or endorsed by OpenWrt or any network equipment vendor.

If UniWRT is useful to you, a ⭐ helps others find it.

</div>
