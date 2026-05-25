# UniWRT design direction

UniWRT aims for a premium router/controller interface:

- App-style left navigation feel
- Clean dashboard cards
- Glass panels over a soft animated gradient background
- Strong spacing, rounded corners, subtle shadows
- Dark, light, and system modes
- Mobile responsive views

## Visual language

- Brand: UniWRT
- Logo: UniWRT SVG mark in `htdocs/luci-static/uniwrt/logo.svg`; blue controller tile, U-shaped monoline, and network-node motif.
- Accent: sky blue to deep blue gradient
- States:
  - Green: online / healthy
  - Amber: warning / pending
  - Red: error / destructive

## Compatibility strategy

Instead of duplicating LuCI's fast-changing internal Bootstrap markup, UniWRT inherits Bootstrap's ucode templates through small shim templates:

```text
ucode/template/themes/uniwrt/header.ut
ucode/template/themes/uniwrt/footer.ut
ucode/template/themes/uniwrt/sysauth.ut
```

The full look is then applied through:

```text
htdocs/luci-static/uniwrt/cascade.css
htdocs/luci-static/uniwrt/uniwrt.js
```

This keeps the package much easier to maintain across OpenWrt 24.x and 25.x.

## Next design upgrades

Recommended after first router test:

1. Add page-specific polish for Status → Overview cards.
2. Add better wireless/client table styling once real screenshots are collected.
3. Add optional compact mode.
4. Add user-configurable accent colour through a future `luci-app-uniwrt-config`.
5. Add release screenshots after testing on OpenWrt 24.10 and 25.12.
