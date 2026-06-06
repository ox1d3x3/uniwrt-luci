# UniWRT Portal

A modern, **standalone** LuCI theme for OpenWrt with a persistent dark navigation rail, a clean enterprise-style content area, live status widgets, and a config-driven settings page. Inspired by the look and feel of contemporary network-controller dashboards.

UniWRT is **not** a restyle layered over the stock `bootstrap` theme — it ships its own full HTML shell (header/footer/login templates), builds its navigation client-side from the LuCI dispatcher tree, and polls `ubus` directly for live data. This avoids the whole class of CSS-cascade conflicts that thin restyles run into.

* **Targets:** OpenWrt 23.05, 24.10, and 25.x (snapshot / 25.12+)
* **Package formats:** `.ipk` (opkg, 23.05 / 24.10) and `.apk` (Alpine apk, 25.x)
* **Architecture:** `all` (one universal package per format — no per-CPU builds)
* **License:** Apache-2.0

---

## Features

* **Dark-first navigation rail** — persistent left sidebar with icon + label entries, an expandable sub-tree with a sliding active indicator, and a collapse/pin toggle (state persists in `localStorage`).
* **Light / Dark / Auto theming** — toggled from the top bar. `auto` follows the OS `prefers-color-scheme`. The choice is resolved *before paint* (no flash) and persists per-browser. A server-side default is set from config.
* **Configurable accent colour** — separate accent for light and dark modes, applied through a CSS custom property.
* **Live status bar** — CPU load, RAM usage, uptime and WAN throughput in the header, polled from `ubus` every 5 s.
* **Live overview dashboard** — an optional dashboard page (System / CPU / Memory / Uptime tiles plus interfaces and wireless cards) that polls `ubus` live. Toggle it on/off from settings.
* **Config-driven settings page** — under *System → UniWRT Theme*. Change mode, accent colours, base font size, rail default state, and dashboard/status toggles. All values live in `/etc/config/uniwrt` and survive upgrades.
* **Custom login page** — a self-contained, themed `sysauth` screen with its own light/dark toggle.

---

## Installation

UniWRT is architecture-independent, so the same package works on every device of a given OpenWrt release. Pick the file that matches your OpenWrt version's package manager.

### OpenWrt 25.x (apk)

```sh
# copy the .apk to the router first, then:
apk add --allow-untrusted ./luci-theme-uniwrt-2.0.20-r1.apk
```

`--allow-untrusted` is required for a manually-downloaded, unsigned package. (If you publish a signed feed, install its public key into `/etc/apk/keys/` instead and drop the flag.)

### OpenWrt 24.10 / 23.05 (opkg)

```sh
# copy the .ipk to the router first, then:
opkg install ./luci-theme-uniwrt_2.0.20-1_all.ipk
```

### Activating the theme

On a **fresh install** UniWRT sets itself as the active theme automatically. On an **upgrade** it will *not* override a theme you have since chosen — it only keeps itself in the selectable list. To switch manually at any time:

*System → System → Language and Style → Design → UniWRT*

or from the CLI:

```sh
uci set luci.main.mediaurlbase=/luci-static/uniwrt
uci commit luci
rm -f /tmp/luci-indexcache /tmp/luci-modulecache
```

---

## Configuration

All settings are stored in `/etc/config/uniwrt` and editable from the GUI (*System → UniWRT Theme*) or via UCI.

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

Example — switch to a forced dark theme with a green accent from the CLI:

```sh
uci set uniwrt.global.mode='dark'
uci set uniwrt.global.dark_accent='#38cc65'
uci commit uniwrt
```

The file is registered as a conffile, so your settings persist across package upgrades.

> **A note on fonts.** UniWRT deliberately uses the platform's native `system-ui` font stack rather than bundling a webfont. Routers are flash-constrained and frequently offline, and a remote webfont would either bloat the package or fail to load. The native stack renders instantly and looks clean on every platform.

---

## Building from source

You do **not** need a full OpenWrt buildroot — the per-release SDK is enough. The package format is decided entirely by which SDK branch you build under:

| SDK branch              | Output    |
|-------------------------|-----------|
| 23.05 / 24.10           | `.ipk`    |
| SNAPSHOT (25.x)         | `.apk`    |

### Option A — GitHub Actions (recommended)

This repo ships `.github/workflows/build.yml`, which runs a static QA gate (`qa-static.sh`) and then builds three OpenWrt releases with the official `openwrt/gh-action-sdk` (pinned to `@main`), producing both `.ipk` (23.05.x / 24.10.x) and `.apk` (25.12.x+) artifacts. Every push to `main`/`master` publishes a rolling `nightly` pre-release; pushing a `v*` tag publishes a normal release:

```sh
git tag v2.0.20
git push origin v2.0.20
```

The release also bundles `uniwrt-apply.sh`, a one-shot router-side helper that auto-detects the local `.ipk`/`.apk`, installs it, activates UniWRT, clears the LuCI cache and restarts the web UI.

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

* **Shell** — `header.ut` reads `/etc/config/uniwrt` server-side (via the ucode `uci`/`ubus` bindings), emits the `<!DOCTYPE>`, head, navigation rail and top bar, and leaves empty containers (`#u-rail-nav`, `#u-rail-modes`, `#u-subnav`, `#u-stats`, `#u-top-title`) for the client to fill. `footer.ut` closes the shell and bootstraps the client modules via `L.require(...)`.
* **Menu** — `menu-uniwrt.js` calls `ui.menu.load()` to fetch the dispatcher tree, then walks it with `ui.menu.getChildren()` to render the rail, the top-level category switcher, the page title and the third-level sub-nav tabs — respecting ACL visibility.
* **Widgets** — `status-uniwrt.js` and `overview.js` use `rpc.declare()` + `L.resolveDefault()` + the `poll` API to poll `ubus` (`system info/board`, `luci-rpc getNetworkDevices`, `network.interface dump`, `luci getRealtimeStats`, `iwinfo`) on a 5 s cadence.
* **Settings** — `settings.js` is a standard `form.Map` view registered through `menu.d` and guarded by the `acl.d` grant, writing back to `/etc/config/uniwrt`.

---

## Compatibility notes

* Requires the **ucode** template engine (OpenWrt 23.05+). It does not ship legacy Lua `.htm` templates and does not depend on `luci-compat`.
* On 25.x the package manager is **apk**; on 23.05 / 24.10 it is **opkg**. A `.ipk` cannot be installed on an apk system and vice-versa — use the matching artifact.

---

## Changelog

### v2.0.20
* **Overview card icons fixed.** The dashboard tile icons (System/CPU/Memory/Uptime/Interfaces/Wireless) were blank because their inline SVGs lacked an `xmlns`, so `DOMParser` produced non-rendering nodes. `svgNode()` now injects the SVG namespace; all icons render.
* **Overview page sorted & filled.** The metric row and the lower row now stretch to fill the full width (auto-fit grids) instead of clustering at the left, and a new live **Clients** card (known hosts -> hostname + IP, via `luci-rpc getHostHints`, already in the ACL) fills the bottom row.
* **Throughput shown in Mbps.** The header throughput chip previously printed a value with its own K/M/G suffix and then appended " Mbps" (e.g. "51.1K Mbps"). It now converts bytes/s to Mbps consistently and shows e.g. "down 0.05 up 0.07 Mbps".
* **Footer credit** now reads "OX1d3x3 X UniWRT V<version>" linking to the project repo (hyperlink unchanged).

### v2.0.19
* **Checkboxes are now iOS-style slide on/off switches.** Every `input[type=checkbox]` (including the `.cbi-checkbox` FlagValue widget) renders as an animated toggle: grey/knob-left when off, accent/knob-right when on, with disabled and focus states. Radios stay radios, and multi-select dropdown checkboxes stay compact so the list isn't broken.
* **Fixed the output box hiding behind the menu.** Package-manager ("search software updates") and attended-sysupgrade ("firmware updates") output, plus Save & Apply review, reboot, and other dialogs, are shown by LuCI via `ui.showModal()` -> `#modal_overlay`. The theme wasn't positioning that overlay, so it fell to the bottom-left behind the fixed rail and was unreadable. `#modal_overlay` is now a fixed, full-viewport, centered overlay (z-index above the rail) with a dimmed/blurred backdrop; the modal card is centred, width-capped and scrolls, and its `<pre>` output is scrollable.
* **Added previously-missing component styles** that the reference themes (glass/argon/aurora) all have: `cbi-tooltip` (+ hover triggers), `cbi-progressbar` (memory/flash/sysupgrade bars), `ifacebadge` + `ifacebox` + `network-status-table` (Network/Interfaces), `zonebadge` (firewall zones), `cbi-input-invalid`/`cbi-value-error` and `cbi-section-error` (validation/errors), `control-group` (diagnostics rows), and `cbi-filebrowser`. Dark-mode overrides added for the toggle off-state, modal backdrop, progress bar and badges.
* Audited cascade.css selector coverage against glass to confirm no common LuCI component is left unstyled.

### v2.0.18
* Verified the menu/tab implementation against the OpenWrt reference themes (glass, x1wrt): the option/menu link building (`L.url(url, child.name, sub[0].name)` for parents, `L.url(url, child.name)` for leaves and tabs) and active-path detection match line-for-line, and every element id `menu-uniwrt.js` targets is present in the shell. The in-page CBI tab handling matches x1wrt (bar left in place, LuCI's native JS drives switching). Confirmed working by rendering the real captured LuCI System DOM with this theme's CSS and switching tabs.
* Hardened the inactive-panel hide rule to also cover the `.cbi-tabcontainer` class form (in addition to the `[data-tab][data-tab-title]` attribute form), so in-page tabs are correct across LuCI builds.

### v2.0.17
* **Fixed in-page form tabs** (System -> General Settings / Logging / Time Synchronization / Language and Style, and the same pattern on DHCP, Wireless, Firewall, Interfaces, etc.). Two bugs were compounding:
  * the theme hid the whole `.cbi-tabmenu` bar and tried to relocate it with custom JS, which broke nested tab groups and click forwarding;
  * the inactive-panel hide rule used the wrong selector (`.cbi-tabcontainer[data-hidden]`) while LuCI marks panels with `data-tab-active`, so every tab's content rendered stacked and clicking did nothing.
  The tab bar is now styled in place as a pill bar and LuCI's native switching drives it; inactive panels are hidden with `[data-tab][data-tab-title]:not([data-tab-active="true"])` (no `!important`, so cross-tab field dependencies still evaluate at load).

### v2.0.16
* Layout: content now **fills the page width** instead of sitting in a narrow centred column — tables and info panels use the whole area (addresses the "fill the whole page / empty space" feedback). Inputs keep a sensible max width.
* Form controls: hardened native `<select>` styling and neutralised LuCI's class-less `<div id="cbid…">` wrapper so the old "square box overlapping the select" can't occur; added a min/max width and killed the legacy `::-ms-expand` arrow.
* Light theme: code/log/`#syslog` blocks now use a light surface in light mode (dark only in dark mode) so they no longer read as a jarring black box.
* Footer: trimmed to a single subtle "UniWRT Portal" credit; removed the OpenWrt distribution/version line.

### v2.0.15
* **CI fix:** switched `openwrt/gh-action-sdk` from the pinned `@v6` (which aborted with `sed: can't read feeds.conf.default` on current SDK images) to `@main`, and pinned per-release SDK image tags. Builds now produce real `.ipk` and `.apk` artifacts.
* Added a static QA gate (`qa-static.sh`) that runs in CI: JS syntax, JSON/YAML validity, ucode tag balance, CSS brace balance, version validity and a trademark scan.
* Added `uniwrt-apply.sh`, a router-side one-shot install/activate helper, bundled into releases.
* **Bug fix:** the overview dashboard's CPU/Memory/Uptime tiles now populate on first paint instead of staying blank until the first poll (they were queried before the view was attached to the DOM).
* Granted `/proc/cpuinfo` read in the theme ACL so CPU core-count detection also works for restricted (non-root) LuCI users.

### v2.0.14
* Full rewrite as a **standalone** theme — replaces the earlier restyle-over-bootstrap approach with its own HTML shell, eliminating the cascade-conflict class of bugs.
* Standalone shell (header / footer / login) on the ucode template engine.
* Client-side navigation rail with collapse/pin, sliding indicators and sub-nav tabs.
* Light / Dark / Auto theming with no-flash resolution and configurable per-mode accent colours.
* Live header status bar and live overview dashboard (5 s `ubus` polling).
* Config-driven settings page backed by `/etc/config/uniwrt`.
* Dual `.ipk` + `.apk` CI matrix via the official OpenWrt SDK.

---

## Credits

Created by [ox1d3x3](https://github.com/ox1d3x3). Architecture and template conventions follow current standalone LuCI themes (notably `luci-theme-glass`) verified against the OpenWrt 25.x LuCI source.

Licensed under the [Apache License 2.0](./LICENSE).
