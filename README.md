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
apk add --allow-untrusted ./luci-theme-uniwrt-2.0.21-r1.apk
```

`--allow-untrusted` is required for a manually-downloaded, unsigned package. If you publish a signed feed, install its public key into `/etc/apk/keys/` instead and drop the flag.

### OpenWrt 24.10 / 23.05 (opkg)

```sh
# copy the .ipk to the router first, then:
opkg install ./luci-theme-uniwrt_2.0.21-1_all.ipk
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

## Building from source

### Option A — GitHub Actions (recommended)

This repo ships `.github/workflows/build.yml`, which runs a static QA gate (`qa-static.sh`) and then builds three OpenWrt releases with the official `openwrt/gh-action-sdk` (pinned to `@main`), producing both `.ipk` (23.05.x / 24.10.x) and `.apk` (25.12.x+) artifacts. Every push to `main` / `master` publishes a rolling `nightly` pre-release; pushing a `v*` tag publishes a normal release:

```sh
git tag v2.0.21
git push origin v2.0.21
```

The release also bundles `uniwrt-apply.sh`, a one-shot router-side helper that auto-detects the local `.ipk` / `.apk`, installs it, activates UniWRT, clears the LuCI cache and restarts the web UI.

> **SDK image tags:** the matrix pins `x86_64-23.05.6`, `x86_64-24.10.6`, and `x86_64-25.12.4`. If a build reports `manifest unknown`, that point-release SDK image isn't published yet — bump the tag to one that exists (or use `x86_64-SNAPSHOT` for the apk row).

### Option B — local SDK build

```sh
# 1. download and extract the SDK for your target/branch, then inside it:
echo "src-link uniwrt /path/to/uniwrt-luci" >> feeds.conf.default
./scripts/feeds update uniwrt
./scripts/feeds install -a -p uniwrt

# 2. enable the package
make menuconfig            # LuCI -> Themes -> luci-theme-uniwrt  (M)

# 3. build
make package/luci-theme-uniwrt/compile V=s

# 4. the package lands under bin/packages/<arch>/uniwrt/
```

> The CSS minifier (`csstidy`) is intentionally disabled in the Makefile (`CONFIG_LUCI_CSSTIDY:=`). It is a CSS2-era tool that mangles modern properties such as `backdrop-filter` and multi-stop gradients, so the committed CSS ships to the device byte-for-byte.

---

## Project layout

```
uniwrt-luci/
├── .github/workflows/build.yml          # QA + dual IPK/APK CI matrix
├── qa-static.sh                         # static QA gate (run in CI and locally)
├── uniwrt-apply.sh                      # router-side one-shot install/activate helper
├── docs/screenshots/                    # README preview images
├── README.md
├── LICENSE
└── luci-theme-uniwrt/
    ├── Makefile
    ├── ucode/template/themes/uniwrt/
    │   ├── header.ut                     # full HTML shell (head, rail, top bar)
    │   ├── footer.ut                     # shell close + client bootstrapping
    │   ├── sysauth.ut                    # themed login page
    │   └── version
    ├── htdocs/luci-static/uniwrt/
    │   ├── css/cascade.css               # light / base layer
    │   ├── css/dark.css                  # dark overrides (injected, media-toggled)
    │   └── img/uniwrt-logo.svg
    ├── htdocs/luci-static/resources/
    │   ├── menu-uniwrt.js                # client-side rail/menu builder
    │   ├── status-uniwrt.js              # live header status widgets
    │   └── view/uniwrt/
    │       ├── settings.js               # settings page (form.Map)
    │       └── overview.js               # live overview dashboard
    └── root/
        ├── etc/config/uniwrt             # default settings (conffile)
        ├── etc/uci-defaults/30_luci-theme-uniwrt
        └── usr/share/
            ├── luci/menu.d/luci-theme-uniwrt.json
            └── rpcd/acl.d/luci-theme-uniwrt.json
```

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

## Changelog

### v2.0.21
* **Restored LuCI system indicators.** The theme was missing the `#indicators` element that LuCI core injects into via `ui.showIndicator()` — so the clickable **"Unsaved Changes"** badge (review/apply pending UCI changes) and the poll **Refreshing/Paused** state never appeared. Every reference theme provides this hook; it is now in the header, styled to match the status chips (amber for pending changes, accent for active states).
* **Styled the UCI change-review dialog** (`uci-change-list` / `uci-change-legend`): monospace diff with green additions, red removals and neutral modifications, in both light and dark.
* **Killed the rail flash on load.** The collapsed/expanded rail state stored in the browser was restored by the footer script after first paint, so a collapsed rail flashed expanded and shifted the layout on every page load. The state is now restored pre-paint in the head, alongside the theme resolution.
* **New logo.** Redesigned brand mark: blue gradient tile with a rounded "U" and a signal-beacon dot, legible from 128 px down to the 16 px favicon, in light and dark.
* Polish & robustness: open dropdown lists now layer above the sticky bars (`z-index`), added `cbi-section-create` row styling, sortable-table header affordance (pointer + sort-direction arrow), `prefers-reduced-motion` support (disables animations for users who request it), thin scrollbar + overscroll containment on the rail, and unified the rail-foot credit with the footer branding.

### v2.0.20
* **Overview card icons fixed.** Dashboard tile icons were blank because their inline SVGs lacked an `xmlns`, so `DOMParser` produced non-rendering nodes; `svgNode()` now injects the SVG namespace.
* **Overview page sorted & filled.** Both card rows stretch to fill the full width, and a new live **Clients** card (known hosts &rarr; hostname + IP, via `luci-rpc getHostHints`) fills the bottom row.
* **Throughput shown in Mbps.** The header throughput chip now converts bytes/s to Mbps consistently (e.g. "&darr;0.05 &uarr;0.07 Mbps") instead of the previous mismatched-unit output.
* **Footer credit** reads "OX1d3x3 X UniWRT V&lt;version&gt;", linking to the project repo.

### v2.0.19
* Checkboxes render as iOS-style slide on/off switches (radios and multi-select dropdown checkboxes are left as-is).
* **Fixed the output box hiding behind the menu** — package-manager / attended-sysupgrade output, Save & Apply review, reboot and other `ui.showModal()` dialogs were dropping to the bottom-left behind the rail. `#modal_overlay` is now a fixed, centred, full-viewport overlay above the rail with a dimmed backdrop and a scrollable card.
* Added previously-missing component styles (tooltip, progress bar, interface / zone badges, validation states, section errors, diagnostics control groups, file browser) plus their dark-mode overrides.

### v2.0.18
* Verified menu/tab link-building and active-path detection against the reference themes (glass, x1wrt); hardened the inactive tab-panel hide rule to cover the `.cbi-tabcontainer` class form across LuCI builds.

### v2.0.17
* **Fixed in-page form tabs** (System &rarr; General / Logging / Time Sync / Language, and the same pattern elsewhere). The tab bar is now styled in place and LuCI's native switching drives it; inactive panels hide via `[data-tab][data-tab-title]:not([data-tab-active="true"])`.

### v2.0.16
* Content fills the page width; hardened `<select>` styling; light-mode code/log blocks use a light surface; trimmed the footer.

### v2.0.15
* CI fix (switched `gh-action-sdk` to `@main` with pinned SDK image tags) so builds produce real `.ipk` / `.apk` artifacts; added the `qa-static.sh` gate and `uniwrt-apply.sh`; overview tiles paint on first load; granted `/proc/cpuinfo` read in the ACL.

### v2.0.14
* Full rewrite as a **standalone** theme — own HTML shell on the ucode template engine, client-side navigation rail, light / dark / auto theming, live status bar and overview dashboard, config-driven settings, and the dual `.ipk` + `.apk` CI matrix.

---

## Credits

Created by [ox1d3x3](https://github.com/ox1d3x3). Architecture and template conventions follow current standalone LuCI themes (notably `luci-theme-glass`), verified against the OpenWrt 25.x LuCI source.

Licensed under the [Apache License 2.0](./LICENSE).
