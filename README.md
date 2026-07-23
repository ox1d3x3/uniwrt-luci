<div align="center">

<img src="luci-theme-uniwrt/htdocs/luci-static/uniwrt/img/uniwrt-logo.svg" width="80" alt="UniWRT">

## If UniWRT is useful to you, a ⭐ helps others find it.

# UniWRT Portal

**A modern, controller-style theme for OpenWrt's LuCI web interface.**

Collapsible icon navigation, a live dashboard, and light / dark / auto theming — in a single package with no external dependencies.

[![Build](https://github.com/ox1d3x3/uniwrt-luci/actions/workflows/build.yml/badge.svg)](https://github.com/ox1d3x3/uniwrt-luci/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/ox1d3x3/uniwrt-luci?include_prereleases&color=006fff)](https://github.com/ox1d3x3/uniwrt-luci/releases)
[![Downloads](https://img.shields.io/github/downloads/ox1d3x3/uniwrt-luci/total?color=006fff&label=downloads)](https://github.com/ox1d3x3/uniwrt-luci/releases)
[![Stars](https://img.shields.io/github/stars/ox1d3x3/uniwrt-luci?color=006fff)](https://github.com/ox1d3x3/uniwrt-luci/stargazers)
[![License](https://img.shields.io/github/license/ox1d3x3/uniwrt-luci?color=blue)](./LICENSE)
![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05%20%7C%2024.10%20%7C%2025.x-orange)

[Install](#installation) · [Configure](#configuration) · [FAQ](#faq--troubleshooting) · [Releases](https://github.com/ox1d3x3/uniwrt-luci/releases)

</div>

---

## Preview

<p align="center">
  <img src="docs/screenshots/overview-light.png" width="100%" alt="UniWRT dashboard, light mode">
</p>

<table>
  <tr>
    <td width="50%"><img src="docs/screenshots/overview-dark.png" alt="Dark mode"></td>
    <td width="50%"><img src="docs/screenshots/in-page-tabs.png" alt="Configuration pages"></td>
  </tr>
  <tr>
    <td align="center"><sub><b>Dark mode</b></sub></td>
    <td align="center"><sub><b>Configuration pages</b></sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/screenshots/modal.png" alt="Dialogs"></td>
    <td width="50%"><img src="docs/screenshots/components.png" alt="Form controls"></td>
  </tr>
  <tr>
    <td align="center"><sub><b>Dialogs &amp; command output</b></sub></td>
    <td align="center"><sub><b>Toggles, validation &amp; badges</b></sub></td>
  </tr>
</table>

<details>
<summary><b>Running on hardware</b> — Xiaomi Redmi Router AX6S, OpenWrt 25.12</summary>
<br>
<img src="docs/screenshots/device-overview.png" width="100%" alt="UniWRT on a router">
</details>

---

## Features

**Navigation**
- Collapsible sidebar — collapse it to a slim icon rail and click any icon to jump straight to that section
- Sticky sub-navigation and an accordion menu that keeps your place
- Works on phones and tablets with an off-canvas menu

**Live dashboard**
- System, CPU load, memory and uptime at a glance
- Network interfaces, wireless radios and connected clients
- Storage usage for flash, RAM and swap
- Live WAN throughput in Mbps, with peak, last-24-hour and since-restart totals
- Quick Actions tiles linking to the pages you use most

**Appearance**
- Light, dark, or automatic (follows your operating system)
- Configurable accent colour, independently for light and dark
- Adjustable base font size
- No flash of the wrong theme on page load

**Everything else**
- Live status bar in the header — CPU, memory, throughput and uptime
- Checkboxes rendered as on/off switches; native form behaviour preserved
- Fully styled LuCI components: tabs, dialogs, tooltips, progress bars, interface and firewall badges, validation states
- Settings stored in UCI and preserved across package upgrades
- Ships as `.ipk` and `.apk` — no webfonts, no CDNs, no telemetry

---

## Installation

Download the package for your OpenWrt release from the [Releases](https://github.com/ox1d3x3/uniwrt-luci/releases) page and copy it to your router.

**OpenWrt 25.x** (apk)

```sh
apk add --allow-untrusted ./luci-theme-uniwrt-2.0.34-r1.apk
```

**OpenWrt 24.10 / 23.05** (opkg)

```sh
opkg install ./luci-theme-uniwrt_2.0.34-1_all.ipk
```

`--allow-untrusted` is required because the package is downloaded manually rather than from a signed feed.

On a fresh install UniWRT activates itself. On an upgrade it will not override a theme you have since chosen. To switch manually, select **UniWRT** under *System → System → Language and Style*, or run:

```sh
uci set luci.main.mediaurlbase=/luci-static/uniwrt
uci commit luci
/etc/init.d/uhttpd restart
```

---

## Configuration

Settings live under *System → UniWRT Theme* in the web interface, or in `/etc/config/uniwrt`:

| Option | Values | Default | Description |
|---|---|---|---|
| `mode` | `auto` `light` `dark` | `auto` | Theme mode; `auto` follows your operating system |
| `accent` | hex colour | `#006fff` | Accent colour in light mode |
| `dark_accent` | hex colour | `#4797ff` | Accent colour in dark mode |
| `status_bar` | `0` `1` | `1` | Live CPU / memory / throughput / uptime bar in the header |
| `overview` | `0` `1` | `1` | Show the UniWRT dashboard menu entry |
| `font_size` | px | `14` | Base font size |
| `rail_collapsed` | `0` `1` | `0` | Start with the sidebar collapsed on desktop |

Example — dark theme with a green accent:

```sh
uci set uniwrt.global.mode='dark'
uci set uniwrt.global.dark_accent='#38cc65'
uci commit uniwrt
```

Your settings are registered as a conffile, so they survive package upgrades.

---

## FAQ & Troubleshooting

<details>
<summary><b>Firmware upgrade fails with "Impossible package selection: missing (luci-theme-uniwrt)"</b></summary>
<br>

Attended Sysupgrade asks OpenWrt's build servers to compile a firmware containing every package installed on your router. Those servers only know packages from the official feeds, and UniWRT is installed manually — so the build fails. This affects **any** manually installed package.

To upgrade, exclude the theme from the request and reinstall it afterwards:

```sh
uci set attendedsysupgrade.client.advanced_mode='1'
uci commit attendedsysupgrade
```

Reload the Attended Sysupgrade page, remove `luci-theme-uniwrt` from the now-editable **Packages** list, then build and flash with *Keep settings* enabled. After the reboot, reinstall the theme — your settings are preserved, so it returns exactly as configured.

From the command line, `owut upgrade --remove luci-theme-uniwrt` does the same thing.
</details>

<details>
<summary><b>LuCI looks unstyled after a firmware upgrade</b></summary>
<br>

A firmware upgrade replaces the whole image, so manually installed packages — including this theme — are removed, while your settings in `/etc/config` are kept. LuCI is still pointing at the missing theme.

Reinstall the package and everything returns as configured. To fall back to the stock theme in the meantime:

```sh
uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci commit luci
```
</details>

<details>
<summary><b>The interface looks broken or half-updated after upgrading the theme</b></summary>
<br>

Your browser is serving a cached stylesheet. Reload once with <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> (<kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> on macOS). Static assets are versioned per release, so this is only needed when upgrading from an older version.
</details>

<details>
<summary><b>A menu entry doesn't appear or disappear after changing a setting</b></summary>
<br>

LuCI caches its menu index. If an entry looks stale, clear the cache and reload:

```sh
rm -f /tmp/luci-indexcache*
```
</details>

<details>
<summary><b>Which package do I need — .ipk or .apk?</b></summary>
<br>

OpenWrt 25.x uses **apk** (`.apk`); 23.05 and 24.10 use **opkg** (`.ipk`). They are not interchangeable. If you are unsure, run `apk --version` — if the command exists, use the `.apk`.
</details>

<details>
<summary><b>Does it need internet access, or send any data?</b></summary>
<br>

No. Everything is served from the router: no webfonts, no CDNs, no external requests and no telemetry. All figures come from your device over `ubus`.
</details>

---

## Compatibility

| | |
|---|---|
| **OpenWrt** | 23.05, 24.10, 25.x |
| **Package format** | `.ipk` (opkg) and `.apk` (apk) |
| **Architecture** | Any — the package is architecture-independent |
| **Browsers** | Current Firefox, Chrome, Edge and Safari |

Requires LuCI with the ucode template engine (the default on all supported releases).

---

## Building from source

The repository ships a GitHub Actions workflow that runs a static QA gate and builds every supported release. Pushing a `v*` tag publishes a release; pushes to the main branch publish a rolling `nightly`.

To build locally with the OpenWrt SDK:

```sh
# inside an extracted SDK for your target and branch
echo "src-link uniwrt /path/to/uniwrt-luci" >> feeds.conf.default
./scripts/feeds update uniwrt
./scripts/feeds install -a -p uniwrt

make menuconfig      # LuCI → Themes → luci-theme-uniwrt  (M)
make package/luci-theme-uniwrt/compile V=s
```

The finished package appears under `bin/packages/<arch>/uniwrt/`.

---

## Contributing

Issues and pull requests are welcome. When reporting a rendering problem, please include:

- the page you were on (for example *Network → Firewall → Port Forwards*)
- your OpenWrt version and router model
- a screenshot, if the issue is visual

Before opening a pull request, run the static checks:

```sh
./qa-static.sh
```

---

## Changelog

Release notes for every version are published on the [Releases](https://github.com/ox1d3x3/uniwrt-luci/releases) page.

---

<div align="center">

Built by [ox1d3x3](https://github.com/ox1d3x3) · Licensed under [Apache 2.0](./LICENSE)

</div>
