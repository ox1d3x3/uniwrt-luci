<div align="center">

<img src="luci-theme-uniwrt/htdocs/luci-static/uniwrt/img/uniwrt-logo.svg" width="76" alt="UniWRT logo">

# UniWRT Portal

**A modern, standalone LuCI theme for OpenWrt — a clean controller-style dashboard with a collapsible navigation rail, live status widgets, and light / dark / auto theming.**

[![Build](https://github.com/ox1d3x3/uniwrt-luci/actions/workflows/build.yml/badge.svg)](https://github.com/ox1d3x3/uniwrt-luci/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/ox1d3x3/uniwrt-luci?include_prereleases&color=006fff)](https://github.com/ox1d3x3/uniwrt-luci/releases)
[![License](https://img.shields.io/github/license/ox1d3x3/uniwrt-luci?color=blue)](./LICENSE)
![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05%20%7C%2024.10%20%7C%2025.x-orange)
![Packages](https://img.shields.io/badge/packages-.ipk%20%2B%20.apk-success)

</div>

---

## Preview

<p align="center">
  <img src="docs/screenshots/overview-light.png" width="100%" alt="UniWRT overview dashboard (light)">
</p>

<table>
  <tr>
    <td width="50%"><img src="docs/screenshots/overview-dark.png" alt="Dark mode"></td>
    <td width="50%"><img src="docs/screenshots/in-page-tabs.png" alt="In-page form tabs"></td>
  </tr>
  <tr>
    <td align="center"><sub><b>Dark mode</b></sub></td>
    <td align="center"><sub><b>In-page form tabs (System &rarr; Logging / Time Sync &hellip;)</b></sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/screenshots/modal.png" alt="Centred modal output"></td>
    <td width="50%"><img src="docs/screenshots/components.png" alt="Toggles, validation and badges"></td>
  </tr>
  <tr>
    <td align="center"><sub><b>Centred modal output (package / firmware)</b></sub></td>
    <td align="center"><sub><b>Slide toggles, validation, progress, badges</b></sub></td>
  </tr>
</table>

<details>
<summary><b>Running on a real device</b> (Xiaomi Redmi Router AX6S &middot; OpenWrt 25.12.4)</summary>

<br>

<img src="docs/screenshots/device-overview.png" width="100%" alt="UniWRT running on a real router">

</details>

---

## Features

* **Standalone full shell** — its own HTML shell (head, navigation rail, top bar, login) on the ucode template engine, not a restyle over the bootstrap theme. This removes the entire class of cascade-conflict bugs.
* **Collapsible navigation rail** — client-side menu with pin / collapse, sliding indicators, and sticky sub-navigation tabs, built from LuCI's live menu tree.
* **Live overview dashboard** — System, CPU load, Memory, Uptime, Network Interfaces, Wireless and Clients tiles, refreshed every 5 seconds over `ubus`.
* **Live header status bar** — at-a-glance CPU / Memory / Throughput (in Mbps) / Uptime chips with status colours.
* **Light / Dark / Auto** — no-flash theme resolution with independent, configurable accent colours per mode.
* **Slide-toggle switches** — checkboxes render as iOS-style on/off switches; native form behaviour is preserved underneath.
* **Native-feel components** — styled tabs, modals, tooltips, progress bars, interface / zone badges, validation states and diagnostics layouts.
* **Config-driven** — every option lives in `/etc/config/uniwrt` and is editable from the GUI or via UCI; settings persist across upgrades.
* **Dual packaging** — ships as `.ipk` (opkg, 23.05 / 24.10) and `.apk` (Alpine apk, 25.x) from one CI matrix.

---

## Installation

Download the artifact that matches your OpenWrt release from the [Releases](https://github.com/ox1d3x3/uniwrt-luci/releases) page.

### OpenWrt 25.x (apk)

```sh
# copy the .apk to the router first, then:
apk add --allow-untrusted ./luci-theme-uniwrt-2.0.20-r1.apk
```

`--allow-untrusted` is required for a manually-downloaded, unsigned package. If you publish a signed feed, install its public key into `/etc/apk/keys/` instead and drop the flag.

### OpenWrt 24.10 / 23.05 (opkg)

```sh
# copy the .ipk to the router first, then:
opkg install ./luci-theme-uniwrt_2.0.20-1_all.ipk
```

### Activating the theme

On a **fresh install** UniWRT sets itself as the active theme automatically. On an **upgrade** it will *not* override a theme you have since chosen — it only keeps itself in the selectable list. To switch manually at any time, pick **UniWRT** under *System &rarr; System &rarr; Language and Style*, or from the CLI:

```sh
uci set luci.main.mediaurlbase=/luci-static/uniwrt
uci commit luci
/etc/init.d/uhttpd restart
```

---

## Configuration

All settings are stored in `/etc/config/uniwrt` and are editable from the GUI (*System &rarr; UniWRT Theme*) or via UCI.

```
config global 'global'
    option mode           'auto'      # auto | light | dark
    option accent         '#006fff'   # accent colour (light mode)
    option dark_accent    '#4797ff'   # accent colour (dark mode)
    option status_bar     '1'         # 1 = show live header status bar
    option overview       '1'         # 1 = show the live overview dashboard entry
    option font_size      '14'        # base font size in px
    option rail_collapsed '0'         # 1 = start with the rail collapsed on desktop
```

Example — force a dark theme with a green accent from the CLI:

```sh
uci set uniwrt.global.mode='dark'
uci set uniwrt.global.dark_accent='#38cc65'
uci commit uniwrt
```

The file is registered as a conffile, so your settings persist across package upgrades.

> **A note on fonts.** UniWRT deliberately uses the platform's native `system-ui` font stack rather than bundling a webfont. Routers are flash-constrained and frequently offline, so a remote webfont would either bloat the package or fail to load. The native stack renders instantly and looks clean on every platform.

---

---

## How it works

* **Shell** — `header.ut` / `footer.ut` render the complete page (rail, top bar, content frame) and inject the dark layer inline so the correct theme is resolved before first paint (no flash).
* **Menu** — `menu-uniwrt.js` builds the rail and sub-nav from LuCI's live menu tree (`L.ui.menu.load()`), matching the link-building and active-path detection of current standalone themes.
* **Widgets** — `status-uniwrt.js` and `overview.js` use `rpc.declare()` + `L.resolveDefault()` + the `poll` API to query `ubus` (`system info` / `board`, `luci-rpc getNetworkDevices` / `getWirelessDevices` / `getHostHints`, `network.interface dump`, `network.device status`, `iwinfo`) on a 5-second cadence.
* **Permissions** — `acl.d/luci-theme-uniwrt.json` grants exactly the read scopes the widgets need (plus `/proc/cpuinfo` for core-count detection) and write access only to its own `uniwrt` UCI config.

---

## Compatibility

* **OpenWrt 23.05, 24.10, 25.x** with LuCI on the ucode template engine.
* On 25.x the package manager is **apk**; on 23.05 / 24.10 it is **opkg**. A `.ipk` cannot be installed on an apk system and vice-versa — use the matching artifact.
* `LUCI_PKGARCH:=all` — the package is architecture-independent.

---

## Contributing

Issues and pull requests are welcome. If you hit a rendering bug, a screenshot plus the page path (e.g. *Network &rarr; Firewall &rarr; Port Forwards*) and your OpenWrt / LuCI version makes it much faster to reproduce. Before opening a PR, run the static gate locally:

```sh
./qa-static.sh
```

---

## Credits

Created by [ox1d3x3](https://github.com/ox1d3x3)

Licensed under the [Apache License 2.0](./LICENSE).
