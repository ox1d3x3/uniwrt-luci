# UniWRT v1.7.0 QA checklist

## Static checks performed in sandbox

- Package tree contains required LuCI theme files.
- ucode and Lua header/footer/sysauth shims exist.
- `cascade.css` and `mobile.css` exist under `/luci-static/uniwrt/`.
- JavaScript parses with Node.js syntax check.
- Shell scripts parse with `sh -n`.
- GitHub Actions workflow parses as YAML.
- Preview page renders in Chromium in light and dark mode.

## Real-router checks still required

These need an actual OpenWrt/LuCI runtime:

1. Install `.ipk` on OpenWrt 24.10.x and verify LuCI loads.
2. Install `.apk` on OpenWrt 25.12.x and verify LuCI loads.
3. Test Status, System, Network, Wireless, Firewall, Software and Reboot links.
4. Test Save, Save & Apply, Reset, Add, Edit, Delete, modal dialogs and tab switching.
5. Test mobile rail open/close.
6. Remove the package and confirm LuCI falls back to Bootstrap.

## Emergency recovery

```sh
uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci commit luci
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/uhttpd restart
```
