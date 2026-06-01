# luci-theme-uniwrt

**UniWRT** — a clean, card-based theme for OpenWrt's LuCI web interface. Left
icon rail, soft shadows, rounded surfaces, pill toggles, a vivid blue accent and
automatic light/dark modes. The layout, structure and interaction model are
designed to feel like a modern appliance UI; the branding (name, logo, colours)
is UniWRT's own.

## One question decides your download: which OpenWrt version are you on?

This theme has **no compiled code**, so it is built as an architecture-independent
(`all`) package. That means your router's CPU/target — `mt7622`, `ramips`,
`x86_64`, anything — **does not matter**. Only your OpenWrt *version* matters,
because that determines the package manager:

| Your OpenWrt | Package manager | Download this file |
|-------------:|:----------------|:-------------------|
| 24.10.x | opkg | `luci-theme-uniwrt_*_all.ipk` |
| 25.12.x+ | apk | `luci-theme-uniwrt-*.apk` |

So there are only ever **two files**: one universal `.ipk` (for 24.10)
and one universal `.apk` (for 25.12+). Pick by version, not by router.

**Not sure which version you run?** On the router:
```sh
ubus call system board | grep -i release
# or
cat /etc/openwrt_release | grep VERSION
```
or in LuCI: **Status → Overview** (firmware version). `24.*` → take the `.ipk`; `25.*` → take the `.apk`.

## Install

```sh
# OpenWrt 24.10  (opkg)
opkg install ./luci-theme-uniwrt_*_all.ipk

# OpenWrt 25.12+  (apk)
apk add --allow-untrusted ./luci-theme-uniwrt-*.apk
```

The theme registers itself and becomes active on install. Hard-refresh LuCI
(`Ctrl+Shift+R`). To switch themes later: **System → System → Language and Style
→ Design**.

## Build it yourself

### In CI
Push to `main` (or run the workflow manually). `.github/workflows/build.yml`
builds the two universal packages via the official `openwrt/gh-action-sdk`
containers and publishes them as a rolling `nightly` pre-release. Pushing a
`v*` tag cuts a tagged pre-release instead.

**The only upkeep:** keep the `release:` SDK versions in the workflow matrix
pinned to current point releases on
[hub.docker.com/r/openwrt/sdk/tags](https://hub.docker.com/r/openwrt/sdk/tags).

### Locally with an SDK
```sh
# inside an unpacked OpenWrt SDK for your release line
git clone <this-repo> package/luci-theme-uniwrt-src
ln -s ../package/luci-theme-uniwrt-src/luci-theme-uniwrt package/luci-theme-uniwrt
./scripts/feeds update -a && ./scripts/feeds install -a
make package/luci-theme-uniwrt/compile V=s
# result: bin/packages/<arch>/uniwrt/luci-theme-uniwrt_*.ipk  (or  luci-theme-uniwrt-*.apk on 25.12)
```

## How it works

To stay compatible as LuCI evolves, the theme **inherits the stock `bootstrap`
chrome** (hence the `luci-theme-bootstrap` dependency) and layers the UniWRT
look on top:

- `htdocs/luci-static/uniwrt/cascade.css` — LuCI/Bootstrap-compatible CSS entrypoint.
- `htdocs/luci-static/uniwrt/css/uniwrt.css` — the entire visual language,
  targeting LuCI's stable `.cbi-*` / `.table` / `.alert-message` classes plus
  common layout classes. This is the robust, portable core.
- `htdocs/luci-static/uniwrt/js/uniwrt.js` — relocates LuCI's real menu into the left
  rail, adds the collapse + light/dark controls, and styles the login page. It
  waits for LuCI's async-rendered menu and **degrades gracefully**: if it
  can't find the menu, it builds a small recovery menu instead of hiding access
  to LuCI.
- `luasrc/view/themes/uniwrt/*.htm` (legacy Lua template fallback) and
  `ucode/template/themes/uniwrt/*.ut` (ucode, for 24.10/25.12) — thin
  header/footer shells. Both engines ship so the theme works whichever the
  running LuCI core renders.

## Customising

Everything visual is a CSS variable at the top of `uniwrt.css`:

```css
:root {
  --u-blue:   #006fff;   /* primary accent  */
  --u-bg:     #f7f8fa;   /* app background  */
  --u-card:   #ffffff;   /* cards / panels  */
  --u-radius: 10px;      /* corner rounding */
  --u-rail:   248px;     /* sidebar width   */
}
```

- **Logo:** replace `htdocs/luci-static/uniwrt/logo.svg`.
- **Brand text:** edit the `UniWRT` strings in `uniwrt.js`.
- **Self-host the font:** drop Inter `.woff2` files into
  `htdocs/luci-static/uniwrt/fonts/` and uncomment the `@font-face` block at the
  top of `uniwrt.css`.

## Notes / known rough edges

- The CSS and JS are the dependable core. The header/footer templates are the
  part most likely to want a one-line tweak after a real build, because the
  `include('themes/bootstrap/...')` mechanism differs slightly between LuCI's
  legacy Lua and current ucode engines.
- LuCI's menu DOM varies a little between versions; the rail builder tries
  several selectors. If your build exposes the menu differently, adjust the
  `findMenu()` selector list in `uniwrt.js`.

## License

MIT — see [LICENSE](LICENSE). UniWRT is an independent project and is not
affiliated with or endorsed by any third party; its name, logo and branding are
its own.


## v1.7.0 QA/fix notes

This release focuses on function safety rather than only visual polish:

- fixed ucode include paths to use the LuCI-compatible `../bootstrap/*.ut` form;
- added `cascade.css` and `mobile.css` entrypoints expected by Bootstrap-based LuCI themes;
- changed navigation to dynamic menu-first parsing so installed LuCI apps/custom pages keep working;
- kept fallback links as a small recovery menu only when LuCI exposes no menu;
- fixed checkbox/switch styling so the real checkbox remains clickable;
- stopped replacing the entire footer, only appending the UniWRT version badge;
- added a post-remove fallback that restores Bootstrap if UniWRT is removed.

