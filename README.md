# luci-theme-unifios

A clean, card-based **LuCI theme styled after the UniFi OS design language** —
left icon rail, soft shadows, rounded surfaces, pill toggles, the vivid
Ubiquiti-style blue accent, and automatic light/dark modes.

> **What this is (and isn't).** This reproduces the *look and feel* of UniFi OS
> on top of OpenWrt's LuCI. It is **not** a copy of Ubiquiti's product: the
> screens, menus and features are LuCI's own (OpenWrt config), restyled to feel
> like UniFi OS. It also ships **no Ubiquiti trademarks** — the bundled logo is
> a neutral placeholder and the font is [Inter] (the closest freely
> redistributable stand-in for Ubiquiti's proprietary UI typeface). Swap in your
> own branding freely; just don't redistribute Ubiquiti's assets.

[Inter]: https://rsms.me/inter/

## Supported versions & architectures

| OpenWrt | Package manager | Artifact | Notes |
|--------:|:----------------|:---------|:------|
| 23.05.x | opkg | `luci-theme-unifios_*_all.ipk` | |
| 24.10.x | opkg | `luci-theme-unifios_*_all.ipk` | |
| 25.12.x | apk  | `luci-theme-unifios_*_all.apk` | apk is the default PM from 25.12 |

The package is **architecture-independent** (`PKGARCH=all`): one file per
release line installs on **every** OpenWrt target (x86, all ARM/MIPS routers,
etc.). The package format differs only because OpenWrt switched its package
manager from opkg to apk starting with 25.12 — the CI builds both automatically.

## Install

Grab the right file from the **[Releases](../../releases)** page (the workflow
publishes a rolling `nightly` pre-release).

```sh
# OpenWrt 23.05 / 24.10  (opkg)
opkg install ./luci-theme-unifios_*_all.ipk

# OpenWrt 25.12+  (apk)
apk add --allow-untrusted ./luci-theme-unifios_*_all.apk
```

The theme registers itself and becomes active on install. Hard-refresh LuCI
(`Ctrl+Shift+R`) afterwards. To switch back: **System → System → Language and
Style → Design**.

## Build it yourself

### In CI (recommended)
Push to `main` (or run the workflow manually). `.github/workflows/build.yml`
builds all three releases via the official `openwrt/gh-action-sdk` containers
and publishes the `.ipk`/`.apk` files as a pre-release. **Keep the `release:`
values in the matrix pinned to the current point releases on
[hub.docker.com/r/openwrt/sdk/tags](https://hub.docker.com/r/openwrt/sdk/tags)** —
that's the one thing to bump over time.

### Locally with an SDK
```sh
# inside an unpacked OpenWrt SDK for your target release
git clone <this-repo> package/luci-theme-unifios-src
ln -s ../package/luci-theme-unifios-src/luci-theme-unifios package/luci-theme-unifios
./scripts/feeds update -a && ./scripts/feeds install -a
make package/luci-theme-unifios/compile V=s
# result: bin/packages/<arch>/unifios/luci-theme-unifios_*_all.{ipk,apk}
```

## How it works

To stay compatible as LuCI evolves, the theme **inherits the stock `bootstrap`
chrome** (which is why `luci-theme-bootstrap` is a dependency) and layers the
UniFi look on top:

- `htdocs/luci-static/unifios/css/unifios.css` — the entire visual language,
  targeting LuCI's stable `.cbi-*` / `.table` / `.alert-message` classes plus
  the common layout classes. This is the robust, portable core of the theme.
- `htdocs/luci-static/unifios/js/unifios.js` — relocates LuCI's menu into the
  left rail, adds the collapse + light/dark controls, and styles the login
  page. It watches for LuCI's async-rendered menu and **degrades gracefully**:
  if it can't find the menu, the CSS styling and dark mode still apply and the
  native top nav is left in place (nothing is hidden until the rail is built).
- `luasrc/view/themes/unifios/*.htm` (Lua) and `ucode/template/themes/unifios/*.ut`
  (ucode) — thin header/footer shells. Both engines ship so the theme works
  whether the running LuCI core renders Lua (`23.05`) or ucode (`24.10`/`25.12`)
  templates.

## Customising

Everything visual is a CSS variable at the top of `unifios.css`:

```css
:root {
  --u-blue:   #006fff;   /* primary accent            */
  --u-bg:     #f7f8fa;   /* app background            */
  --u-card:   #ffffff;   /* cards / panels            */
  --u-radius: 10px;      /* corner rounding           */
  --u-rail:   248px;     /* sidebar width             */
  --u-font:   "Inter", -apple-system, "Segoe UI", Roboto, sans-serif;
}
```

- **Logo:** replace `htdocs/luci-static/unifios/logo.svg`.
- **Self-host Inter:** drop the `.woff2` files into `htdocs/luci-static/unifios/fonts/`
  and uncomment the `@font-face` block at the top of `unifios.css` (otherwise it
  falls back to the system sans, which still reads cleanly).
- **Brand text:** edit the two `UniFi&nbsp;OS` strings in `unifios.js`.

## Notes / known rough edges

- The **CSS and JS are the dependable core** and are easy to verify in any
  browser. The **header/footer templates** are the part most likely to want a
  one-line tweak after a real build, because the include mechanism differs
  slightly between the Lua and ucode template engines. If a template ever fails
  to resolve `include('themes/bootstrap/...')` on your build, point it at the
  matching file your stock theme actually ships.
- LuCI's menu DOM varies a little between versions; the rail builder tries
  several selectors. If your build exposes the menu differently, adjust the
  `findMenu()` selector list in `unifios.js`.

## License

MIT — see [LICENSE](LICENSE). UniFi and UniFi OS are trademarks of Ubiquiti Inc.;
this project is an independent, unaffiliated theme inspired by their design and
ships none of their assets.
