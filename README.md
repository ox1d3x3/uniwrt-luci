# UniWRT LuCI Theme

UniWRT is a clean, modern, responsive LuCI theme for OpenWrt.

## Package names

- Project/theme name: `UniWRT`
- Package name: `luci-theme-uniwrt`
- Static assets: `/www/luci-static/uniwrt`
- LuCI templates: `/usr/share/ucode/luci/template/themes/uniwrt`

## Rolling update v0.2.8

This update fixes the package/release workflow mess:

- Removed all old legacy naming.
- Removed duplicated package workflow file.
- Builds both required package formats:
  - `luci-theme-uniwrt.ipk` for OpenWrt 24.10.6 / OPKG.
  - `luci-theme-uniwrt.apk` for OpenWrt 25.12.4 / APK.
- Publishes a moving GitHub pre-release named `pre-release`.
- Uses GitHub's built-in `${{ github.token }}` with `contents: write`.
- Does not use a custom PAT or custom secret.
- Uses `package.mk` only. This package must not use `luci.mk`.
- Does not build `luci-base`, `ucode`, `rpcd`, `lucihttp`, `libnl`, or Lua dependencies in the SDK path.

## Important before pushing

Delete old duplicate workflow files from the repo first. If they remain in GitHub, GitHub will still show/run them.

```sh
rm -f .github/workflows/build-openwrt-packages.yml
rm -f .github/workflows/build-packages.yml
rm -f .github/workflows/openwrt-25-apk.yml
rm -f .github/workflows/apk-build.yml
rm -f .github/workflows/ipk-build.yml
```

Then push this project:

```sh
chmod +x scripts/*.sh
./scripts/clean-repo-before-push.sh
git add -A
git commit -m "Roll UniWRT v0.2.8 package workflow fix"
git push
```

## GitHub release permissions

No custom GitHub token is required.

The workflow uses:

```yaml
permissions:
  contents: write
  actions: read
```

and:

```yaml
env:
  GH_TOKEN: ${{ github.token }}
```

If GitHub still throws `HTTP 403: Resource not accessible by integration`, fix the repo setting:

`Settings > Actions > General > Workflow permissions > Read and write permissions`

## Install from the moving pre-release

OpenWrt 25.12.4 / APK:

```sh
cd /tmp
apk del luci-theme-uniwrt 2>/dev/null || true
sed -i '/^luci-theme-uniwrt/d' /etc/apk/world 2>/dev/null || true
wget https://github.com/ox1d3x3/uniwrt-luci/releases/download/pre-release/luci-theme-uniwrt.apk
apk add --allow-untrusted ./luci-theme-uniwrt.apk
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/uhttpd restart
```

OpenWrt 24.10.6 / OPKG:

```sh
cd /tmp
wget https://github.com/ox1d3x3/uniwrt-luci/releases/download/pre-release/luci-theme-uniwrt.ipk
opkg install ./luci-theme-uniwrt.ipk
uci set luci.main.mediaurlbase='/luci-static/uniwrt'
uci commit luci
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/uhttpd restart
```
